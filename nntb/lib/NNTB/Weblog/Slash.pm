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
use Slash::Constants qw(:strip);

sub new($;@) {
	my $type = shift;
	my $self = $type->SUPER::new;
	my %params = @_;
	my @params = qw(datadir slashsites slashsite);

	($self->{map { "slash_$_" } @params}) = delete $params{@params};
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

	$self->{root} ||= $self->groupname("slash." . lc($self->{slash_db}->getVar("sitename", "value")));

	return $self;
}

sub root($) { return shift->{root}; }

# $id should be either a comment ID, a story ID, or a journal ID
# $format should be "text" or "html"
# $type should be either "comment", "story", "journal"
sub form_msgid($$$$) {
	my($self, $id, $format, $type) = @_;
	return "<$id\@$type.$format." . join(".", reverse split(/\./, $self->{root})) . ">";
}

# Parses a message ID, returning:
#	ID: A comment, story, or journal ID
#	format: "html" or "text"
#	type: "comment", "story", or "journal"
sub parse_msgid($$) {
	my($self, $msgid) = @_;
	$msgid =~ /^<(.+?)\@(comment|story|journal)\.(html|text)\./ or return ();
	return ($1, $3, $2);
}

sub num2id($$$) {
	my($self, $group, $msgnum) = @_;

	my($id, $format, $type) = $self->parsegroup($group);
	my($idtype, $idid);

	if($type eq "frontpage") {
		$idtype = "story";
		$idid = $self->{slash_db}->sqlSelect("sid", "stories",
			"nntp_snum=$msgnum") or return undef;
	} elsif($type eq "section") {
		$idtype = "story";
		$idid = $self->{slash_db}->sqlSelect("sid", "stories",
			"section=".$self->{slash_db}->sqlQuote($id).
			" AND nntp_section_snum=$msgnum") or return undef;
	} elsif($type eq "story") {
		$idtype = "comment";
		$idid = $self->{slash_db}->sqlSelect("cid", "comments",
			"sid=".$self->{slash_db}->sqlQuote($id).
			" AND nntp_cnum=$msgnum") or return undef;
	} elsif($type eq "journal") {
		$idtype = "journal";
		$idid = $self->{slash_db}->sqlSelect("id", "journals",
			"uid=".$self->{slash_db}->sqlQuote(
				$self->{slash_db}->getUserUID($id)
			).
			" AND nntp_cnum=$msgnum");
		if(!$idid) {
			$idtype = "comment";
			$idid = $self->{slash_db}->sqlSelect("cid",
				"journals, comments",
				"journals.uid=".$self->{slash_db}->sqlQuote(
					$self->{slash_db}->getUserUID($id)
				).
				" AND journals.discussion = comments.sid".
				" AND comments.nntp_cnum = $id");
			return undef unless $idid;
		}
	}

	return $self->form_msgid($idid, $format, $idtype);
}

# Parses a group, returning:
#	ID: For "section", section name.  For "story", story ID.  For "journal", nick.
#	"html" or "text"
#	type: "frontpage", "section", "story", or "journal"
# In scalar context, returns only the type.
sub parsegroup($$) {#
	my($self, $group) = @_;

	substr($group, 0, length($self->{root})) = ""; # Remove root
	my(@groupparts) = split(/\./, $group);
	my @ret;

	$ret[1] = $groupparts[0]; # text/html
	if(@groupparts == 2) { #{text,html}.stories
		return "frontpage" unless wantarray;
		$ret[2] = "frontpage";
	} elsif(lc($groupparts[1]) eq "stories") {
		if(@groupparts == 3) { # {text,html}.stories.section
			return "section" unless wantarray;
			$ret[2] = "section";

			$groupparts[2] =~ /^(.+)_(\d+)$/;
			my($section, $id) = ($1, $2);

			# Section name possibly mangled
			($section) = grep { $_->{id} == $id } $self->{slash_db}->getSections() if $section =~ /_/;

			$ret[0] = $section;
		} else { # {text,html}.stories.section.story_id
			return "story" unless wantarray;
			$ret[2] = "story";
			$ret[0] = $groupparts[3];
		}
	} elsif(lc($groupparts[1]) eq "journals") {
		return "journal" unless wantarray;
		$ret[2] = "journal";

		$groupparts[2] =~ /^(.+)_(\d+)$/;
		my($nick, $uid) = ($1, $2);

		# Nickname possibly mangled
		$nick = $self->{slash_db}->getUser($uid, 'nickname') if $nick =~ /_/;

		$ret[0] = $nick;
	}

	return @ret;
}

