* currently we are operating in read-only beta mode
* some paths are hardcoded
* syncing
* mirroring
* there is no restriction on ssh pushing / pulling; this could be fixed by having a pseudo file system for every user with mount+chroot; this makes cooperation easy to implement
* cooperation
* the ini parser Perl uses, only supports ; comments
* if a repository cannot be read due to permissions, a more helpful message should be provided than "404 its so fucking over"
