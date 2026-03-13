# Gorillanest Developer documentation
GN stands for Gorillanest in the following document,
and it refers to the project as a whole.

## Tech stack
* Perl for webdev
* Python for SSH daemon
* files and SQLite for storage

## Project structure
| Path                 | Description |
| :------------------- | :---------- |
| gorillanest          | Run all subservices |
| config.default.ini   | Default configuration, don't edit this, copy it to ./config.ini |
| config.ini           | (Nonexistant.) Configuration overriding ./config.default.ini |
| repositories/        | Default git repository storage path |
| dummy\_repositories/ | Mock repositories/ contents for testing |
| www/                 | HTTP served documents | 
| service/             | Service files {lighttpd, nginx, cron} |
| perl-module/         | Perl dependencies |
| PATH/                | Custom scripts and wrappers exposed to the daemons | 
| gn-cgi               | Web service script |
| gn-fcgi              | Fast cgi wrapper for gn-cli |
| gn-daemon            | Custom SSH daemon handling various repo and site management requests |

## Git config extensions
Git config allows for storing arbitrary data.
We utilize this to store metadata meaningful to Gorillanest within the repos themselves.

The extensions are:
- meta:
    * description [string]
    * topic       [string-list]
- remote [url]:
    * sync-direction [push|pull|none]
- permissions
    * hidden [true|false]
    * write  [user-list]

## Web

### URL scheme
| Path                | Description |
| :------------------ | :---------- |
| /                   | Index |
| /api                | REST API relaying commands as SSH to gn-daemon |
| /explore            | Project listing |
| /login              | Redirection to authenticator service |
| /~{user}            | User index |
| /~{user}/{repo}     | Repository index |
| /~{user}/{repo}.git | HTTP git clone endpoint |

### API
The GN web interface provides an api at `/api`.

It can be disabled with the boolean `frontend::DISABLE_API` option.

Given a `POST` request,
it will relay commands to the SSH daemon,
assuming password based authentication is enabled and successful.
For what that is capable of, consult the SSH section.

Given a `GET` request,
a simple form is provided for creating appropriate `POST` request from the browser.

### Clones
HTTP clones are proxied to the official git executable `git-http-backend`.

### PATH/cgi
Somewhat analogous to `PATH/daemon` (see below),
but these executables are used by the GN web interface internally.
That is to say,
these commands are NOT available to clients
and admins should have no reason to audit the directory,
unless forking the project.

## SSH
GN runs a custom SSH daemon using Python's `asyncssh` package.
Python was specifically selected because of the availability
and ergonomics of this one package.

The main benefit of a custom SSH daemon is control over authentication.
This allows GN to support anonymous SSH clones
and automatically permit password logins for registered users.

### PATH/daemon
The SSH daemon only allows for running executables which are present in this folder,
for security reasons, obviously.

Alternatively, a whitelist could be deployed.
While it is theoretically safer,
it was judged to be a safety-theater,
adding unnecessary friction for the initiated.

Users are highly advised against inserting new executables,
unless they are absolutely certain in what they are doing.
Any unsecure executable could compromise the system.

Any executable script that takes tainted user input is recommended to be in Perl.
Regardless, using Shell scripts would be equivalent to a death wish.
