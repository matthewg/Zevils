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



1;
