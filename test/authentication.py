import asyncio
import importlib.machinery
import importlib.util
import shutil
import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import asyncssh


loader = importlib.machinery.SourceFileLoader(
    'gn_daemon', str(Path(__file__).resolve().parent.parent / 'gn-daemon')
)
spec = importlib.util.spec_from_loader(loader.name, loader)
daemon = importlib.util.module_from_spec(spec)
loader.exec_module(daemon)


class AuthenticationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.database_path = Path(self.directory.name) / 'users.db'
        self.key = asyncssh.generate_private_key('ssh-ed25519').convert_to_public()
        self.other_key = asyncssh.generate_private_key('ssh-ed25519').convert_to_public()
        with sqlite3.connect(self.database_path) as database:
            database.execute('CREATE TABLE users (username TEXT UNIQUE, ssh_public_key TEXT)')
            database.execute(
                'INSERT INTO users VALUES (?, ?)',
                ('anon', self.key.export_public_key().decode().strip() + ' a comment'),
            )
        settings = patch.dict(daemon.GLOBAL_CONFIG, {
            'SCRIMSHAW': True,
            'DATABASE_LOCATION': str(self.database_path),
        })
        settings.start()
        self.addCleanup(settings.stop)

    def test_key_is_bound_to_username(self):
        self.assertTrue(daemon.validate_key('anon', self.key))
        self.assertFalse(daemon.validate_key('anon', self.other_key))
        self.assertFalse(daemon.validate_key('other-user', self.key))
        self.assertFalse(daemon.validate_key("anon' OR 1=1 --", self.key))

    def test_key_changes_are_seen_without_restart(self):
        with sqlite3.connect(self.database_path) as database:
            database.execute(
                'UPDATE users SET ssh_public_key = ? WHERE username = ?',
                (self.other_key.export_public_key().decode(), 'anon'),
            )
        self.assertFalse(daemon.validate_key('anon', self.key))
        self.assertTrue(daemon.validate_key('anon', self.other_key))

    def test_disabled_authentication_and_anonymous_git(self):
        daemon.GLOBAL_CONFIG['SCRIMSHAW'] = False
        self.assertFalse(daemon.validate_key('anon', self.key))
        server = daemon.GNServer()
        self.assertFalse(server.begin_auth('git'))
        self.assertTrue(server.begin_auth('anon'))
        self.assertFalse(server.password_auth_supported())

    def test_invalid_and_missing_keys_fail_closed(self):
        for stored_key in (None, '', 'not a public key'):
            with self.subTest(stored_key=stored_key):
                with sqlite3.connect(self.database_path) as database:
                    database.execute('UPDATE users SET ssh_public_key = ?', (stored_key,))
                self.assertFalse(daemon.validate_key('anon', self.key))

    def test_missing_database_is_not_created(self):
        missing = Path(self.directory.name) / 'missing.db'
        daemon.GLOBAL_CONFIG['DATABASE_LOCATION'] = str(missing)
        self.assertFalse(daemon.validate_key('anon', self.key))
        self.assertFalse(missing.exists())

    def test_invalid_schema_fails_closed(self):
        with sqlite3.connect(self.database_path) as database:
            database.execute('DROP TABLE users')
        self.assertFalse(daemon.validate_key('anon', self.key))

    def test_configuration_booleans(self):
        for enabled in ('1', '0'):
            with self.subTest(enabled=enabled):
                config = daemon.ConfigObj({
                    'core': {'GIT_ROOT': 'repositories/'},
                    'ssh': {'SCRIMSHAW': enabled},
                    'scrimshaw': {'DATABASE_LOCATION': str(self.database_path)},
                })
                with patch.object(daemon, 'ConfigObj', side_effect=[config, daemon.ConfigObj()]):
                    daemon.init()
                self.assertIs(daemon.GLOBAL_CONFIG['SCRIMSHAW'], enabled == '1')

    def test_invalid_configuration_boolean_is_rejected(self):
        for enabled in ('true', 'false', '2', ''):
            with self.subTest(enabled=enabled):
                config = daemon.ConfigObj({'ssh': {'SCRIMSHAW': enabled}})
                with patch.object(daemon, 'ConfigObj', side_effect=[config, daemon.ConfigObj()]):
                    with self.assertRaisesRegex(ValueError, 'SCRIMSHAW must be 0 or 1'):
                        daemon.init()

    def test_ssh_handshake(self):
        private_key = asyncssh.generate_private_key('ssh-ed25519')
        with sqlite3.connect(self.database_path) as database:
            database.execute('UPDATE users SET ssh_public_key = ?', (
                private_key.export_public_key().decode(),
            ))

        async def handshake():
            server = await asyncssh.create_server(
                daemon.GNServer, '127.0.0.1', 0,
                server_host_keys=[asyncssh.generate_private_key('ssh-ed25519')],
            )
            try:
                options = {
                    'host': '127.0.0.1', 'port': server.get_port(),
                    'known_hosts': None, 'agent_path': None,
                }
                async with asyncssh.connect(**options, username='anon', client_keys=[private_key]):
                    pass
                with self.assertRaises(asyncssh.PermissionDenied):
                    await asyncssh.connect(**options, username='other-user', client_keys=[private_key])
                daemon.GLOBAL_CONFIG['SCRIMSHAW'] = False
                with self.assertRaises(asyncssh.PermissionDenied):
                    await asyncssh.connect(**options, username='anon', client_keys=[private_key])
                async with asyncssh.connect(**options, username='git', client_keys=[]):
                    pass
            finally:
                server.close()
                await server.wait_closed()

        asyncio.run(handshake())


