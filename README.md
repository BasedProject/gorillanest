# Gorillanest

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

## URL scheme
| Path                | Description |
| :------------------ | :---------- |
| /                   | Index |
| /api                | REST API relaying commands as SSH to gn-daemon |
| /explore            | Project listing |
| /login              | Redirection to authenticator service |
| /~{user}            | User index |
| /~{user}/{repo}     | Repository index |
| /~{user}/{repo}.git | HTTP git clone endpoint |

## Configuration
Each section references a service.
Each daemon validates the section(s) it reads.

## Users
A registered user is a user that can login.

Registered users are not managed by Gorillanest dirrectly,
instead an authenticator is used.
The authenticator is a service dedicated to perform user CRUD.
Scrimshaw is the only supported authenticator.

Registered users can perform various remote commands over SSH or HTTP.

The user `git` is reserved for anonymous clones over SSH.

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
    - meta:
        * description [string]
        * topic       [string-list]
    - remote [url]:
        * sync-direction [push|pull|none]
    - permissions
        * hidden [true|false]
        * write  [user-list]
