package Net::OSCAR::Screenname;

$VERSION = '0.62';

use strict;
use vars qw($VERSION);

use Net::OSCAR::Common qw(normalize);
use Net::OSCAR::OldPerl;

use overload
	"cmp" => "compare",
	'""' => "stringify",
	"bool" => "boolify";

sub new($$) {
	return $_[1] if ref($_[0]) or UNIVERSAL::isa($_[1], "Net::OSCAR::Screenname");
	my $class = ref($_[0]) || $_[0] || "Net::OSCAR::Screenname";
	shift;
	my $name = "$_[0]"; # Make doubleplus sure that name isn't one of us
	my $self = \$name;
	bless $self, $class;
	return $self;
}

sub compare {
	my($self, $comparand) = @_;

	return normalize($$self) cmp normalize($comparand);
}

sub stringify { my $self = shift; return $$self; }

sub boolify {
	my $self = shift;
	return 0 if !defined($$self) or $$self eq "" or $$self eq "0";
	return 1;
}

1;
