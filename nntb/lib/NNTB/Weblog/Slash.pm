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

	$self->{root} = $self->groupname("slash.$self->{slash_slashsite}");

	return $self;
}

sub root($) { return $self->{root}; }

sub auth_status_ok($) {
	my($self) = @_;

	my $auth_requirements = $self->{slash_db}->getVar("nntp_force_auth", "value");
	return 1 unless $auth_requirements;
	return 0 if $self->{slash_user}->{uid} == $self->{slash_constants}->{anonymous_coward_uid};
	return 1 unless $auth_requirements > 1 and $self->{slash_db}->getDescriptions("plugins")->{Journal});
	return 0 unless $user->{hits_bought} > $user->{hits_paidfor};
	return 1;
}

sub consume_subscription($) {
	my($self) = @_;

	$self->sqlUpdate("users_hits", {hits_paidfor => ++$user->{hits_paidfor}}, "uid=$self->{slash_user}->{uid}");
}

sub groups($;$) {
	my($self, $time) = @_;
	my %ret = ();

	$self->auth_status_ok() or return fail("480 Authorization Required");

	$time ||= 0;
	$time =~ tr/0-9//dc;

	# slash.slashsite.{text,html}
	#                            .stories
	#                                    .section
	#                                            .foo_bar_story
	#                            .journals.uid

	my $sitename = $self->{slash_db}->getVar("sitename", "value");
	$ret{"$self->{root}.text.stories"} = "$sitename front page stories in plain text";
	$ret{"$self->{root}.html.stories"} = "$sitename front page stories in HTML";

	my $sections = $self->sqlSelectAllHashref(
		'section',
		'section, title, ctime',
		'sections',
		"UNIX_TIMESTAMP(ctime) > $time"
	);

	foreach my $section (values %$sections) {
		$group = $self->groupname($section->{section});
		$ret{"$self->{root}.text.stories.$group"} = "$sitename $section->{title} stories in plain text";
		$ret{"$self->{root}.html.stories.$group"} = "$sitename $section->{title} stories in HTML";
	}

	if($self->{slash_db}->getDescriptions("plugins")->{Journal}) {
		my $jusers = $self->{slash_db}->sqlSelectAllHashref('nickname', 'nickname, UNIX_TIMESTAMP(MIN(date)) AS jdate', 'journals, users', 'users.uid = journals.uid', 'GROUP BY uid')};
		foreach my $juser(values %$jusers) {
			next if $juser->{jdate} <= $time;
			$ret{"$self->{root}.text.journals.$juser->{nickname}"} = "$sitename journals for $juser->{nickname}";
		}
	}
}

sub articles($$;$) {
	my($self, $group, $time) = @_;
	$self->auth_status_ok() or return fail("480 Authorization Required");

	
}

sub article($$$) {
	my($self, $type, $msgid) = @_;
	$self->auth_status_ok() or return fail("480 Authorization Required");

	$self->consume_subscription() unless $type "head";
}

sub auth($$$) {
	my($self, $user, $pass) = @_;
}

sub post($$$) {
	my($self, $head, $body) = @_;
	$self->auth_status_ok() or return fail("480 Authorization Required");

	$self->consume_subscription();
}

sub isgroup($$) {
	my($self, $group) = @_;
	$self->auth_status_ok() or return fail("480 Authorization Required");
}

sub groupstats($$) { 
	my($self, $group) = @_;
	$self->auth_status_ok() or return fail("480 Authorization Required");

	return ($first, $last, $num);
}

sub id2num($$$) {
	my($self, $group, $msgid) = @_;
}

sub num2id($$$) {
	my($self, $group, $msgnum) = @_;
}

1;
