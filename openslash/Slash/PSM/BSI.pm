package Slash::PSM::BSI;
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
	$self->{_capabilities}{auth} = 1;
	$self->{_capabilities}{permissions} = 1;
	$self->{_capabilities}{userdata} = 1;
	$self->{_capabilities}{sections} = 1;
	$self->{_capabilities}{topics} = 1;
	$self->{_capabilities}{stories} = 1;
	$self->{_capabilities}{comments} = 1;
	$self->{_capabilities}{moderation} = 1;
	$self->{_capabilities}{metamod} = 1;
	$self->{_capabilities}{vars} = 1;

	return $self;
}

sub Section($$) { print "Section $_[1]\n"; 1; }
sub Topic($$) { print "Topic $_[1]\n"; 1; }
sub User($$) { print "User $_[1]\n"; 1; }
sub Story($$) { print "Story $_[1]\n"; 1; }
sub Comment($$) { print "Comment $_[1]\n"; 1; }
sub FrontendVar($$;$$) { shift; print "FrontendVar ", join(", ", @_), "\n"; 1; }

1;

