#!/usr/bin/perl

use strict;
use warnings;
use feature 'signatures';
use IPC::Open2;
use Data::Dumper;
use Cwd 'realpath';
use File::Basename;
use Path::Tiny;
use Git::Repository;
use String::Util 'trim';

sub new_repository {
    my ($path) = @_;
    $path = realpath($path);
    return undef unless $path;

    my $name = basename($path);
    my $repo;
    eval { $repo = Git::Repository->new(work_tree => $path); };
    do {
        print STDERR "!! " . $@ . "\n";
        return undef;
    } unless not $@;

    my $has_commits = eval { $repo->run('rev-parse', '--verify' => 'HEAD') };
    return {} unless $has_commits;

    my @raw_branches = $repo->run('branch');
    my @branches;

    for my $b (@raw_branches) {
        $b = trim($b);
        my $is_active = 0;

        if ($b =~ /^\* /) {
            $b =~ s/^\* //;
            $is_active = 1;
        }

        my @commits;
        my @logs = $repo->run(
            log => $b,
            '--pretty=format:%H;%an;%ad;%s',
            '--date=format:%Y-%m-%dT%H:%M:%SZ'
        );
        for my $line (@logs) {
            my ($hash, $author, $date, $message) = split /;/, $line, 4;
            push @commits, {
                hash    => $hash,
                author  => $author,
                date    => $date,
                message => $message,
            };
        }

        push @branches, {
            name      => $b,
            is_active => $is_active,
            commits   => \@commits,
        };
    }

    # first commiter as a fallback # XXX
    my $owner = ($repo->run('log', '--reverse', '--pretty=format:%an'))[0];

    my @files = $repo->run('ls-tree', '--name-only', 'HEAD');

    my $description = $repo->run('config', 'get', 'meta.description');

    return {
        name        => $name,
        owner       => $owner,
        branches    => \@branches,
        files       => \@files,
        h_repo      => $repo,
        description => $description,
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

sub txt2html ($txt) {
    $txt =~ s/</&lt;/g;
    $txt =~ s/>/&gt;/g;
    return "<pre>$txt</pre>";
}

sub new_readme {
    my ($h_repository) = @_;

    # Plain text
    for my $f ('README', 'README.txt') {
        if (does_exist_in_repository($f, $h_repository)) {
            my $text = git_cat($h_repository->{path}, $f);
            return txt2html($text);
        }
    }

    # Markdown
    if (does_exist_in_repository("README.md", $h_repository)) {
        my $text = git_cat($h_repository, 'README.md');
        my ($in, $out);
        my $pid = eval {
            open2($out, $in, 'ts-md2html', '/dev/stdin');
        };

        if ($@) {
            $text = txt2html($text);
            return '<h2>!!! MD -> HTML CONVERTER MISSING; USING PLAIN TEXT !!!</h2>' . $text;
        };

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

sub repository_to_link ($repo) {
    my $r = $repo;

    $r =~ s/\.git$//;
    $r = "/~$r";

    return $r;
}

sub repository_to_name ($repo) {
    my $r = $repo;

    $r =~ s/\.git$//;

    return $r;
}

print Dumper( new_repository('./') ) unless caller;

1;
