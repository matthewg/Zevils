package Slash::PSM::test;
use strict;
use Carp qw(cluck croak carp confess);
use vars qw($VERSION @ISA);
@ISA = ('Slash::PSM::SlashSite');
$VERSION = '0.01';

sub load($$$$$) { #load up an existing SlashSite
	my($class, $psmver, $frontend, $slashsite, $confdir) = @_;
	my $self = {};
	bless $self, $class;
	$self->{_psmver} = $psmver;
	$self->{_frontend} = $frontend;
	$self->{_slashsite} = $slashsite;
	$self->{_confdir} = $confdir;
	$self->{_capabilities}{sections} = 1;
	$self->{_capabilities}{topics} = 1;

	return $self;
}

sub Section($$) { print "Test Section $_[1]\n"; 1; }
sub Topic($$) { return undef; }

1;

