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

	$self->{root} ||= $self->groupname("slash." . lc($self->{slash_db}->getVar("sitename", "value"));

	return $self;
}

sub root($) { return $self->{root}; }

# Parses a group, returning:
#	"html" or "text"
#	type: "frontpage", "section", "story", or "journal"
#	ID: For "section", section name.  For "story", story ID.  For "journal", nick.
# In scalar context, returns only the type.
sub parsegroup($$) {#
	my($self, $group) = @_;

	substr($group, 0, length($self->{root})) = ""; # Remove root
	my(@groupparts) = split(/\./, $group);
	my @ret;

	push @ret, $groupparts[0]; # text/html
	if(@groupparts == 2) { {text,html}.stories
		return "frontpage" unless wantarray;
		push @ret, "frontpage";
	} elsif(lc($groupparts[1]) eq "stories") {
		if(@groupparts == 3) { # {text,html}.stories.section
			return "section" unless wantarray;
			push @ret, "section";

			$groupparts[2] =~ /^(.+)_(\d+)$/;
			my($section, $id) = ($1, $2);

			if($section =~ /_/) { # Section name possibly mangled
				my $result = $self->sqlSelectAll("section", "sections", "id=$id");
				$section = $result->[0]->[0];
			}
			push @ret, $section;
		} else { # {text,html}.stories.section.story_id
			return "story" unless wantarray;
			push @ret, "story";
			push @ret, $groupparts[3];
		}
	} elsif(lc($groupparts[1]) eq "journals") {
		return "journal" unless wantarray;
		push @ret, "journal";

		$groupparts[2] =~ /^(.+)_(\d+)$/;
		my($nick, $uid) = ($1, $2);

		if($nick =~ /_/) { # Nickname possibly mangled
			my $result = $self->sqlSelectAll("nickname", "users", "uid=$uid");
			$nick = $result->[0]->[0];
		}
		push @ret, $nick;
	}

	return @ret;
}

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
	#                                    .section_sectid
	#                                            .123
	#                            .journals.nick_uid

	my $sitename = $self->{slash_db}->getVar("sitename", "value");
	$ret{"$self->{root}.text.stories"} = "$sitename front page stories in plain text";
	$ret{"$self->{root}.html.stories"} = "$sitename front page stories in HTML";

	my $sections = $self->sqlSelectAllHashref(
		'section',
		'id, section, title, ctime',
		'sections',
		"UNIX_TIMESTAMP(ctime) > $time"
	);

	foreach my $section (values %$sections) {
		$group = $self->groupname("$section->{section}_$section->{id}");
		my $textgroup = "$self->{root}.text.stories.$group";
		my $htmlgroup = "$self->{root}.html.stories.$group";
		$ret{$textgroup} = "$sitename $section->{title} stories in plain text";
		$ret{$htmlgroup} = "$sitename $section->{title} stories in HTML";

		my $stories = $self->sqlSelectAllHashref(
			'id',
			'id, title, topics.name AS topic',
			'discussions, topics',
			'discussions.id = topics.tid AND UNIX_TIMESTAMP(nntp_section_posttime) > $time AND section=$section->{id}"
		);

		foreach my $story (values %$stories) {
			$ret{"$textgroup.$story->{id}"} = "$story->{title} ($story->{topic})";
			$ret{"$htmlgroup.$story->{id}"} = "$story->{title} ($story->{topic})";
		}
	}

	if($self->{slash_db}->getDescriptions("plugins")->{Journal}) {
		my $jusers = $self->{slash_db}->sqlSelectAllHashref('nickname', 'nickname, journals.uid AS uid, UNIX_TIMESTAMP(MIN(date)) AS jdate', 'journals, users', 'users.uid = journals.uid AND UNIX_TIMESTAMP(MIN(date)) > '.$time, 'GROUP BY uid')};
		foreach my $juser(values %$jusers) {
			my $journalgroup = $self->groupname("journals.$juser->{nickname}.$juser->{uid}");
			$ret{"$self->{root}.text.$journalgroup"} = "$sitename journals for $juser->{nickname} (UID $juser->{uid})";
			$ret{"$self->{root}.html.$journalgroup"} = "$sitename journals for $juser->{nickname} ($juser->{uid})";
		}
	}
}

sub articles($$;$) {
	my($self, $group, $time) = @_;
	$self->auth_status_ok() or return fail("480 Authorization Required");

	my($format, $grouptype, $id) = $self->parsegroup($group);
	if($grouptype eq "frontpage") {
		my $stories = $self->sqlSelectAllHashref(
			"nntp_snum
		);
	} elsif($grouptype eq "section") {
	} elsif($grouptype eq "story") {
	} elsif($grouptype eq "journal") {
	}
}

sub article($$$;@) {
	my($self, $type, $msgid, @headers) = @_;
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

sub form_msgid_story($$$) {
	my($self, $format, $discussion_id) = @_;
	return "<$discussion_id\@$format." . join(".", reverse split(/\./, $self->{root})) . ">";
}

sub form_msgid_comment

sub id2num($$$) {
	my($self, $group, $msgid) = @_;
}

sub num2id($$$) {
	my($self, $group, $msgnum) = @_;
}

1;
