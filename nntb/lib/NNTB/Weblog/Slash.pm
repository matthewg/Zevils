package NNTB::Weblog::Slash;

# This module allows NNTB to be used with Slash - http://www.slashcode.com/

$VERSION = '0.01';
@ISA = qw(NNTB::Weblog);

use strict;
use warnings;
use vars qw($VERSION @ISA);
use Carp;
use NNTB::Common;

use Slash;

sub new($;@) {
	my $type = shift;
	my $self = $type->SUPER::new;
	my %params = @_;
	my @params = qw(datadir slashsites slashsite);

	(@self->{map { "slash_$_" } @params}) = delete $params{@params};
	croak "Unknown Slash weblog options: " . join(", ", keys %params) if keys %params;
	$self->{slash_datadir} ||= "/usr/local/slash";
	$self->{slash_slashsites} ||= "$self->{slash_datadir}/slash.sites";

	my %slashsites;
	open(CONFIG, $self->{slash_slashsites}) or croak "Couldn't open $self->{slash_slashsites}: $!";
	while(<CONFIG>) {
		chomp;
		my @siteparams = split(/:/);
		$slashsites{$siteparams[2]} = $siteparams[0];
	}
	close CONFIG;

	croak "You have multiple Slash sites available - you must specify one." if keys %slashsites > 1 and !$self->{slash_slashsite};
	$self->{slash_slashsite} ||= (keys %slashsites)[0];
	croak "Couldn't find Slash site $self->{slash_slashsite}!" if !$slashsites{$self->{slash_slashsite}};

	$self->{slash_virtuser} = $slashsites{$self->{slash_slashsite}};
	createEnvironment($self->{slash_virtuser});
	$self->{slash_constants} = getCurrentStatic();
	$self->{slash_db} = getCurrentDB();
	$self->{slash_user} = getCurrentUser();
	$self->{slash_nntp} = getObject("Slash::NNTP") or croak "Couldn't get Slash::NNTP - is the NNTP plugin installed for $self->{slash_slashsite}?";

	croak "You must run the nntp_init.pl script from the Slash NNTP plugin directory before you can use NNTB with Slash for $self->{slash_slashsite}!"
		unless $self->{slash_db}->getVar("nntp_initialized", "value");

	return $self;
}

sub groups($;$) {
	my($self, $time) = @_;
	my %ret = ();

	# slash.slashsite.{text,html}
	#                            .stories
	#                                    .section
	#                                            .foo_bar_story
	#                            .journals.uid

	my $root = $self->groupname("slash.$self->{slash_slashsite}");
	my $sitename = $self->{slash_db}->getVar("sitename", "value");
	$ret{"$root.text.stories"} = "$sitename front page stories in plain text";
	$ret{"$root.html.stories"} = "$sitename front page stories in HTML";

	my %sections = %{$self->{slash_db}->getDescriptions("sections-all")};

	while(my($section, $desc) = each(%sections)) {
		$section = $self->groupname($section);
		$ret{"$root.text.stories.$section"} = "$sitename $desc stories in plain text";
		$ret{"$root.html.stories.$section"} = "$sitename $desc stories in HTML";
	}

	if($self->{slash_db}->getDescriptions("plugins")->{Journal}) {
		my %jusers = @{$self->{slash_db}->sqlSelectAll('uid, MIN(date)', 'journals', '', 'GROUP BY uid')};
		# timeCalc($date, "%s", 0)
	}
}

sub articles($;$) {
	my($group, $time) = @_;
}

sub article($$) {
	my($type, $msgid) = @_;
}

sub auth($$) {
	my($user, $pass) = @_;
}

sub post($$) {
	my($head, $body) = @_;
}

sub isgroup($) {
	my($group) = @_;
}

sub groupstats($) { 
	my($group) = @_;
	return ($first, $last, $num);
}

sub id2num($$) {
	my($group, $msgid) = @_;
}

sub num2id($$) {
	my($group, $msgnum) = @_;
}

1;
