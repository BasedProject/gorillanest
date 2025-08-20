#!/usr/bin/env perl

use strict;
use warnings;

use Syntax::Keyword::Try;
use FCGI;

use lib '.';
# BEGIN { require 'config.pl'; }
BEGIN { require 'gorillanest.pl.cgi'; }

try {
    open STDERR, '>', LOG_FILE or die LOG_FILE . ": $!";
    my $sock = FCGI::OpenSocket(SOCKET_FILE, 100);
    my $request = FCGI::Request(\*STDIN, \*STDOUT, \*STDERR, \%ENV, $sock);
    while($request->Accept() >= 0) {
		master();
    }
} catch ($error) {
    info("Crashed: $error");
}
