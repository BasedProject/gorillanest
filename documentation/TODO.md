* currently we are operating in read-only beta mode
* some paths are hardcoded; such as link PATH/cgi/git-init, but git-init is never system installed under normal circumstances
* syncing
* mirroring
* there is no restriction on ssh pushing / pulling; this could be fixed by having a pseudo file system for every user with mount+chroot; this makes cooperation easy to implement
* cooperation
* the ini parser Perl uses, only supports ; comments
