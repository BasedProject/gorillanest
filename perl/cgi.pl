#!/usr/bin/env perl

# XXX
# why are we passing around root like a cheap whore?                            because root is where things are (f(x) -> y)
# looking into it, i think we should have a global config object using
# https://metacpan.org/pod/Readonly                                             fuck read only, constants are for faggots
#
# i modified the routing heavily, this is how people do it;                     very scary
# pretty clean
# you must also realize that not all routes are necessarily templates,          then they are routed by nginx.
# it could be a redirect for example, so the original solution would
# complicate beyond comprehension                                               ACK.

use strict;
use warnings;
use CGI;
use Template;
use URI::Escape;
use Cwd;
use Data::Dumper;
use Git::Repository;

use lib qw(. ..);
no warnings 'redefine';
BEGIN { require 'config.default.pl'; }
BEGIN { require 'config.pl'; }
use warnings 'redefine';

sub info {
    warn join(' ', @_);
}


sub serve_template {
    my $template = Template->new({INCLUDE_PATH => 'template'});
    my ($template_name, $data) = @_;

    $template->process($template_name, $data)
        or info("Template: " . $template->error());
}

# significant dirs only
sub GN::directories {
    my $root = $_[0];
    opendir my $dir, $root or die "$root: $!";
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
    my ($root) = @_;
    my %data;

    my @directories = map { my $i = $_; map { join('/', $i, $_) } @{GN::directories(join('/', $root, $i))} } @{GN::directories($root)};
    $data{directories} = \@directories;
    if ($data{directories}) { $data{found} = 1; }

    serve_template("index.tt", \%data);
}

sub GN::user { # /$username/
    my ($root, $username) = @_;

    my %data;
    my @directories = @{GN::directories(join('/', $root, $data{username}))};
    $data{directories} = \@directories;
    if ($data{directories}) { $data{found} = 1; }

    serve_template("index_user.tt", \%data);
}

sub GN::repository { # /$username/$repository
    my ($root, $username, $repository) = @_;

    die 'not implemented';
}

my $root = GIT_ROOT;
my $dbfile = DB_FILE;

my %data = (
    found => 0,
);

my %routes = (
    '/'                   => sub { GN::index($root); },
    '/~([\w.]+)'          => sub { GN::user($root, @_) },
    '/~([\w.]+)/([\w.]+)' => sub { GN::repository($root, @_) },
);
my %route_regex_cache = map { $_ => qr{^$_$} } keys %routes;

sub master {
	my $cgi = CGI->new;
	my %header = (
		-Content_Type => 'text/html',
		-charset      => 'UTF-8',
		);
	my $method = $ENV{'REQUEST_METHOD'} || '';
	my $uri = $ENV{'REQUEST_URI'} || '/';

	for my $pattern (keys %routes) {
		if ($uri =~ $route_regex_cache{$pattern}) {
			my $handler = $routes{$pattern};
			$handler->($uri, $1, $2, $3);
            return;
		}
	}

	serve_template("404.tt", {}); # XXX missing code
}

master() if !caller;

1;