sub auth_status_ok($) {
	my($self) = @_;

	my $auth_requirements = $self->{slash_db}->getVar("nntp_force_auth", "value");
	return 1 unless $auth_requirements;
	return 0 if $self->{slash_user}->{uid} == $self->{slash_constants}->{anonymous_coward_uid};
	return 1 unless $auth_requirements > 1 and $self->{slash_db}->getDescriptions("plugins")->{Journal};
	return 0 unless $self->{slash_user}->{hits_bought} > $self->{slash_user}->{hits_paidfor};
	return 1;
}

sub consume_subscription($) {
	my($self) = @_;

	$self->{slash_db}->setUser($self->{slash_user}->{uid}, {hits_paidfor => $self->{slash_db}->getUser($self->{slash_user}->{uid}, 'hist_paidfor') + 1});
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
	my $textroot = "$self->{root}.text";
	my $htmlroot = "$self->{root}.html";
	$ret{"$textroot.stories"} = "$sitename front page stories in plain text";
	$ret{"$htmlroot.stories"} = "$sitename front page stories in HTML";

	my $sections = $self->{slash_db}->getSections();

	foreach my $section (@$sections) {
		next unless timeCalc($section->{ctime}, "%s") > $time;

		my $group = $self->groupname("$section->{section}_$section->{id}");
		$ret{"$textroot.stories.$group"} = "$sitename $section->{title} stories in plain text";
		$ret{"$htmlroot.stories.$group"} = "$sitename $section->{title} stories in HTML";
	}

	# Not using cache == bad, true.
	# But in order to use the cache, I'd have to call getStories().
	# Do you *really* want to burden the cache with SELECT * FROM stories?
	# Keep in mind that since we fork for each client, the cache wouldn't
	#  be shared between clients.

	my $stories = $self->{slash_db}->sqlSelectAllHashref(
		'sid',
		'sid, tid, section, title',
		'stories',
		"UNIX_TIMESTAMP(nntp_section_posttime) > $time"
	);


	foreach my $story (values %$stories) {
		my $sectgroup = $self->groupname("$story->{section}_".$self->{slash_db}->getSection($story->{section}, 'id'));
		my $topic = $self->{slash_db}->getTopic($story->{tid}, 'name');

		$ret{"$textroot.stories.$sectgroup.$story->{sid}"} = "$story->{title} ($topic)";
		$ret{"$htmlroot.stories.$sectgroup.$story->{sid}"} = "$story->{title} ($topic)";
	}

	if($self->{slash_db}->getDescriptions("plugins")->{Journal}) {
		my $jusers = $self->{slash_db}->{slash_db}->sqlSelectAllHashref('nickname', 'nickname, journals.uid AS uid, UNIX_TIMESTAMP(MIN(date)) AS jdate', 'journals, users', 'users.uid = journals.uid AND UNIX_TIMESTAMP(MIN(date)) > '.$time, 'GROUP BY uid');
		foreach my $juser(values %$jusers) {
			# No getJournals...
			my $journalgroup = $self->groupname("journals.$juser->{nickname}.$juser->{uid}");
			$ret{"$textroot.$journalgroup"} = "$sitename journals for $juser->{nickname} (UID $juser->{uid})";
			$ret{"$htmlroot.$journalgroup"} = "$sitename journals for $juser->{nickname} ($juser->{uid})";
		}
	}
}

