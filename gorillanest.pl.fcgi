#!/usr/bin/env perl

use strict;
use warnings;

use Syntax::Keyword::Try;
use FCGI;

use lib '.';
BEGIN { require 'gorillanest.pl.cgi'; }

while (1) {
    try {
        open STDERR, '>', LOG_FILE or die LOG_FILE . ": $!";
        my $request = FCGI::Request( \*STDIN, \*STDOUT, \*STDERR, \%ENV, BARE_REQUEST ? 0 : FCGI::OpenSocket(SOCKET_FILE, SOCKET_MAX_CONNECTIONS));
        while($request->Accept() >= 0) {
            master();
        }
    } catch ($error) {
        info("Crashed: $error");
    }
    exit 1 unless (IMMORTAL);
}
