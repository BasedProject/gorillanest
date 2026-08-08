#!/usr/bin/perl
use strict;
use warnings;
use feature 'signatures';
use Path::Tiny;
use Data::Dumper;
use Linux::Inotify2;
use IO::Select;
require 'perl-modules/config-frontend.pl';
require 'perl-modules/sanity-check.pl';
require 'perl-modules/permissions-db.pl';

# seconds
use constant FULL_POLL_INTERVAL => 300;

our $GLOBAL_CONFIG;
ConfigFrontend::read_config();

my $git_root = $GLOBAL_CONFIG->{'GIT_ROOT'};

# Table of tracked items for modify events.
# Helps to discover new data and to prevent duplicate inotify instantiation
#
#   users        => { $username => 1, ... }
#   repositories => { "$owner/$repo" => 1, ... }
#   watches      => { $path_string => $watch_object, ... }   # for ->cancel()
our %polling_table = (
    users        => {},
    repositories => {},
    watches      => {},
);

# Cache storage
my $db_path = 'user-permission-cache.sqlite';
my $dbh = PermissionDB::connect($db_path);

#
my $inotify = Linux::Inotify2->new
    or die "Unable to create inotify object: $!";

sub get_users($git_root) {
    my $r = [];
    for my $candidate (path($git_root)->children) {
        next unless $candidate->is_dir;
        my $name = $candidate->basename;
        next unless SanityCheck::is_valid_username($name);
        push @$r, $name;
    }
    return $r;
}

sub get_repositories($git_root, $user) {
    my $r = [];
    for my $candidate (path($git_root, $user)->children) {
        next unless $candidate->is_dir;
        my $name = $candidate->basename;
        next unless SanityCheck::is_valid_repository_name($name);
        push @$r, $name;
    }
    return $r;
}

