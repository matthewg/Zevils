package Slash::PSM;
use strict;
use Carp qw(cluck croak carp confess);
use vars qw($VERSION $errstr $errlevel $errnum $confdir @capabilities);
$VERSION = '0.01';

$confdir = "/etc/slash/";	#Under here goes psm.d/, psm/ (PSM-specific
				#configuration files), and psm.conf

@capabilities = qw(auth permissions userdata sections topics stories
	comments moderation metamod vars polls);
				#auth - user/author/admin authentication
				#permissions - user permissions, such as
				#	whether or not a user can post stories
				#userdata - Stores all information about a user,
				#	including preferences.  Also responsible
				#	for listing users.
				#sections - List/edit sections
				#topics - List/edit topics
				#stories - Get/edit stories
				#comments - Get/post comments
				#moderation - Moderate comments
				#metamod - Moderate moderation
				#vars - Storage and retrieval of frontend vars

sub PSM_ERR_OK() { 0; }
sub PSM_ERR_DEBUG() { 1; }
sub PSM_ERR_WARN() { 2; }
sub PSM_ERR_IMP() { 3; }
sub PSM_ERR_CRIT() { 4; }

sub _noinherit($$$) {
	my($class, $method, $shouldbe) = ((ref($_[0]) || $_[0]), $_[1], $_[2]); #Heh, that's not very pretty, is it?
	$Carp::CarpLevel++; #Don't show _noinherit in stack trace
	_crapout(Slash::PSM::PSM_ERR_CRIT, 4, "PSM $class did not override the $method method!") if $class ne $shouldbe;
}

sub new($$$$;$) {
	my($self, $psmver, $frontend, $slashsite, $conf, $psm, $capability, $cpsm, $currcape, %seencapes, $class) = @_;

	$class = ref($self) || $self;

	$confdir = $conf if $conf;
	_loadconf("$confdir/psm.conf");
	my $obj = Slash::PSM::SlashSite->load($psmver, $frontend, $slashsite, $confdir); #Create the SlashSite object
	return $obj unless $obj; #If SlashSite->load returns an error, pass it on
	open CONFIG, "<$confdir/psm.d/$frontend" or #Always include the leading <.  Otherwise, a malicious user might be able to set $confdir to something like |rm -rf /\0 (see the latest Phrack for details.)  That would be Bad.
		open CONFIG, "<$confdir/psm.d/other" or 
			_crapout(PSM_ERR_CRIT, 1, "Couldn't load $confdir/psm.d/$frontend or $confdir/psm.d/other");
	while(<CONFIG>) {
		chomp;
		s/#.*//; #Strip comments
		s/^\s+//; #Strip leading whitespace
		s/\s+$//; #Strip trailing whitespace
		next unless $_; #Skip blank lines
		($capability, $psm) = split(/\s+/); #Split on whitespace
		$capability = lc($capability);

		#For every capability, there's an array containing the names of the PSMs to use for that capability, in order

		if($capability eq "other" or $capability eq "all") { #Add $psm to every (unseen?) capability
			foreach $currcape(@capabilities) {
				next if $seencapes{$currcape} and $capability eq "other";
				push @{$obj->{_capabilities}{$currcape}}, $psm;
			}
		} else {
			$seencapes{$capability} = 1;
			push @{$obj->{_capabilities}{$capability}}, $psm;
		}

		#Build a list of PSMs.  We use this to load them up.

		${$obj->{PSMs}}->{$psm} = {};
	}

	foreach $psm(keys %${$obj->{PSMs}}) { #Load up the PSMs
		eval "require Slash::PSM::$psm" or _crapout(PSM_ERR_CRIT, 2, "Couldn't load PSM $psm"); #Load the module

		#Now we're going to create a SlashSite object from the PSM.  That's what PSMs do - make objects inherited from Slash::PSM::SlashSite.
		#We will have a bunch of these stored in %{$obj->{PSMs}}.  So, we support multiple PSMs for the same capability through a combination of
		#that hash and @{$obj->{_capabilities}{$capability}}.  If you're still confused, try dumping $obj after the end of this foreach using
		#Data::Dumper.

		{
			#we need to allow indirect references
			no strict 'refs';
			
			#The following line is, as Grandpa Simpson would say, long as a mule and twice as ugly.
			#$obj is a reference to a SlashSite object.  In Perl, objects are really just special hashrefs.
			#$obj->{PSMs} is a hashref as well.  Its keys are in turn hashrefs, which are the PSM objects.
			#{"Slash::PSM::" . $psm . "::load"} is an "indirect reference" to the load sub in the package for PSM whose name is stored in $psm.
			#	One way of doing indirect references is by putting the name of a variable inside {curly braces}.  ${"foo"} is an indirect
			#	reference to foo.  This is a pretty powerful technique, although if used carelessly it sacrafices readability.
			#
			#So we're doing is calling the load method of the package for the PSM whose name is stored in $psm, and storing it deep inside $obj.
			#
			#Now go take some asprin, drink a glass of water, have a nice nap, and look at this code again when you wake up <G>
			#(In other words, this is why Perl critics complain that Perl is difficult to read.)

			${$obj->{PSMs}}->{$psm} = &{"Slash::PSM::" . $psm . "::load"}("Slash::PSM::$psm", $obj->{_psmver}, $obj->{_frontend}, $obj->{slashsite}, $obj->{_confdir});
		}

		#Now we have to make sure that the PSM we just loaded provides all the capabilities that the user is trying to use it for.

		foreach $capability(@capabilities) {
			foreach $cpsm(@{$obj->{_capabilities}{$capability}}) {
				next unless $cpsm eq $psm; 
				#We got this far, so we are trying to use $psm for $capability.
				next if ${$obj->{PSMs}}->{$psm}->{_capabilities}{$capability}; #All PSMs must load the _capabilities hash with the capabilties that they provide.
				_crapout(PSM_ERR_CRIT, 3, "Tried to load PSM $psm for capability $capability, but that PSM does not provide that capability!");
			}
		}
	}

	return $obj;
}

sub _loadconf($) { } #This is a no-op for now, as PSM.pm doesn't take any configuration options yet.

sub _crapout($$$) {
	$Carp::CarpLevel++; #Don't display _crapout in stack trace
	shift unless $_[0] =~ /^\d+$/; #Support OO-syntax
	($errlevel, $errnum, $errstr) = @_;
	confess $errstr if $errlevel == PSM_ERR_CRIT;
	cluck $errstr;
	$Carp::CarpLevel--;
}

#The actual packages s/PSM-/PSM::/ in their package statement, but I wanted PSM/ to be reserved for the PSMs themselves.
require Slash::PSM_SlashSite;

1;
