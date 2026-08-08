package SanityCheck;

use strict;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';

my $WORD_CHARS = qr/^[-\w]+$/;

sub is_valid_username($name) {
    return 0 unless defined $name;
    return $name =~ $WORD_CHARS ? 1 : 0;
}

# XXX must be split in two and wrap (find_bad_chars ensure_suffix)
# add check for reserved user "git"
sub is_valid_repository_name($name) {
    return 0 unless defined $name;
    return 0 unless $name =~ /\.git$/;   # bare .git suffix required
    (my $repo_name = $name) =~ s/\.git$//;
    return $repo_name =~ $WORD_CHARS ? 1 : 0;
}

1;
