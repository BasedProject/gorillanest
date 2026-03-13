# Gorillanest
> ACTIVATION PHRASE: GIT IN THE GORILLA NEST!

Gorillanest is a Git-server,
that provides a web-frontend and an SSH interface.

> [!CAUTION]
> Gorillanest is currently in an Alpha testing phase!

> [!CAUTION]
> Not everything mentioned in the documentation is implemented yet!

## Features
* Read/write or read-only git serving
* Anonymous SSH clones
* Trivial to restore/migrate
* Mirroring of repositories, users or instances
* UNIX philosophy abiding

## Rationale
**TL;DR:** Gitea broke so I had a low wage Hungarian programmer write this.

Git servers tend to fall into two categories:
* suckless read-only frontends
* überbloat web services

The simpler stuff -such as cgit- does flawlessly what it says it does,
however miss a number of functionality which would be crucial for hobbyists.

The larger stuff -such as gitea- has most of the features one could want and plenty more,
but has a tendency to break in various hard to restore ways,
while still not being entirely satisfactory.

Gorillanest aims to sit in the middle.
The target audience is based internet schitzos.

## Dependencies
* Perl (and environment as specified by `cpanfile`)
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

Registered users are not managed by Gorillanest directly,
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
