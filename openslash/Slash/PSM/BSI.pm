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


#The optional hash for the GetFoos methods is a set of constraints which limit which Foos are gotten.
#Each GetFoos method will have a documented set of fields.
#e.g. GetUsers might have fields like seclevel and karma
#The keys of the hash are the names of the fields.
#The values are lists whose first element is an operator (=, <, >, >=, <=, !=, =~, !~) and whose second element is the RHS for the operator
#For the =~ and !~ operators, the array can have a third element.  This third element specifies flags to pass to the regex, e.g. 'imx'.  'g' will be ignored.
# == can be substitued for =.  The "string versions" are also allowed.  lt is considered equivalent to <.
#To be included in the result set, all criteria must be met.  That is, consider all criteria joined by "and".
#For the equivalent of an "or", just join multiple resultsets.

#Here are some examples:
#
#Get all users with seclevel equal to 0 and karma greater than or equal to 25.
#	@users = $slashsite->GetUsers(seclevel => ['=', 0], karma => ['>=', 25]);
#Get all users trying to impersonate Rob.
#	@users = ($slashsite->GetUsers(nick => ['=~', 'rob|malda|co?m{1,2}a?n?de?r|taco', 'i']);
#Get all stories in either the apache or BSD sections
#	@stories = ($slashsite->GetStories(section => ['eq', 'apache']), $slashsite->GetStories(section => ['eq', 'BSD']));

sub GetSections($;%) { print "GetSections\n"; return qw(1); }
sub GetTopics($;%) { print "GetTopics\n"; return qw(1); }
sub GetUsers($;%) { print "GetUsers\n"; return qw(1); }
sub GetStories($;%) { print "GetStories\n"; return qw(1); }
sub GetComments($;%) { print "GetComments\n"; return qw(1); }
sub GetFrontendVars($;%) { print "GetFrontendVars\n"; return qw(1); }

require Slash::PSM::BSI:Section;
require Slash::PSM::BSI::Topic;
require Slash::PSM::BSI::User;
require Slash::PSM::BSI::Story;
require Slash::PSM::BSI::Comment;

1;
