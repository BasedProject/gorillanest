#!/usr/bin/perl

use strict;
use warnings;
use feature 'signatures'; # XXX
use Git::Repository;
use Cwd 'realpath';
use File::Basename;
use IPC::Open2;

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

    # first commiter as a fallback
    my $owner = ($repo->run('log', '--reverse', '--pretty=format:%an'))[0];

    my @files = $repo->run('ls-tree', '--name-only', 'HEAD');

    return {
        name     => $name,
        owner    => $owner,
        branches => \@branches,
        files    => \@files,
        h_repo   => $repo,
    };
}

sub git_cat ($h_repository, $path) {
    my $content = $h_repository->{h_repo}->run('show', "HEAD:$path");
    return "" if $@;
    return $content;
}

sub does_exist_in_repository {
    my ($path, $h_repository) = @_;
    my $files = $h_repository->{files};

    return scalar grep { $_ eq $path } @$files;
}

sub new_readme {
    my ($h_repository) = @_;

    # Plain text
    for my $f ('README', 'README.txt') {
        if (does_exist_in_repository($f, $h_repository)) {
            my $text = read_git_file($h_repository->{path}, 'HEAD', $f);
            $text =~ s/</&lt;/g;
            $text =~ s/>/&gt;/g;
            return "<pre>$text</pre>";
        }
    }

    # Markdown
    if (does_exist_in_repository("README.md", $h_repository)) {
        my $text = git_cat($h_repository, 'README.md');
        my ($in, $out);
        my $pid = open2($out, $in, 'ts-md2html', '/dev/stdin')
            or die "failed to run ts-md2html: $!";

        print $in $text;
        close $in;

        local $/;
        my $html = <$out>;
        close $out;

        waitpid($pid, 0);
        return $html;
    }

    return "";
}

print Dumper( new_repository('./') ) unless caller;

1;
