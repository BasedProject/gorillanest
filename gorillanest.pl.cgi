#!/usr/bin/env perl

use strict;
use warnings;

use CGI;
use Template;
use URI::Escape;
use Cwd;
use Data::Dumper;
use Git::Repository;

use lib '.';
BEGIN { require 'config.pl'; }

sub info {
    warn join(' ', @_);
}

our $template = Template->new({INCLUDE_PATH => 'template'});

# significant dirs only
sub GN::directories {
    my $root = $_[0];
    opendir my $dir, $root or die "Cannot open directory '$root': $!";
    my @directories;
    my %drop = (
        '.'  => 0,
        '..' => 0,
        );
    foreach (readdir $dir) {
        push(@directories, $_) if (-d join('/', $_[0], $_) && ($drop{$_} // 1));
    }
    closedir $dir;
    return \@directories;
}

# probably should output all repos recursively, currently just outputs list of users
sub GN::index { # /
    my ($root, $dataref) = @_;
    my %data = %$dataref;
    my @directories = map { my $i = $_; map { join('/', $i, $_) } @{GN::directories(join('/', $root, $i))} } @{GN::directories($root)};
    $data{directories} = \@directories;
    if ($data{directories}) { $data{found} = 1; }
    return \%data;
}

sub GN::user { # /$username/
    my ($root, $dataref) = @_;
    my %data = %$dataref;
    my @directories = @{GN::directories(join('/', $root, $data{username}))};
    $data{directories} = \@directories;
    if ($data{directories}) { $data{found} = 1; }
    return \%data;
}

sub GN::repository { # /$username/$repository
    my ($root, $dataref) = @_;
    my %data = %$dataref;
    $data{found} = 0;
    return \%data;
}

sub serve_template {
    my ($file, @rest) = @_;
    my %vars = @rest ? @rest : ();
    
    $template->process($file, \%vars)
        or info("Template: " . $template->error());
}

my %routes = (
    '/'                                   => sub { serve_template("index.tt", @_) },
    '/~([a-zA-Z0-9_.]+)'                  => sub { serve_template("index_user.tt", @_) },
    '/~([a-zA-Z0-9_.]+)/([a-zA-Z0-9_.]+)' => sub { serve_template("repository.tt", @_) },
);

my $public = 'git/public';
my $dbfile = 'gorillanest.sqlite3';
my %data = (
    found => 0,
);

sub master {
	my $cgi = CGI->new;
	my %header = (
		-Content_Type => 'text/html',
		-charset      => 'UTF-8',
		);
	my $method = $ENV{'REQUEST_METHOD'} || '';
	my $uri = $ENV{'REQUEST_URI'} || '/';

	for my $pattern (keys %routes) {
		if ($uri =~ m{^$pattern$}) {
			my $handler = $routes{$pattern};
			$handler->($uri, $1, $2, $3);
		}
	}

	serve_template("404.tt"); # XXX missing code
}

master() if !caller; 1;
