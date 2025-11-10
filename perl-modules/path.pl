#!/usr/bin/env perl

use feature 'signatures';
use Data::Dumper;
use Path::Tiny;

sub directories_at_level ($root, $level) {
    $level == 0
        ? [ path($root)->stringify ]
        : [ map { @{ directories_at_level($_, $level - 1) } }
            grep { $_->is_dir }
            path($root)->children ]
    ;
}

print Dumper(directories_at_level('repositories/', 2)) unless caller;

1;
