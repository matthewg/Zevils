package NNTB::Weblog;

# This package provides common functions to all NNTB weblog modules.
# NNTB modules should be inherit from this.

$VERSION = '0.01';

use strict;
use warnings;
use vars qw($VERSION);
use Carp;

sub new($) {
	my $class = ref($_[0]) || $_[0] || "NNTB::Weblog";
	croak "Do not instantiate NNTB::Weblog directly; use one of its subclasses." if $class eq "NNTB::Weblog";

	shift;
	my $self = { };
	bless $self, $class;

	return $self;
}

sub log(@) {
	my $package = ref($_[0]) || $_[0];
	shift;
	::_log("$package: ", @_);
}

# These methods count as failing if unimplemented.
# They are the mandatory methods since weblog modules must override them.
sub groups(;$) { return 0; }
sub articles($;$) { return 0; }
sub article($$) { return 0; }
sub auth($$) { return 0; }
sub post($$) { return 0; }
sub isgroup($) { return 0; }
sub groupstats($) { return (); }
sub id2num($$) { return 0; }
sub num2id($$) { return 0; }

# These methods are optional - if unimplemented, they'll return success
sub logout() { return 1; }

1;
