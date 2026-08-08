package PermissionDB;

use strict;
use warnings;
use feature 'signatures';
use DBI;

sub connect($db_path) {
    my $dbh = DBI->connect(
        "dbi:SQLite:dbname=$db_path", "", "",
        { RaiseError => 1, AutoCommit => 1 }
    ) or die "Unable to open permission cache '$db_path': $DBI::errstr";

    # We're the sole writer, but gn-daemon (and possibly other services)
    # read concurrently. WAL lets readers proceed without blocking on us.
    $dbh->do("PRAGMA journal_mode = WAL");

    _init_schema($dbh);
    return $dbh;
}

sub _init_schema($dbh) {
    $dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS permissions (
    username  TEXT NOT NULL,
    repo_key  TEXT NOT NULL,
    PRIMARY KEY (username, repo_key)
)
SQL
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_permissions_repo ON permissions(repo_key)");
}

sub grant_write($dbh, $repo_key, @users) {
    return unless @users;
    my $sth = $dbh->prepare_cached(
        "INSERT OR IGNORE INTO permissions (username, repo_key) VALUES (?, ?)"
    );
    $sth->execute($_, $repo_key) for @users;
}

# we revoke and grant all repo permissions on recalculation
sub revoke_repo($dbh, $repo_key) {
    $dbh->do("DELETE FROM permissions WHERE repo_key = ?", undef, $repo_key);
}

sub clear_all($dbh) {
    $dbh->do("DELETE FROM permissions");
}

sub with_transaction($dbh, $code) {
    $dbh->begin_work;
    my @result = eval { $code->() };
    if ($@) {
        $dbh->rollback;
        die $@;
    }
    $dbh->commit;
    return @result;
}

sub writable_repos($dbh, $username) {
    my $sth = $dbh->prepare_cached(
        "SELECT repo_key FROM permissions WHERE username = ? ORDER BY repo_key"
    );
    $sth->execute($username);
    return [ map { $_->[0] } @{ $sth->fetchall_arrayref([0]) } ];
}

# for debugging
sub dump_all($dbh) {
    my $sth = $dbh->prepare("SELECT username, repo_key FROM permissions ORDER BY username, repo_key");
    $sth->execute;
    my %out;
    while (my ($user, $repo) = $sth->fetchrow_array) {
        push @{ $out{$user} }, $repo;
    }
    return \%out;
}

1;
