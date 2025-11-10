# CGI
CGI processes have empty `$PATH`-s by default for security reasons.
We depend on Git::Repository
which delegates the actual command execution to System::Command,
which depends on `$PATH`.

As a comprimise we expose this directory to the to `gn-cgi`,
so that it can find git.

# Daemon
Daemon process execution is whitelist based,
so mangling PATH in any way is not strictly required,
however since the binaries have to go somewhere
and we are isolating CGI executables anyways,
it makes organizational sense to have a seperate directory.
