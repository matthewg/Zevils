package NNTB::Weblog::Slash;

# This module allows NNTB to be used with Slash - http://www.slashcode.com/

use vars qw($VERSION @ISA);
$VERSION = '0.01';
@ISA = qw(NNTB::Weblog);

use strict;
use warnings;
use Carp;
use NNTB::Common;
use NNTB::Weblog;

use Slash;
use Slash::Constants qw(:strip);
use Slash::Utility;

sub new($;@) {
	my $type = shift;
	my $self = $type->SUPER::new(@_);

	my %params = @_;
	my @params = qw(datadir slashsites slashsite);

	$self->log("Creating new NNTB::Weblog::Slash...", LOG_NOTICE);

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

	$self->{root} ||= $self->groupname("slash", lc($self->{slash_db}->getVar("sitename", "value")));

	$self->log("Created NNTB::Weblog::Slash: root=$self->{root}", LOG_NOTICE);

	return $self;
}

sub root($) { return shift->{root}; }

# $id should be either a comment ID, a story ID, or a journal ID
# $format should be "text" or "html"
# $type should be either "comment", "story", "journal"
sub form_msgid($$$$) {
	my($self, $id, $format, $type) = @_;
	return "<$id\@$type.$format.$self->{root}>";
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
			"sid=".$self->{slash_db}->getStory($id, 'discussion').
			" AND nntp_cnum=$msgnum") or return undef;
	} elsif($type eq "journal" or $type eq "journals") {
		$idtype = "journal";

		if($type eq "journal") {
			$idid = $self->{slash_db}->sqlSelect("id", "journals",
				"uid=".$self->{slash_db}->sqlQuote(
					$self->{slash_db}->getUserUID($id)
				).
				" AND nntp_cnum=$msgnum");
		} else {
			my $journal_obj = getObject("Slash::Journal");
			return undef unless $journal_obj->get($msgnum);
			$idid = $msgnum;
		}

		if(!$idid) {
			$idtype = "comment";
			$idid = $self->{slash_db}->sqlSelect("cid",
				"journals, comments",
				"journals.uid=".$self->{slash_db}->sqlQuote(
					$self->{slash_db}->getUserUID($id)
				).
				" AND journals.discussion = comments.sid".
				" AND comments.nntp_cnum = $msgnum");
			return undef unless $idid;
		}
	}

	my $msgid = $self->form_msgid($idid, $format, $idtype);
	$self->log("num2id: $group.$msgnum -> $msgid", LOG_NOTICE);
	return $msgid;
}

