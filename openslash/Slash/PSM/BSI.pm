package Slash::PSM::BSI;
use strict;
use Carp qw(cluck croak carp confess);
use vars qw($VERSION @ISA %sections %topics %users %stories %comments %polls %vars);
@ISA = ('Slash::PSM::SlashSite');
$VERSION = '0.01';

%sections = 	(
			articles => MakeSection(name => 'articles'),
			features => MakeSection(name => 'features'),
			releases => MakeSection(name => 'releases'),
		);
%topics = 	(
			news => MakeTopic(name => 'news'),
			openslash => MakeTopic(name => 'openslash'),
			mp3tools => MakeTopic(name => 'mp3tools'),
			aimirc => MakeTopic(name => 'aimirc'),
		);
%users = 	(
			matthewg => MakeUser(name => 'matthewg', seclevel => 10000, realname => 'Matthew Sachs', email => 'matthewg@zevils.com', fakeemail => 'matthewg@zevils.com', url => 'http://www.zevils.com/', defscore => 2, pass => 'openslash'),
			somedude => MakeUser(name => 'somedude', realname => 'Some Dude', email => 'some@dude.org', fakeemail => 'some@dude.org.NOSPAM', url => '', pass => 'openslash'),
			jonkatz =>  MakeUser(name => 'jonkatz', seclevel => 5000, realname => 'Jon Katz', email => 'jon@katz.org', fakeemail => 'jon@NOSPAMkatz.org', pass => 'openslash', restrict => 'articles'),
		);
%stories = 	(
			openslash => MakeStory(title => 'OpenSlash Keeps Getting Better', dept => 'testing-1-2-3', topic => 'openslash', section => 'articles', author => 'matthewg', time => 945165180, introtext => 
				'<a href="http://www.zevils.com/linux/OpenSlash/">OpenSlash</a> just keeps getting better.  It has lots of nifty features.', bodytext =>
				'PSMs are nice.  Testing, testing, 1 2 3.'),
			aimirc => MakeStory(title => 'aimirc 0.51 released', dept => 'next-release-adds-multithreading', topic => 'aimirc', section => 'releases', author => 'matthewg', time => 945165180, introtext =>
				'<a href="http;//www.zevils.com/linux/aimirc/">aimirc</a> 0.51 has been released.'),
			hellmouth => MakeStory(title => 'The Hellmouth Has Halitosis', dept => 'dental-hygiene-is-important', topic => 'news', section => 'features', author => 'jonkatz', time => 945165180, introtext =>
				'The quick brown fox jumped over the lazy dogs.  Now is the time for all good men to come to the aid of their party.  This software is furnished under license and may only be used or copied in accordance with the terms of that license.'),
		);
%comments = 	();
%polls = 	();
%vars = 	();

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
	$self->{_capabilities}{polls} = 1;

	return $self;
}

sub Section($$) { print "Section $_[1]\n"; 1; }
sub Topic($$) { print "Topic $_[1]\n"; 1; }
sub User($$) { print "User $_[1]\n"; 1; }
sub Story($$) { print "Story $_[1]\n"; 1; }
sub Comment($$) { print "Comment $_[1]\n"; 1; }
sub Poll($$) { print "Poll $_[1]\n"; 1; }
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
sub GetPolls($;%) { print "GetPolls\n"; return qw(1); }
sub GetFrontendVars($;%) { print "GetFrontendVars\n"; return qw(1); }

#The MakeFoo methods return an empty object of the appropriate type.
#No changes should be made in the database (or whatever you're using for persistent storage)
#until the save method is called on the object.

sub MakeSection($;%) { print "MakeSection\n"; return qw(1); }
sub MakeTopic($;%) { print "MakeTopic\n"; return qw(1); }
sub MakeUser($;%) { print "MakeUser\n"; return qw(1); }
sub MakeStory($;%) { print "MakeStory\n"; return qw(1); }
sub MakeComment($;%) { print "MakeComment\n"; return qw(1); }
sub MakePoll($;%) { print "MakePoll\n"; return qw(1); }
sub MakeFrontendVar($;%) { print "MakeFrontendVar\n"; return qw(1); }

require Slash::PSM::BSI::Section;
require Slash::PSM::BSI::Topic;
require Slash::PSM::BSI::User;
require Slash::PSM::BSI::Story;
require Slash::PSM::BSI::Comment;
require Slash::PSM::BSI::Poll;

1;
