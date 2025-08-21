The relevant ulities for implementing a git server are:
* git-upload-pack
* git-recieve-pack
* git-fetch-pack
* git-send-pack

Not all of these are installed by git packages,
but they are very much real binaries produced by standard builds.

Communication model:
       (client)          (server)
    git-fetch-pack => git-upload-pack   # pull
    git-send-pack  => git-recieve-pack  # push