# Parses a group, returning:
#	ID: For "section", section name.  For "story", story ID.  For "journal", nick.
#	"html" or "text"
#	type: "frontpage", "section", "story", "journal", or "journals"
# In scalar context, returns only the type.
sub parsegroup($$) {#
	my($self, $group) = @_;

	substr($group, 0, length($self->{root}) + 1) = ""; # Remove root (and trailing .)
	my(@groupparts) = split(/\./, $group);
	$self->log("groupparts: ", join(", ", map { "<$_>" } @groupparts), LOG_DEBUG);
	my @ret;

	$ret[1] = $groupparts[0]; # text/html
	if(@groupparts == 2 and lc($groupparts[1]) eq "stories") { #{text,html}.stories
		return "frontpage" unless wantarray;
		$ret[2] = "frontpage";
	} elsif(lc($groupparts[1]) eq "stories") {
		if(@groupparts == 3) { # {text,html}.stories.section
			return "section" unless wantarray;
			$ret[2] = "section";

			$groupparts[2] =~ /^(.+)_(\d+)$/;
			my($section, $id) = ($1, $2);

			# Section name possibly mangled
			($section) = grep { $_->{id} == $id } values %{$self->{slash_db}->getSections()} if $section =~ /_/;

			$ret[0] = $section;
		} else { # {text,html}.stories.section.story_id
			return "story" unless wantarray;
			$ret[2] = "story";
			$ret[0] = $groupparts[3];
		}
	} elsif(lc($groupparts[1]) eq "journals") {
		return ($groupparts[2] ? "journal" : "journals") unless wantarray;
		$ret[2] = $groupparts[2] ? "journal" : "journals";
		return @ret unless $groupparts[2];

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
	return 1 unless $auth_requirements > 1 and $self->{slash_db}->getDescriptions("plugins")->{Subscribe};
	return 0 unless $self->{slash_user}->{hits_bought} > $self->{slash_user}->{hits_paidfor};
	return 1;
}

sub consume_subscription($) {
	my($self) = @_;

	return unless $self->{slash_db}->getDescriptions("plugins")->{Subscribe} and $self->{slash_db}->getVar("nntp_force_auth", "value") > 1;
	$self->do_log("Yum yum, subscriptions are delicious!", LOG_NOTICE);
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
	#                            .journals
	#                                     .nick_uid

	my $sitename = $self->{slash_db}->getVar("sitename", "value");
	my $textroot = "$self->{root}.text";
	my $htmlroot = "$self->{root}.html";
	$ret{"$textroot.stories"} = "$sitename front page stories in plain text";
	$ret{"$htmlroot.stories"} = "$sitename front page stories in HTML";

	my $sections = $self->{slash_db}->getSections();

	foreach my $section (values %$sections) {
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
		"NOT ISNULL(discussion) AND UNIX_TIMESTAMP(nntp_section_posttime) > $time"
	);


	foreach my $story (values %$stories) {
		my $sectgroup = $self->groupname("$story->{section}_".$self->{slash_db}->getSection($story->{section}, 'id'));
		my $topic = $self->{slash_db}->getTopic($story->{tid}, 'name');

		$ret{"$textroot.stories.$sectgroup.$story->{sid}"} = "$story->{title} ($topic)";
		$ret{"$htmlroot.stories.$sectgroup.$story->{sid}"} = "$story->{title} ($topic)";
	}

	if($self->{slash_db}->getDescriptions("plugins")->{Journal}) {
		$ret{"$textroot.journals"} = "All $sitename journals";
		$ret{"$htmlroot.journals"} = "All $sitename journals";

		my $jusers = $self->{slash_db}->sqlSelectAllHashref('nickname', 'nickname, journals.uid AS uid, UNIX_TIMESTAMP(MIN(date)) AS jdate', 'journals, users', 'users.uid = journals.uid GROUP BY nickname, uid HAVING jdate > '.$time);
		foreach my $juser(values %$jusers) {
			# No getJournals...
			my $journalgroup = $self->groupname("journals", "$juser->{nickname}_$juser->{uid}");
			$ret{"$textroot.$journalgroup"} = "$sitename journals for $juser->{nickname} (UID $juser->{uid})";
			$ret{"$htmlroot.$journalgroup"} = "$sitename journals for $juser->{nickname} ($juser->{uid})";
		}
	}

	return %ret;
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
	} elsif($grouptype eq "journals") {
		my $where = "";
		$where = "UNIX_TIMESTAMP(date) > $time" if $time;

		my $journals = $self->{slash_db}->sqlSelectAllHashref(
			"id",
			"id",
			"journals",
			$where
		);

		foreach my $journal (values %$journals) {
			$ret{$journal->{id}} = $self->form_msgid($journal->{id}, $format, "journal");
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
			my $sectiongroup = "$self->{root}." . $self->groupname($format, "stories", "$story->{section}_".$self->{slash_db}->getSection($story->{section}, 'id'));
			my $fpgroup = "";
			$fpgroup = "$self->{root}." . $self->groupname($format, "stories") if $story->{nntp_posttime};

			$headers{subject} = $story->{title};
			$headers{newsgroups} = $sectiongroup;
			$headers{newsgroups} .= ",$fpgroup" if $fpgroup;
			$headers{xref} = $self->{slash_db}->getVar("nntp_host") . " $sectiongroup:$story->{nntp_section_snum}";
			$headers{xref} .= " $fpgroup:$story->{nntp_snum}" if $fpgroup;
			$headers{"followup-to"} = "$sectiongroup.$story->{sid}";
			$headers{"x-slash-url"} = "http:" . $self->{slash_db}->getVar('rootdir', 'value') . "/article.pl?sid=$story->{sid}";
			$headers{"x-slash-topic"} = $self->{slash_db}->getTopic($story->{tid}, 'name');
			$headers{"x-slash-dept"} = $story->{dept};
			$headers{"x-slash-can-post"} = $self->can_post("$sectiongroup.$story->{sid}");
		}
	} elsif($msgtype eq "comment") {
		my $comment = $self->{slash_db}->getComment($id) or return undef;

		# Ick, is this really the name of the function to do this?
		$body = $self->{slash_db}->_getCommentTextOld($id);

		$uid = $comment->{uid};
		$date = $comment->{date};

		if($type eq "head" or $type eq "article") {
			my $discussion = $self->{slash_db}->getDiscussion($comment->{sid});

			my($section, $sid) = ($discussion->{section}, $discussion->{sid});
			my $secid = $self->{slash_db}->getSection($section, 'id');
			my($jid, $journal_nick, $journal_uid);
			if(!$sid) {
				$jid = $self->{slash_db}->sqlSelect("id", "journals", "discussion=$comment->{sid}");
				my $journal_obj = getObject("Slash::Journal");
				my $journal = $journal_obj->get($jid);
				$journal_uid = $journal->{uid};
				$journal_nick = $self->{slash_db}->getUser($journal_uid, 'nickname');
			}

			my $group = "$self->{root}." . $self->groupname($format, ($sid ? "stories" : "journals"), ($sid ? ("${section}_$secid", $sid) : ($journal_nick."_".$journal_uid)));

			$headers{subject} = $comment->{subject};
			$headers{newsgroups} = $group;
			$headers{xref} = $self->{slash_db}->getVar("nntp_host") . " $group:$comment->{nntp_cnum}";
			$headers{"x-slash-url"} = "http:" . $self->{slash_db}->getVar('rootdir', 'value') . "/comments.pl?sid=$comment->{sid}&cid=$comment->{cid}";
			$headers{"x-slash-score"} = $comment->{points};

			#if($comment->{reason}) {
				$headers{"x-slash-mod-reason"} = (split(/\|/, $self->{slash_db}->getVar("reasons", "value")))[$comment->{reason}];
			#}

			my @references = ();
			while($comment->{pid}) {
				$comment = $self->{slash_db}->getComment($comment->{pid});
				unshift @references, $self->form_msgid($comment->{cid}, $format, "comment");
			}

			# If it's a journal, the top-level post is the journal article
			my $journal = $self->{slash_db}->sqlSelect("discussion", "journals", "discussion = $comment->{sid}");
			unshift @references, $self->form_msgid($journal, $format, "journal") if $journal;

			$headers{references} = join(" ", @references) if @references;
		}
	} elsif($msgtype eq "journal") {
		my $journal_obj = getObject("Slash::Journal") or return fail("500 Couldn't get Slash::Journal");
		my $journal = $journal_obj->get($id) or return undef;
		$body = $journal->{article};
		$uid = $journal->{uid};
		$date = $journal->{date};

		if($type eq "head" or $type eq "article") {
			my $group = "$self->{root}." . $self->groupname($format, "journals", $self->{slash_db}->getUser($journal->{uid}, 'nickname')."_$journal->{uid}");

			$headers{subject} = $journal->{description};
			$headers{newsgroups} = "$group,$self->{root}.$format.journals";
			$headers{xref} = $self->{slash_db}->getVar("nntp_host") . " $group:$journal->{nntp_cnum}";
			$headers{"followup-to"} = $group;
			$headers{"x-slash-url"} = "http:" . $self->{slash_db}->getVar('rootdir', 'value') . "/journal.pl?op=display&uid=$journal->{uid}&id=$journal->{id}";
			$headers{"x-slash-topic"} = $self->{slash_db}->getTopic($journal->{tid}, 'name');
			$headers{"x-slash-can-post"} = $journal->{discussion} ? 1 : 0;
		}
	}

	if($type eq "head" or $type eq "article") {
		if(!@headers or $get_headers{from}) {
			my $uinfo = $self->{slash_db}->getUser($uid);
			my $email = $uinfo->{fakeemail} || $uinfo->{realemail};
			my $name = $uinfo->{realname};
			$headers{from} = $name ?
				"$name <$email>" :
				$email;
		}
		$headers{"x-slash-user"} = $self->{slash_db}->getUser($uid, 'nickname') . " ($uid)" if !@headers or $get_headers{"x-slash-user"};

		$headers{date} = timeCalc($date, "%d %b %Y %H:%M:%S ". $self->{slash_user}->{off_set}/60/60);
	}

	$self->consume_subscription() unless $type eq "head";

	if($type ne "head" or $get_headers{lines} or $get_headers{bytes}) {
		$body = $self->html2txt($body) if $format eq "text";
		$self->log("Body: $body", LOG_DEBUG);
		my @lines = split(/\n/, $body);
		$headers{lines} = scalar @lines;
		$headers{bytes} = length($body);
	}

	if(@headers) {
		foreach my $header (keys %headers) {
			delete $headers{$header} unless $get_headers{$header};
		}
	}

	return 1, $body, %headers;
}

