package ConfigFrontend;

use strict;
use warnings;
use Data::Dumper;
use Config::INI::Reader::Ordered;

sub read_config {
    my $r = {};
    my $default_file = 'config.default.ini';
    my $user_file    = 'config.ini';

    my %frontend_whitelist = map { $_ => 1 } qw(
        BARE_REQUEST
        LOG_FILE
        DB_FILE
        SOCKET_FILE
        SOCKET_MAX_CONNECTIONS
        TEMPLATE_ROOT
        DISABLE_API
        USE_CGI
    );
    my %core_whitelist = map { $_ => 1 } qw(
        GIT_ROOT
    );

    my @config_array;
    push @config_array, @{ Config::INI::Reader::Ordered->read_file($default_file) };
    push @config_array, @{ Config::INI::Reader::Ordered->read_file($user_file) } if -f $user_file;

    for my $pair (@config_array) {
        my ($section, $keys) = @$pair;
        for my $key (keys %$keys) {
            my $val = $keys->{$key};
            if ($section eq 'frontend') {
                die "Unknown key in [frontend]: $key\n" unless $frontend_whitelist{$key};
                $r->{$key} = $val;
            } elsif ($section eq 'core') {
                next unless $core_whitelist{$key};
                $r->{$key} = $val;
            }
        }
    }

    no strict 'refs';
    ${'main::GLOBAL_CONFIG'} = $r;
}

1;
