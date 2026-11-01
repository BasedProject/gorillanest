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

    def test_scrimshaw_disabled_and_anonymous_git(self):
        daemon.GLOBAL_CONFIG['SCRIMSHAW'] = False
        self.assertFalse(daemon.validate_key('anon', self.key))
        server = daemon.GNServer()
        self.assertFalse(server.begin_auth('git'))
        self.assertTrue(server.begin_auth('anon'))
        self.assertFalse(server.password_auth_supported())

    def test_ssh_handshake(self):
        private_key = asyncssh.generate_private_key('ssh-ed25519')
        with sqlite3.connect(self.database_path) as database:
            database.execute('UPDATE users SET ssh_public_key = ?', (
                private_key.export_public_key().decode(),
            ))

        async def handshake():
            server = await asyncssh.create_server(
                daemon.GNServer,
                '127.0.0.1', 0,
                server_host_keys=[asyncssh.generate_private_key('ssh-ed25519')],
            )
            try:
                options = {
                    'host': '127.0.0.1',
                    'port': server.get_port(),
                    'known_hosts': None,
                    'agent_path': None,
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


if __name__ == '__main__':
    unittest.main()