sub articles($$;$) {
	my($self, $group, $time) = @_;
	$self->auth_status_ok() or return fail("480 Authorization Required");

	my %ret;
	my($id, $format, $grouptype) = $self->parsegroup($group);
	if($grouptype eq "frontpage" or $grouptype eq "section") {
		my $sect = "";
		$sect = "_section" if $grouptype eq "section";

		my $where = "NOT ISNULL(nntp_${sect}posttime)";
		$where .= " AND UNIX_TIMESTAMP(nntp_${sect}posttime) > $time" if $time;
		$where .= " AND section=".$self->{slash_db}->sqlQuote($id) if $grouptype eq "section";

		my $stories = $self->{slash_db}->sqlSelectAllHashref(
			"nntp_${sect}snum",
			"nntp_${sect}snum, id",
			"stories",
			$where
		);

		foreach my $story (values %$stories) {
			$ret{$story->{"nntp_${sect}snum"}} = $self->form_msgid($story->{id}, $format, "story");
		}
	} elsif($grouptype eq "story" or $grouptype eq "journal") {
		my $from = "comments";

		my $where = "NOT ISNULL(nntp_posttime)";
		$where .= " AND UNIX_TIMESTAMP(nntp_posttime) > $time" if $time;

		if($grouptype eq "story") {
			$from .= ", stories";
			$where .= " AND comments.sid = stories.sid";
			$where .= " AND stories.sid = $id";
		} else {
			$from .= ", journals";
			$where .= " AND journals.discussion = comments.sid";
			$where .= " AND journals.uid = $id";
		}

		my $comments = $self->{slash_db}->sqlSelectAllHashref(
			"cid",
			"cid, nntp_cnum",
			$from,
			$where
		);

		foreach my $comment (values %$comments) {
			$ret{$comment->{nntp_cnum}} = $self->form_msgid($comment->{cid}, $format, "comment");
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
				$ret{$journal->{nntp_cnum}} = $self->form_msgid($journal->{id}, $format, "journal");
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
	my($id, $format, $msgtype) = $self->parse_msgid($msgid) or return undef;

	if($type eq "article" or $type eq "head") {
		$headers{path} = "$self->{slash_slashsite}!not-for-mail";
		$headers{"message-id"} = $msgid;
		$headers{"content-type"} = "text/html; charset=us-ascii" if $format eq "html";

		delete $get_headers{qw(path message-id content-type)};
	}

	my($uid, $date);
	$headers{"content-type"} = "text/html" if $format eq "html";

	if($msgtype eq "story") {
		my $story = $self->{slash_db}->getStory($id) or return undef;
		$body = "$story->{introtext}<p>$story->{bodytext}";
		$uid = $story->{uid};
		$date = $story->{time};

		if($type eq "head" or $type eq "article") {
			my $sectiongroup = $self->groupname("$self->{root}.$format.stories.$story->{section}_".$self->{slash_db}->getSection($story->{section}, 'id'));
			my $fpgroup = "";
			$fpgroup = $self->groupname("$self->{root}.$format.stories") if $story->{nntp_posttime};

			$headers{subject} = $story->{title};
			$headers{newsgroups} = $sectiongroup;
			$headers{newsgroups} .= ",$fpgroup" if $fpgroup;
			$headers{xref} = $self->{slash_db}->getVar("nntp_host") . " $sectiongroup:$story->{nntp_section_snum}";
			$headers{xref} .= " $fpgroup:$story->{nntp_snum}" if $fpgroup;
			$headers{"followup-to"} = "$sectiongroup.$story->{sid}";
			$headers{"x-slash-url"} = "http:" . $self->{slash_db}->getVar('rootdir', 'value') . "/article.pl?sid=$story->{sid}";
			$headers{"x-slash-topic"} = $self->{slash_db}->getTopic($story->{tid}, 'name');
			$headers{"x-slash-dept"} = $story->{dept};
			$headers{"x-slash-can-post"} = $story->{discussion} ? 1 : 0;
		}
	} elsif($msgtype eq "comment") {
		my $comment = $self->{slash_db}->getComment($id) or return undef;
		$body = $comment->{comment} . "<p>-- <br>$comment->{signature}";
		$uid = $comment->{uid};
		$date = $comment->{date};

		if($type eq "head" or $type eq "article") {
			my($section, $sid) = $self->{slash_db}->getDiscussion($comment->{sid}, ['section', 'sid']);
			my $secid = $self->{slash_db}->getSection($section, 'id');
			my $group = $self->groupname("$self->{root}.$format.stories.${section}_$secid.$sid");

			$headers{subject} = $comment->{subject};
			$headers{newsgroups} = $group;
			$headers{xref} = $self->{slash_db}->getVar("nntp_host") . " $group:$comment->{nntp_cnum}";
			$headers{"x-slash-url"} = "http:" . $self->{slash_db}->getVar('rootdir', 'value') . "/comments.pl?sid=$comment->{sid}&cid=$comment->{cid}";
			$headers{"x-slash-score"} = $comment->{points};
			$headers{"x-slash-mod-reason"} = (split(/|/, $self->{slash_db}->getVar("reasons", "value")))[$comment->{reason}];

			my @references = ();
			while($comment->{pid}) {
				$comment = $self->{slash_db}->getComment($comment->{pid});
				unshift @references, $self->form_msgid($comment->{cid}, $format, "comment");
			}

			# If it's a journal, the top-level post is the journal article
			my $journal = $self->{slash_db}->sqlSelect("discussion", "journals", "discussion = $comment->{sid}");
			unshift @references, $self->form_msgid($journal, $format, "journal") if $journal;

			$headers{references} = join(" ", @references);
		}
	} elsif($msgtype eq "journal") {
		my $journal_obj = getObject("Slash::Journal") or return fail("500 Couldn't get Slash::Journal");
		my $journal = $journal_obj->get($id) or return undef;
		$body = $journal->{article};
		$uid = $journal->{uid};
		$date = $journal->{date};

		if($type eq "head" or $type eq "article") {
			my $group = $self->groupname("$self->{root}.$format.journals.".$self->{slash_db}->getUser($journal->{uid}, 'nickname')."_$journal->{uid}");

			$headers{subject} = $journal->{description};
			$headers{newsgroups} = $group;
			$headers{xref} = $self->{slash_db}->getVar("nntp_host") . " $group:$journal->{nntp_cnum}";
			$headers{"x-slash-url"} = "http:" . $self->{slash_db}->getVar('rootdir', 'value') . "/journal.pl?op=display&uid=$journal->{uid}&id=$journal->{id}";
			$headers{"x-slash-topic"} = $self->{slash_db}->getTopic($journal->{tid}, 'name');
			$headers{"x-slash-can-post"} = $journal->{discussion} ? 1 : 0;
		}
	}

	if($type eq "head" or $type eq "article") {
		if(!@headers or $get_headers{from}) {
			my @uinfo = $self->{slash_db}->getUser($uid, ['realname', 'fakeemail']);
			$headers{from} = "$uinfo[0] <$uinfo[0]>";
		}
		$headers{"x-slash-user"} = $self->{slash_db}->getUser($uid, 'nickname') . " ($uid)" if !@headers or $get_headers{"x-slash-user"};

		$headers{date} = timeCalc($date, "%d %b %Y %H:%M:%s $self->{slash_user}->{off_set}");
		my @lines = split(/\n/, $body);
		$headers{lines} = scalar @lines;
		$headers{bytes} = length($body);
	}

	$self->consume_subscription() unless $type eq "head";

	$body = $self->html2txt($body) if $format eq "text";
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

	my($uid) = $self->{slash_db}->getUserAuthenticate($self->{slash_db}->getUserUID($user), $pass);
	return 0 unless $uid;
	$self->{slash_user} = $self->{slash_db}->getUser($uid);
	return 1;
}

sub post($$$) {
	my($self, $head, $body) = @_;
	$self->auth_status_ok() or return fail("480 Authorization Required");

	my $journal_obj;

	my $uid = $self->{slash_user}->{uid};
	$uid = $self->{slash_constants}->{anonymous_coward_uid} if
		$head->{"x-slash-anon"} or
		$head->{"x-slash-anonymous"} or
		$head->{"x-slash-post-anon"} or
		$head->{"x-slash-post-anonymous"} or
		$head->{"x-slash-post-anonymously"};

	my $score = 1;
	$score = 0 if
		$uid == $self->{slash_constants}->{anonymous_coward_uid} or
		$self->{slash_db}->getUser($uid, 'karma') < $self->{slash_constants}->{badkarma};
	$score = 2 if
		$self->{slash_db}->getUser($uid, 'karma') > $self->{slash_constants}->{goodkarma}
			and not (
				$head->{"x-slash-no-bonus"} or
				$head->{"x-slash-no-score-bonus"} or
				$head->{"x-slash-no-karma-bonus"}
			);

	my($type, $id);
	($id, undef, $type) = $self->parse_group($head->{newsgroups});
	my $sid;

	my $posttype = "comment";
	my $cnum;

	if($type eq "journal") {
		if(!$head->{references}) {
			return fail("500 Can't make top-level post in someone else's journal") unless $id == $self->{slash_user}->{uid};
			$posttype = "journal";
		} else {
			my $pid;
			($pid, undef, $type) = $self->parse_msgid($head->{references});
			if($type eq "journal") {
				$journal_obj = getObject("Slash::Journal") or return fail("500 Couldn't get Slash::Journal");
				my $journal = $journal_obj->get($pid) or return fail("500 Couldn't find journal");
				$sid = $self->{slash_db}->getDiscussion($journal->{discussion}, 'sid');
			} else { # comment
				$sid = $self->{slash_db}->getComment($pid, 'sid');
			}
		}
		$cnum = $self->{slash_nntp}->next_num("journal_cnum", $id);
	} else { # comment
		$sid = $id;
		$cnum = $self->{slash_nntp}->next_num("cnum", $sid);
	}

	my $subject = $head->{subject} || "";

	my $mode = "";
	if($head->{"content-type"} =~ m!\btext/html\b!) {
		$mode = HTML;
	} else {
		$mode = PLAINTEXT;
	}
	$body = stripByMode($body, $mode, 0);

	unless($posttype eq "journal") {
		my $pid;
		($pid, undef, $type) = $self->parse_msgid($head->{references});
		$pid = 0 unless $type eq "comment";

		# Yay for having to C+P code from sub createAccessLog!
		my $ipid = md5_hex($self->client_ip);
		my $subnetid = $self->client_ip;
		$subnetid =~ s/^(\d+\.\d+\.\d+)\.\d+$/$1.0/;
		$subnetid = md5_hex($subnetid);

		my $comment = {
			sid => $sid,
			pid => $pid,
			date => 'NOW()',
			ipid => $ipid,
			subnetid => $subnetid,
			subject => $subject,
			uid => $uid,
			points => $score,
			nntp_cnum => $cnum,
			nntp_posttime => 'NOW()',
			comment => $body,
		};
		$self->{slash_db}->createComment($comment) or return fail("500 Couldn't post comment");
	} else {
		$ENV{SLASH_USER} = $self->{slash_user}->{uid};
		my $topic = $head->{"x-slash-topic"} || "journal";
		my($tid) = grep { $_->{name} eq $topic } $self->{slash_db}->getTopics();
		$tid ||= grep { $_->{name} eq "journal" } $self->{slash_db}->getTopics();

		my $jid = $journal_obj->create(
			$subject,
			$body,
			2, # posttype?
			$tid
		) or return fail("500 Couldn't post journal");

		my $journal_comments = 0;
		if($self->{slash_constants}->{journal_comments}) {
			if((
				$self->{slash_user}->{journal_discuss}
					or $head->{"x-slash-journal-discuss"}
			) and not (
				exists($head->{"x-slash-journal-discuss"}) and
					not $head->{"x-slash-journal-discuss"}
			)) {
				$journal_comments = 1;
			}
		}
			

		if($journal_comments) {
			my $did = $self->{slash_db}->createDiscussion({
				title => $subject,
				topic => $tid,
				url => $self->{slash_db}->getVar('rootdir', 'value') . "/~" . fixparam($self->{slash_user}->{nickname}) . "/journal/$jid",
			});
			$journal_obj->set($jid, { discussion => $did });
		}
		$journal_obj->set($jid, { nntp_cnum => $cnum });
	}

	$self->consume_subscription();
}

sub is_group($$) {
	my($self, $group) = @_;
	$self->auth_status_ok() or return fail("480 Authorization Required");

	$group = lc($group);
	my $root = substr($group, 0, length($self->{root}), "");
	return 0 unless $root eq lc($self->{root});

	return 0 unless $group;
	my @groupparts = split(/\./, $group);

	my $format = shift @groupparts or return 0;
	return 0 unless $format eq "text" or $format eq "html";

	my $type = shift @groupparts or return 0;

	if($type eq "stories") {
		my $section = shift @groupparts or return 1;
		$section =~ s/_(\d+)$// or return 0;
		my $sectid = $1;
		return 0 unless $section;

		my($section_data) = grep { $_->{id} == $sectid } $self->{slash_db}->getSections();
		return 0 unless $section_data;
		return 0 unless lc($self->groupname($section_data->{section})) eq $section;

		my $sid = shift @groupparts or return 1;
		return 0 unless my $story = $self->{slash_db}->getStory($sid);
		return 0 unless $story->{section} eq $section;
		return 1;
	} elsif($type eq "journals") {
		my $nick = shift @groupparts or return 0;
		$nick =~ s/_(\d+)$// or return 0;
		my $uid = $1;
		return 0 unless $nick;

		return 0 unless lc($self->groupname($self->{slash_db}->getUser($uid, 'nickname'))) eq $nick;
		return 1;
	} else {
		return 0;
	}
}

sub can_post($$) {
	my($self, $group) = @_;
	$self->auth_status_ok() or return fail("480 Authorization Required");

	return 0 if $self->{slash_user}->{uid} == 
			$self->{slash_constants}->{anonymous_coward_uid} and
				!$self->{slash_db}->getVar("allow_anonymous", "value");

	my($id, $format, $type) = $self->parsegroup($group);

	return 0 if $type eq "frontpage" or $type eq "section";
	return 1 if $type eq "journal";
	my $story = $self->{slash_db}->getStory($id);
	return 0 unless $story->{discussion};
	return 1;
}

sub groupstats($$) { 
	my($self, $group) = @_;
	$self->auth_status_ok() or return fail("480 Authorization Required");

	my($first, $last, $num) = (undef, undef, undef);
	my($id, $format, $type) = $self->parsegroup($group);

	if($type eq "frontpage") {
		($first, $last, $num) = $self->{slash_db}->sqlSelect(
						"MIN(nntp_snum), MAX(nntp_snum), COUNT(nntp_snum)",
						"stories");
	} elsif($type eq "section") {
		($first, $last, $num) = $self->{slash_db}->sqlSelect(
						"MIN(nntp_section_snum), MAX(nntp_section_snum), COUNT(nntp_section_num)",
						"stories",
						"section=".$self->{slash_db}->sqlQuote($id));
	} elsif($type eq "story") {
		($first, $last, $num) = $self->{slash_db}->sqlSelect(
						"MIN(nntp_cnum), MAX(nntp_cnum), COUNT(nntp_cnum)",
						"comments",
						"sid=".$self->{slash_db}->getStory($id, 'discussion'));
	} elsif($type eq "journal") {
		my $journals = $self->{slash_db}->sqlSelectAllHashref(
						"discussion",
						"nntp_cnum, discussion",
						"journals",
						"NOT ISNULL(nntp_cnum) AND uid=".$self->{slash_db}->sqlQuote($self->{slash_db}->getUserUID($id)));
		foreach my $journal (values %$journals) {
			$first = $journal->{nntp_cnum} if !defined($first) or $journal->{nntp_cnum} < $first;
			$last = $journal->{nntp_cnum} if !defined($last) or $journal->{nntp_cnum} > $last;
			$num++;
			if($journal->{discussion}) {
				my($dfirst, $dlast, $dnum) = $self->{slash_db}->sqlSelect(
						"MIN(nntp_cnum), MAX(nntp_cnum), COUNT(nntp_cnum)",
						"comments",

						"comments.sid=".$self->{slash_db}->getStory($id, 'discussion'));
				$first = $dfirst if !defined($first) or $dfirst < $first;
				$last = $dlast if !defined($last) or $dlast > $last;
				$num += $dnum;
			}
		}
	}

	return ($first, $last, $num);
}

1;
