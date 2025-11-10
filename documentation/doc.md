# Gorillanest

## Tech stack
* Perl for webdev
* Python for SSH daemon
* SQLite and files for storage

## Project structure
| Path                 | Description |
| :------------------- | :---------- |
| repositories/        | Default git repository storage path |
| dummy\_repositories/ | Mock repositories/ contents for testing |
| perl-module/         | Perl dependencies |
| service/             | Service files {lighttpd, nginx, cron} |
| www/                 | HTTP served documents | 
| config.default.ini   | Default configuration, don't edit this, copy it to ./config.ini |
| config.ini           | (Nonexistant.) Configuration overriding ./config.default.ini |
| Makefile             | Anon's autism for starting webserver |
| gn-cgi               | Web service script |
| gn-fcgi              | Fast cgi wrapper for gn-cli |

> [!NOTE]
> Executables are allways stored top level.

## URL scheme
| Path                | Description |
| :------------------ | :---------- |
| /                   | Index |
| /~{user}            | User index |
| /~{user}/{repo}     | Repository index |
| /~{user}/{repo}.git | Git over HTTP endpoint for repository |
| /explore            | Project listing |
| /login              | Redirection to authenticator service |
| /api                | REST API relaying commands as SSH to gn-daemon |

## Configuration
Each section references a service.
Each daemon validates the sections belonging to it.

## Users
A registered user is a user that can login.

Registered users are not managed by Gorillanest dirrectly,
instead an authenticator is used.
The authenticator is a service dedicated to perform user CRUD.
Scrimshaw is the only supported authenticator.

Registered users can perform various remote commands over SSH or HTTP.

## Repository management
As mentioned registered users can perform various repository tasks
by commanding Gorillanest daemons.

Alternatively, the git root can be written by hand, similar to cgit.
Every project has to reside in a directory which's name will correspond to a user.
The directory does not have to belong to a registered user.

## Git config extensions
Git config allows for storing arbitrary data.
We utalize this to store metadata meaningful to Gorillanest within the repos themselves.

The extensions are:
    - remote [url]:
        * sync           [true|false]
        * sync-direction [push|pull]
        * sync-interval  [n-seconds]
        * sync-on-commit [true|false]
    - permissions
        * hidden [true|false]
        * write  [user-list]
    - meta:
        * description [string]
        * topic       [string-list]
