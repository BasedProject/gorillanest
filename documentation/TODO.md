* currently we are operating in read-only beta mode
* some paths are hardcoded; such as link PATH/cgi/git-init, but git-init is never system installed under normal circumstances
* syncing
* mirroring
* there is no restriction on ssh pushing / pulling; this could be fixed by having a pseudo file system for every user with mount+chroot; this makes cooperation easy to implement
* cooperation
* the ini parser Perl uses, only supports ; comments
* if a repository cannot be read due to permissions, a more helpful message should be provided than "404 its so fucking over"
* repository names can only contain word characters, which is a feature and not a bug; however, if someone hand inserts a repository with non-word chars in its names, the 404 is confusing and a footgun