class ProcessEnvironmentTests(unittest.TestCase):
    def test_hook_paths_are_relative_to_daemon_not_cwd(self):
        process = MagicMock()
        process.command = 'git-upload-pack repositories/anon/slurp.git'
        process.get_extra_info.return_value = 'git'
        create_process = AsyncMock(side_effect=OSError('environment probe'))

        with tempfile.TemporaryFile() as descriptor:
            with patch.object(daemon, 'bwrap_argv_for_user', return_value=(['bwrap'], descriptor)), \
                    patch.dict(daemon.GLOBAL_CONFIG, {'GIT_ROOT': 'repositories/'}), \
                    patch.object(daemon.os, 'getcwd', return_value='/unrelated/directory') as getcwd, \
                    patch.dict(daemon.environ, {'PERL5LIB': 'inherited-library-path'}), \
                    patch.object(daemon.asyncio, 'create_subprocess_exec', create_process):
                with self.assertRaisesRegex(OSError, 'environment probe'):
                    asyncio.run(daemon.gn_process.__wrapped__(process))
                getcwd.assert_not_called()

        environment = create_process.call_args.kwargs['env']
        project_root = Path(__file__).resolve().parent.parent
        self.assertEqual(environment['PATH'], str(project_root / 'PATH' / 'daemon'))
        self.assertEqual(environment['PERL5LIB'].split(daemon.os.pathsep), [
            str(project_root), str(project_root / 'local' / 'lib' / 'perl5'),
            'inherited-library-path',
        ])
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(
                [shutil.which('perl'), '-c', str(project_root / 'utility' / 'sync-git-repository-to-remotes')],
                cwd=directory, env=environment, capture_output=True,
            )
        self.assertEqual(result.returncode, 0, result.stderr.decode())


class SandboxTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.git_root = Path(self.directory.name) / 'repositories'
        self.git_root.mkdir()
        settings = patch.dict(daemon.GLOBAL_CONFIG, {'GIT_ROOT': str(self.git_root)})
        settings.start()
        self.addCleanup(settings.stop)

    def sandbox_args(self, username):
        args, descriptor = daemon.bwrap_argv_for_user(
            username, ['PATH/daemon/git-upload-pack'],
        )
        with descriptor:
            extra_args = descriptor.read().decode().rstrip('\0').split('\0')
        return args, extra_args if extra_args != [''] else []

    def test_git_has_no_writable_mounts_or_cache_dependency(self):
        with patch.object(daemon, 'get_writable_repositories') as lookup:
            for user_directory_exists in (False, True):
                with self.subTest(user_directory_exists=user_directory_exists):
                    if user_directory_exists:
                        (self.git_root / 'git').mkdir()
                    args, extra_args = self.sandbox_args('git')
                    self.assertNotIn('--bind', args)
                    self.assertEqual(extra_args, [])
                    self.assertIn('--ro-bind', args)
                    root_mount = ['--ro-bind', str(self.git_root), str(self.git_root)]
                    self.assertTrue(any(args[index:index + 3] == root_mount for index in range(len(args))))
            lookup.assert_not_called()

    def test_missing_user_directory_is_not_mounted(self):
        collaborator_repo = self.git_root / 'other' / 'shared.git'
        collaborator_repo.mkdir(parents=True)
        with patch.object(daemon, 'get_writable_repositories', return_value=['other/shared.git']):
            args, extra_args = self.sandbox_args('anon')
        self.assertNotIn('--bind', args)
        self.assertNotIn(str(self.git_root / 'anon'), args)
        self.assertEqual(extra_args, ['--bind', str(collaborator_repo), str(collaborator_repo)])

    def test_existing_user_directory_is_writable(self):
        user_directory = self.git_root / 'anon'
        user_directory.mkdir()
        with patch.object(daemon, 'get_writable_repositories', return_value=[]):
            args, extra_args = self.sandbox_args('anon')
        bind_index = args.index('--bind')
        self.assertEqual(args[bind_index + 1:bind_index + 3], [str(user_directory)] * 2)
        self.assertEqual(extra_args, [])


if __name__ == '__main__':
    unittest.main()