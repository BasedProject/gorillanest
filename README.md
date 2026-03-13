# Gorillanest
> ACTIVATION PHRASE: GIT IN THE GORILLA NEST!

Gorillanest is a Git server.
It provides a web-frontend and an SSH interface.

## Dependencies
* Perl
* Python (and environment as specified by `requirements.txt`)
* Git
* Lighttpd
* [Hivemind](https://github.com/DarthSim/hivemind)

**Optional:**
* Scrimshaw

## Running
```sh
./gorillanest
```

## Configuration
Gorillanest is internally made up of multiple services.
`config.ini` your main way of configuration.
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
Specifically, the scripts under `PATH/daemon/` can be executed by authorized remote users.
(None of those scripts allow for arbitrary remote code execution
and you should never add one that does.)

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
