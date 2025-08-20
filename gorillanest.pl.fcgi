#!/usr/bin/env perl

use strict;
use warnings;

use Syntax::Keyword::Try;
use FCGI;

require "gorillanest.pl.cgi";

our $request = FCGI::Request();

try {
    while($request->Accept() >= 0) {
		master();
    }
} catch ($error) {
    info("Crashed: $error");
}
