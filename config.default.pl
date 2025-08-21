# always assume anything to do with files is from project root

use constant LOG_FILE => '/tmp/gorillanest.log';
use constant SOCKET_FILE => '/tmp/gorillanest.socket';
use constant DB_FILE => 'gorillanest.sqlite3'; # sqlite3

use constant TEMPLATE_ROOT => 'template'; # template directory
use constant GIT_ROOT => 'git'; # git directory (~user/repo)

# If you're using lighttpd, set this to 1
# This disables SOCKET_FILE and lets the socket handling be externally managed
use constant BARE_REQUEST => 0;

use constant SOCKET_MAX_CONNECTIONS => 100;
1;