sub auth($$$) {
	my($self, $user, $pass) = @_;

	$self->do_log("Authenticating $user...", LOG_NOTICE);
	my($uid) = $self->{slash_db}->getUserAuthenticate($self->{slash_db}->getUserUID($user), $pass);
	return 0 unless $uid;
	$self->{slash_user} = $self->{slash_db}->getUser($uid);
	$self->do_log("User authenticated!", LOG_NOTICE);
	return 1;
}

sub post($$$) {
	my($self, $head, $body) = @_;
	$self->auth_status_ok() or return fail("480 Authorization Required");

	my $journal_obj;

	$self->do_log("Posting an article...", LOG_NOTICE);

	my $uid = $self->{slash_user}->{uid};
	$uid = $self->{slash_constants}->{anonymous_coward_uid} if
		$head->{"x-slash-anon"} or
		$head->{"x-slash-anonymous"} or
		$head->{"x-slash-post-anon"} or
		$head->{"x-slash-post-anonymous"} or
		$head->{"x-slash-post-anonymously"};

	return fail("500 Anonymous posting not allowed")
		if $uid == $self->{slash_constants}->{anonymous_coward_uid} and
		not $self->{slash_db}->getVar("allow_anonymous", "value");

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
	($id, undef, $type) = $self->parsegroup($head->{newsgroups});
	my $sid;

	my $posttype = "comment";
	my $cnum;
	my $pid = 0;

	if($type eq "journal") {
		if(!$head->{references}) {
			return fail("500 Can't make top-level post in someone else's journal") unless $id == $self->{slash_user}->{uid};
			$posttype = "journal";
		} else {
			my $type;
			($pid, undef, $type) = $self->parse_msgid($head->{references});

			if($type eq "journal") {
				my $journal_obj = getObject("Slash::Journal") or return fail("500 Couldn't get Slash::Journal");
				my $journal = $journal_obj->get($pid) or return fail("500 Couldn't find journal");
				$sid = $self->{slash_db}->getDiscussion($journal->{discussion}, 'sid');
				return fail("500 Comments are not allowed on that journal") unless $sid;

				$pid = 0;
			} else { # comment
				my $parent = $self->{slash_db}->getComment($pid)
					or return fail("500 That comment could not be located");
			}
		}
		$cnum = $self->{slash_nntp}->next_num("journal_cnum", $id);
	} elsif($type eq "story") { # comment
		$cnum = $self->{slash_nntp}->next_num("cnum", $id);

		($pid, undef, $type) = $self->parse_msgid($head->{references});
		if($type eq "story") {
			return fail("500 Comment posting has been disabled for that story")
				unless $self->{slash_db}->getStory($pid, "commentstatus") == 0;
			$sid = $self->{slash_db}->getStory($pid, "discussion");
			$pid = 0;
		} else {
			$sid = $self->{slash_db}->getComment($pid, "sid");
		}
	} else { # Attempt to post to frontpage, section, or journals group
		return fail("500 Can't post to that group");
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
		(undef, undef, $type) = $self->parse_msgid($head->{references});

		# Yay for having to C+P code from sub createAccessLog!
		my $ipid = md5_hex($self->client_ip);
		my $subnetid = $self->client_ip;
		$subnetid =~ s/^(\d+\.\d+\.\d+)\.\d+$/$1.0/;
		$subnetid = md5_hex($subnetid);

		$self->do_log("Posting comment: SID=$sid, PID=$pid, CNUM=$cnum", LOG_NOTICE);

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

		$self->do_log("Posting journal", LOG_NOTICE);

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
			$self->do_log("Creating journal discussion: JID=$jid", LOG_NOTICE);

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

	$self->log("is_group($group)", LOG_DEBUG);

	$group = lc($group);
	my $root = substr($group, 0, length($self->{root}) + 1, "");
	return 0 unless $root eq lc($self->{root}) . ".";

	$self->log("Down to $group", LOG_DEBUG);

	return 0 unless $group;
	my @groupparts = split(/\./, $group);

	my $format = shift @groupparts or return 0;
	$self->log("format $format", LOG_DEBUG);
	return 0 unless $format eq "text" or $format eq "html";

	my $type = shift @groupparts or return 0;
	$self->log("type $type", LOG_DEBUG);

	if($type eq "stories") {
		my $section = shift @groupparts or return 1;
		$section =~ s/_(\d+)$// or return 0;
		my $sectid = $1;
		$self->log("section $section, ID $sectid", LOG_DEBUG);
		return 0 unless $section;

		my($section_data) = grep { $_->{id} == $sectid } values %{$self->{slash_db}->getSections()};

		return 0 unless $section_data;
		return 0 unless lc($self->groupname($section_data->{section})) eq $section;

		my $sid = shift @groupparts or return 1;
		$self->log("SID $sid", LOG_DEBUG);
		return 0 unless my $story = $self->{slash_db}->getStory($sid);
		return 0 unless $story->{section} eq $section;
		$self->log("Ok!", LOG_DEBUG);
		return 1;
	} elsif($type eq "journals") {
		my $nick = shift @groupparts or return 1;
		$nick =~ s/_(\d+)$// or return 0;
		my $uid = $1;
		$self->log("nick $nick, UID $uid", LOG_DEBUG);
		return 0 unless $nick;

		return 0 unless lc($self->groupname($self->{slash_db}->getUser($uid, 'nickname'))) eq $nick;
		$self->log("Ok!", LOG_DEBUG);
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

	return 0 if $type eq "frontpage" or $type eq "section" or $type eq "journals";
	return 1 if $type eq "journal";
	my $story = $self->{slash_db}->getStory($id);
	return 0 unless $story->{commentstatus} == 0;
	return 1;
}

sub groupstats($$) { 
	my($self, $group) = @_;
	$self->auth_status_ok() or return fail("480 Authorization Required");

	$self->log("groupstats($group)", LOG_DEBUG);

	my($first, $last, $num) = (undef, undef, 0);
	my($id, $format, $type) = $self->parsegroup($group);

	$self->log("(id, type): ($id, $type)", LOG_DEBUG);

	if($type eq "frontpage") {
		($first, $last, $num) = $self->{slash_db}->sqlSelect(
						"MIN(nntp_snum), MAX(nntp_snum), COUNT(nntp_snum)",
						"stories",
						"NOT ISNULL(nntp_snum)");
	} elsif($type eq "journals") {
		($first, $last, $num) = $self->{slash_db}->sqlSelect(
						"MIN(id), MAX(id), COUNT(id)",
						"journals");
	} elsif($type eq "section") {
		($first, $last, $num) = $self->{slash_db}->sqlSelect(
						"MIN(nntp_section_snum), MAX(nntp_section_snum), COUNT(nntp_section_snum)",
						"stories",
						"NOT ISNULL(nntp_section_snum) AND section=".$self->{slash_db}->sqlQuote($id));
	} elsif($type eq "story") {
		($first, $last, $num) = $self->{slash_db}->sqlSelect(
						"MIN(nntp_cnum), MAX(nntp_cnum), COUNT(nntp_cnum)",
						"comments",
						"NOT ISNULL(nntp_cnum) AND sid=".$self->{slash_db}->getStory($id, 'discussion'));
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
						"NOT ISNULL(nntp_cnum) AND comments.sid=$journal->{discussion}");
				$first = $dfirst if !defined($first) or $dfirst < $first;
				$last = $dlast if !defined($last) or $dlast > $last;
				$num += $dnum;
			}
		}
	}

	($first, $last, $num) = (1, 0, 0) if !defined($first) || !defined($last);

	$self->log("Returning ($first, $last, $num)", LOG_DEBUG);
	return ($first, $last, $num);
}

1;
