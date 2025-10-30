# always assume anything to do with files or directories is ran at project root

use constant {

# If you're using lighttpd, set this to 1
# This disables SOCKET_FILE and lets the socket handling be externally managed
BARE_REQUEST           => 0,

IMMORTAL               => 1, # will continue handling request after death/error

LOG_FILE               => '/tmp/gorillanest.log',
DB_FILE                => 'gorillanest.sqlite3', # sqlite3

SOCKET_FILE            => '/tmp/gorillanest.socket',
SOCKET_MAX_CONNECTIONS => 100,

TEMPLATE_ROOT          => 'www/template', # template directory
GIT_ROOT               => 'repositories',      # git directory (~user/repo)

};

1;
