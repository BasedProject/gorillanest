The relevant utilities for implementing a git server are:
* git-upload-pack
* git-receive-pack
* git-fetch-pack
* git-send-pack
* git-http-backend

Not all of these are installed by git packages,
but they are very much real binaries produced by standard builds.

Communication model:
       (client)          (server)
    git-fetch-pack => git-upload-pack   # pull
    git-send-pack  => git-receive-pack  # push
