package Slash::PSM::SlashSite;
use strict;
use Carp qw(cluck croak carp confess);
no strict 'subs';
use vars qw(@ISA $AUTOLOAD);
@ISA = ('Slash::PSM');

#I should explain sub _AUTOLOAD.
#This is an adaptation of the technique given in The Perl Cookbook 13.11 (p468).
#Nobody should be accessing our internal hash directly.  To get to our properties, we want them to go through methods.
#But those methods are annoying to write.  So we list all readable properties in %rfields and all writable properties in %wfields (these aren't mutually inclusive or exlusive).
#Then, when someone tries to call one of our methods and we don't know about that method, it goes to AUTOLOAD.  AUTOLOAD will check %rfields/%wfields, and if it
#	sees that it should make an accessor method for us, it does so.  Pretty sweet.

sub _autoload { #I don't like having to duplicate AUTOLOAD code, but I don't want AUTOLOAD to be inherited since I want packages to explicitly request this autoload behavior.
	my($self) = shift;
	my($rfields, $wfields, %rfields, %wfields) = @_;
	%rfields = %$rfields; %wfields = %$wfields;

	my $attr = $AUTOLOAD;
	$attr =~ s/.*:://;
	return unless $attr =~ /[^A-Z]/; # skip DESTROY and all-cap methods
	confess "Invalid attribute method: ->$attr()" unless $rfields{$attr} or $wfields{$attr};
	if(@_) {
		confess "Cannot write to $attr" unless $wfields{$attr};
		$self->{$attr} = shift;
	} else {
		confess "Cannot read $attr" unless $rfields{$attr};
		return $self->{$attr};
	}
}

sub AUTOLOAD {
	my($self, %rfields, %wfields) = shift;

	return unless ref($self) eq "Slash::PSM::SlashSite" or $self eq "Slash::PSM::SlashSite"; #Don't allow this method to be inherited.
	for my $attr (qw(PSMs)) { $rfields{$attr}++; }
	for my $attr (qw()) { $wfields{$attr}++; }

	$_[0]->_autoload(\%rfields, \%wfields);
}

sub load($$$$$) { #load up an existing SlashSite
	my($self, $psmver, $frontend, $slashsite, $confdir, $class) = @_;

	$class = ref($self) || $self; #In case $self is an object, we want the classname
	$self->_noinherit('load', 'Slash::PSM::SlashSite');
	$self = {};
	bless $self, $class;
	$self->{_psmver} = $psmver;
	$self->{_frontend} = $frontend;
	$self->{_slashsite} = $slashsite;
	$self->{_confdir} = $confdir;
	return $self;
}

sub _psmloader {	#Call method $_[0] in PSMs with capability $_[1]
			#When a non-false value is returned, return it
			#If nothing is returned, warn that $method $_[0] not found
			#	and return undef
	my($method, $capability, $self, $psm, $class, $ret) = (shift, shift, shift); #Since we need @_

	no strict 'refs';

	$class = ref($self) || $self; #Get the class of $self

	foreach $psm(@{$self->{_capabilities}{$capability}}) {
		$ret = ${$self->{PSMs}}->{$psm}->$method(@_);
		return $ret if $ret;
	}
	$self->_crapout(Slash::PSM::PSM_ERR_WARN, 5, "$method $_[0] not found");
	return undef;
}

#Things we need to provide access to: Section, Topic, User, Story,
#	Comment, FrontendVars

sub Section($$) { &_psmloader("Section", "sections", @_); }
sub Topic($$) { &_psmloader("Topic", "topics", @_); }
sub User($$) { &_psmloader("User", "userdata", @_); }
sub Story($$) { &_psmloader("Story", "stories", @_); }
sub Comment($$) { &_psmloader("Comment", "comments", @_); }
sub Poll($$) { &_psmloader("Poll", "polls", @_); }
sub FrontendVar($$;$$) { &_psmloader("FrontendVar", "vars", @_); }

sub GetSections($;%) { &_psmloader("GetSections", "sections", @_); }
sub GetTopics($;%) { &_psmloader("GetTopics", "topics", @_); }
sub GetUsers($;%) { &_psmloader("GetUsers", "userdata", @_); }
sub GetStories($;%) { &_psmloader("GetStories", "stories", @_); }
sub GetComments($;%) { &_psmloader("GetComments", "comments", @_); }
sub GetPolls($;%) { &_psmloader("GetPolls", "polls", @_); }
sub GetFrontendVars($;%) { &_psmloader("GetFrontendVars", "vars", @_); }

1;
