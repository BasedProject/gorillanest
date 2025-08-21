#!/usr/bin/env perl

use strict;
use warnings;

use Syntax::Keyword::Try;
use FCGI;

use lib qw(perl);
BEGIN { require 'cgi.pl'; }

while (1) {
    try {
        my $request = FCGI::Request( \*STDIN, \*STDOUT, \*STDERR, \%ENV, BARE_REQUEST ? 0 : FCGI::OpenSocket(SOCKET_FILE, SOCKET_MAX_CONNECTIONS));
        my ($data, $routes, $routes_cache) = GN::init();
        while($request->Accept() >= 0) {
            GN::cgi($data, $routes, $routes_cache);
        }
    } catch ($error) {
        info("Crashed: $error");
    }
    exit 1 unless (IMMORTAL);
}