sub get_write_authorised_users($git_root, $user, $repository) {
    # hash for easy dedupping
    my %authorised = ( $user => 1 );

    my $config_path = path($git_root, $user, $repository, 'config');
    if ($config_path->is_file) {
        my $raw = qx(git config -f @{[$config_path->stringify]} --get permissions.write 2>/dev/null);
        my $exit_code = $? >> 8;

        return [ keys %authorised ] unless $exit_code == 0;

        chomp $raw;

        return [ keys %authorised ] unless length $raw;

        for my $c (map { s/^\s+|\s+$//gr } split /,/, $raw) {
            next unless length $c;
            unless (SanityCheck::is_valid_username($c)) {
                warn "Ignoring invalid collaborator '$c' in $config_path\n";
                next;
            }
            $authorised{$c} = 1;
        }
    }

    return [ keys %authorised ];
}

# Git-config performs atomic writes with rename.
# Inotify is tied to the inode.
# If we were to watch the file itself, we would be watching orphaned inodes.
# Therefor we must watch the parent.
sub watch_repo_dir($git_root, $owner, $repo) {
    my $key = path($git_root, $owner, $repo)->stringify;
    return if $polling_table{watches}{$key};

    my $watch = $inotify->watch(
        $key,
        IN_CREATE | IN_MOVED_TO | IN_CLOSE_WRITE,
        sub ($e) {
            return unless $e->name eq 'config';
            on_git_config_change(path($git_root, $owner, $repo, 'config'));
        },
    ) or do { warn "Failed to watch '$key': $!\n"; return; };

    $polling_table{watches}{$key} = $watch;
}

sub watch_user_home($git_root, $user) {
    my $key = path($git_root, $user)->stringify;
    return if $polling_table{watches}{$key};

    my $watch = $inotify->watch(
        $key,
        IN_CREATE | IN_DELETE | IN_MOVED_TO | IN_MOVED_FROM,
        sub ($e) { on_user_home_change(path($git_root, $user)) },
    ) or do { warn "Failed to watch '$key': $!\n"; return; };

    $polling_table{watches}{$key} = $watch;
}

sub watch_git_root($git_root) {
    my $key = path($git_root)->stringify;
    return if $polling_table{watches}{$key};

    my $watch = $inotify->watch(
        $key,
        IN_CREATE | IN_DELETE | IN_MOVED_TO | IN_MOVED_FROM,
        sub ($e) { on_git_root_change(path($git_root)) },
    ) or do { warn "Failed to watch '$key': $!\n"; return; };

    $polling_table{watches}{$key} = $watch;
}

sub unwatch($path_string) {
    my $watch = delete $polling_table{watches}{$path_string};
    $watch->cancel if $watch;
}

sub do_full_poll($git_root) {
    $polling_table{users}        = {};
    $polling_table{repositories} = {};

    watch_git_root($git_root);

    PermissionDB::with_transaction($dbh, sub {
        PermissionDB::clear_all($dbh);

        for my $owner (@{ get_users($git_root) }) {
            $polling_table{users}{$owner} = 1;
            watch_user_home($git_root, $owner);

            for my $repo (@{ get_repositories($git_root, $owner) }) {
                my $repo_key = "$owner/$repo";
                $polling_table{repositories}{$repo_key} = 1;
                watch_repo_dir($git_root, $owner, $repo);

                PermissionDB::grant_write(
                    $dbh, $repo_key,
                    @{ get_write_authorised_users($git_root, $owner, $repo) }
                );
            }
        }
    });

    print STDERR "Full poll cycle performed.\n"
}

# New user directory appeared/disappeared directly under $git_root
sub on_git_root_change($path) {
    my %current = map { $_ => 1 } @{ get_users($git_root) };

    for my $user (keys %current) {
        next if $polling_table{users}{$user};
        $polling_table{users}{$user} = 1;
        watch_user_home($git_root, $user);
        on_user_home_change(path($git_root, $user));   # pick up any repos already inside
    }

    for my $user (keys %{ $polling_table{users} }) {
        next if $current{$user};
        delete $polling_table{users}{$user};
        unwatch(path($git_root, $user)->stringify);

        for my $repo_key (grep { m{^\Q$user\E/} } keys %{ $polling_table{repositories} }) {
            my (undef, $repo) = split m{/}, $repo_key, 2;
            unwatch(path($git_root, $user, $repo)->stringify);
            delete $polling_table{repositories}{$repo_key};
            remove_repo_from_permissions($repo_key);
        }
    }
}

# New repository directory appeared/disappeared under a user's home
sub on_user_home_change($path) {
    my $owner = $path->basename;
    return unless $polling_table{users}{$owner};   # stale event for a since-removed user

    my %current = map { +"$owner/$_" => 1 } @{ get_repositories($git_root, $owner) };

    for my $repo_key (keys %current) {
        next if $polling_table{repositories}{$repo_key};
        $polling_table{repositories}{$repo_key} = 1;
        my (undef, $repo) = split m{/}, $repo_key, 2;
        watch_repo_dir($git_root, $owner, $repo);

        PermissionDB::grant_write($repo_key, @{ get_write_authorised_users($git_root, $owner, $repo) });
    }

    for my $repo_key (keys %{ $polling_table{repositories} }) {
        next unless $repo_key =~ m{^\Q$owner\E/};
        next if $current{$repo_key};
        my (undef, $repo) = split m{/}, $repo_key, 2;
        unwatch(path($git_root, $owner, $repo)->stringify);
        delete $polling_table{repositories}{$repo_key};
        PermissionDB::revoke_repo($dbh, $repo_key);
    }
}

sub on_git_config_change($path) {
    # $path is */repositories/<owner>/<repo>/config
    my $repo_dir = $path->parent;
    my $owner    = $repo_dir->parent->basename;
    my $repo     = $repo_dir->basename;
    my $repo_key = "$owner/$repo";

    # stale/unknown repo
    return unless $polling_table{repositories}{$repo_key};

    PermissionDB::with_transaction($dbh, sub {
        PermissionDB::revoke_repo($dbh, $repo_key);
        PermissionDB::grant_write(
            $dbh, $repo_key,
            @{ get_write_authorised_users($git_root, $owner, $repo) }
        );
    });
}

do_full_poll($git_root);
#print Dumper(PermissionDB::dump_all($dbh));

$inotify->on_overflow(sub {
    warn "inotify queue overflow -- events were dropped, forcing a full poll\n";
    do_full_poll($git_root);
});

my $selector = IO::Select->new($inotify->fileno);

while (1) {
    my @ready = $selector->can_read(FULL_POLL_INTERVAL);
    if (@ready) {
        $inotify->poll;
    } else {
        do_full_poll($git_root);
    }
}
