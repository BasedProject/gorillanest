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

    my $name = basename($path, ".git");
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
    my $content = eval { $h_repository->{h_repo}->run('show', "HEAD:$path") };
    return undef if $@;
    return $content;
}

sub does_exist_in_repository ($path, $h_repository) {
    my $files = $h_repository->{files};
    return scalar grep { $_ eq $path } @$files;
}

# XXX
#  bad architecture, git has nothing to do with html
#  solve it with git_get_readme which returns a path,
#  combine it with git_cat and move all the logic upward or into a new module
sub txt2html ($txt) {
    $txt =~ s/</&lt;/g;
    $txt =~ s/>/&gt;/g;
    return "<pre>$txt</pre>";
}

sub new_readme ($h_repository) {
    # Plain text
    for my $f ('README', 'README.txt') {
        if (does_exist_in_repository($f, $h_repository)) {
            my $text = git_cat($h_repository, $f);
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

        local $SIG{PIPE} = 'IGNORE';

        my $ok = print {$in} $text;
        close $in or $ok = 0;

        local $/;
        my $html = <$out>;
        close $out;

        waitpid($pid, 0);

        if (!$ok || $? != 0) {
            return '<h2>!!! README CONSTRUCTING SUBPROCESS EXITED WITH CATASTROPHIC ERROR !!!<br>'
                 . ' Please consult the server logs for more information.';
        }

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
