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

# $id should be either a discussion ID, a comment ID, or a journal ID
# $format should be "text" or "html"
# $type should be either "discussions", "comments", or "journals"
sub form_msgid($$$$) {
	my($self, $id, $format, $type) = @_;
	return "<$id\@$type.$format." . join(".", reverse split(/\./, $self->{root})) . ">";
}

# Parses a message ID, returning:
#	ID: A discussion, comment, or journal ID
#	format: "html" or "text"
#	type: "discussion, "comment", or "journal"
sub parse_msgid($$) {
	my($self, $msgid) = @_;
	$msgid =~ /^<(\d+)\@(discussion|comment|journal)s\.(html|text)\./;
	return ($1, $3, $2);
}

sub num2id($$$) {
	my($self, $group, $msgnum) = @_;
}

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
				my $result = $self->{slash_db}->sqlSelectAll("section", "sections", "id=$id");
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
			my $result = $self->{slash_db}->sqlSelectAll("nickname", "users", "uid=$uid");
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

	$self->{slash_db}->sqlUpdate("users_hits", {hits_paidfor => ++$user->{hits_paidfor}}, "uid=$self->{slash_user}->{uid}");
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

	my $sections = $self->{slash_db}->sqlSelectAllHashref(
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

		my $stories = $self->{slash_db}->sqlSelectAllHashref(
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
		my $jusers = $self->{slash_db}->{slash_db}->sqlSelectAllHashref('nickname', 'nickname, journals.uid AS uid, UNIX_TIMESTAMP(MIN(date)) AS jdate', 'journals, users', 'users.uid = journals.uid AND UNIX_TIMESTAMP(MIN(date)) > '.$time, 'GROUP BY uid')};
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

	my %ret;
	my($format, $grouptype, $id) = $self->parsegroup($group);
	if($grouptype eq "frontpage" or $grouptype eq "section") {
		my $sect = "";
		$sect = "_section" if $grouptype eq "section";

		my $where = "NOT ISNULL(nntp_${section}posttime)";
		$where .= " AND UNIX_TIMESTAMP(nntp_${section}posttime) > $time" if $time;
		$where .= " AND section=".$self->{slash_db}->sqlQuote($id) if $grouptype eq "section";

		my $stories = $self->{slash_db}->sqlSelectAllHashref(
			"nntp_${section}snum",
			"nntp_${section}snum, id",
			"stories",
			$where
		);

		foreach my $story (values %$stories) {
			$ret{$story->{"nntp_${section}snum"}} = $self->form_msgid($story->{id}, $format, "discussions");
		}
	} elsif($grouptype eq "story" or $grouptype eq "journal") {
		my $from = "comments";

		my $where = "NOT ISNULL(nntp_posttime)";
		$where .= " AND UNIX_TIMESTAMP(nntp_posttime) > $time" if $time;

		if($grouptype eq "story") {
			$from .= ", discussions";
			$where .= " AND comments.sid = discussions.sid";
			$where .= " AND discussions.id = $id";
		} else {
			$from .= ", journals";
			$where .= " AND journals.discussion = discussions.id";
			$where .= " AND journals.uid = $id";
		}

		my $comments = $self->{slash_db}->sqlSelectAllHashref(
			"cid",
			"cid, nntp_cnum",
			$from,
			$where
		);

		foreach my $comment (values %$comments) {
			$ret{$comment->{nntp_cnum}} = $self->form_msgid($comment->{cid}, $format, "comments");
		}

		if($grouptype eq "journal") {
			$where = "NOT ISNULL(nntp_posttime)";
			$where .= " AND UNIX_TIMESTAMP(nntp_posttime) > $time" if $time;
			$where .= " AND uid = $id";

			my $journals = $self->{slash_db}->sqlSelectAllHashref(
				"id",
				"id, nntp_cnum",
				"journals",
				$where
			);

			foreach my $journal (values %$journals) {
				$ret{$journal->{nntp_cnum}} = $self->form_msgid($journal->{id}, $format, "journals");
			}
		}
	}

	return %ret;
}

sub article($$$;@) {
	my($self, $type, $msgid, @headers) = @_;
	$self->auth_status_ok() or return fail("480 Authorization Required");

	my(%headers, $body);
	my %get_headers = map { $_ => 1 } @headers;
	my($id, $format, $type) = $self->parse_msgid($msgid);

	if($type eq "article" or $type eq "head") {
		$headers{path} = "$self->{slash_slashsite}!not-for-mail";
		$headers{message-id} = $msgid ;
		$headers{content-type} = "text/html; charset=us-ascii" if $format eq "html";
		# From
		# Subject
		# Newsgroups
		# Xref
		# Followup-To
		# Date
		# X-Slash-URL
		# X-Slash-Dept
		# X-Slash-User
		# X-Slash-Score
		# X-Slash-Mod-Reason
	}

	if($type eq "discussion") {
		
	} elsif($type eq "comment") {
	} elsif($type eq "journal") {
	}

	$self->consume_subscription() unless $type "head";
	if(@headers) {
		foreach my $header (keys %headers) {
			delete $headers{$header} unless $get_headers{$header};
		}
	}

	if($type eq "article") {
		return \%headers, $body;
	} elsif($type eq "head") {
		return \%headers;
	} elsif($type eq "body") {
		return $body;
	}
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

1;
