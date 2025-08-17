#!/usr/bin/perl

use strict;
use warnings;
use Git::Repository;
use Cwd 'realpath';
use File::Basename;

use Data::Dumper;

sub new_repository {
    my ($path) = @_;
    $path = realpath($path);

    my $name = basename($path);
    my $repo = Git::Repository->new(work_tree => $path);

    my @raw_branches = $repo->run('branch');
    my @branches;

    for my $b (@raw_branches) {
        chomp $b;
        my $is_active = 0;

        if ($b =~ /^\* /) {
            $b =~ s/^\* //;
            $is_active = 1;
        }

        my @commits;
        my @logs = $repo->run(log => $b, '--pretty=format:%H;%an;%s');
        for my $line (@logs) {
            my ($hash, $author, $message) = split /;/, $line, 3;
            push @commits, {
                hash    => $hash,
                author  => $author,
                message => $message,
            };
        }

        push @branches, {
            name      => $b,
            is_active => $is_active,
            commits   => \@commits,
        };
    }

    my $owner = $repo->run('log', '--reverse', '--pretty=format:%an');

    return {
        name     => $name,
        owner    => $owner,
        branches => \@branches,
    };
}

print Dumper( new_repository('./') );
