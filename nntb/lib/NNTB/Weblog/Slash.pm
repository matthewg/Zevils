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
use Slash::Utility::Data;
use Digest::MD5 qw(md5_hex);

use Fcntl ':flock';
use IO::Handle;

sub new($;@) {
	my $type = shift;
	my $self = $type->SUPER::new(@_);

	my %params = @_;
	my @params = qw(datadir slashsites slashsite snum_lockfile);

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

	$self->{slash_snum_lockfile} ||= "$self->{slash_datadir}/site/$self->{slash_slashsite}/misc/nntb_snum.lock";

	$self->{slash_virtuser} = $slashsites{$self->{slash_slashsite}};
	createEnvironment($self->{slash_virtuser});
	$self->{slash_constants} = getCurrentStatic();
	$self->{slash_db} = getCurrentDB();
	$self->{slash_user} = getCurrentUser();

	croak "You must install the Slash NNTP plugin in order to use NNTB" unless $self->{slash_db}->getDescriptions("plugins")->{NNTP};

	$self->{root} ||= $self->groupname("slash", lc($self->{slash_db}->getVar("sitename", "value")));

	$self->log("Created NNTB::Weblog::Slash: root=$self->{root}", LOG_NOTICE);

	return $self;
}

sub root($) { return shift->{root}; }

# Parses a group, returning:
#	ID:
#		section: section name or empty string (== front page)
#		story: discussion ID
#		journals: UID or empty string (== all journals)
#		journal: JID
#	format: "html" or "text"
#	type: "section", "story", "journals", "journal"
sub parsegroup($$) {
	my($self, $group) = @_;
	my($id, $format, $type);

	$group = lc($group);
	#$self->log("parsegroup $group", LOG_DEBUG);

	substr($group, 0, length($self->{root}) + 1) = ""; # Remove root (and trailing .)
	my(@groupparts) = split(/\./, $group);
	#$self->log("groupparts: ", join(", ", map { "<$_>" } @groupparts), LOG_DEBUG);
	my @ret;

	$format = shift @groupparts; # text/html
	$type = shift @groupparts;
	if($type eq "stories") { # .stories
		$type = "section";
		$id = "";

		if(@groupparts) { # .section
			$id = shift @groupparts;
			$id =~ /^(.+)_(\d+)$/;
			$id = $2; # Now ID is section number

			# Section name was possibly mangled
			my ($sectname) = map { $_->{section} } grep { $_->{id} == $id } values %{$self->{slash_db}->getSections()};
			$id = $sectname;

			# Now ID is section name again

			if(@groupparts) { # .SID
				$id = shift @groupparts;
				$type = "story";
			}
		}
	} elsif($type eq "journals") { # .journals
		$type = "journals";
		$id = "";

		if(@groupparts) { # .nick_uid
			$id = shift @groupparts;
			$id =~ /^(.+)_(\d+)$/;
			$id = $2; # Now ID is UID

			if(@groupparts) { # .JID
				$id = shift @groupparts;
				$type = "journal";
			}
		}
	}

	#$self->log("parsegroup returning ($id, $format, $type)", LOG_DEBUG);
	return ($id, $format, $type);
}

# $id should be either a comment ID, a story ID, or a journal ID
# $format should be "text" or "html"
# $type should be either "story_comment", "journal_comment", "story", "journal"
sub form_msgid($$$$) {
	my($self, $id, $format, $type) = @_;
	return "<$id\@$type.$format.$self->{root}>";
}

# Parses a message ID, returning:
#	ID: A comment, story, or journal ID
#	format: "html" or "text"
#	type: "story_comment", or "journal_comment", "story", "journal"
sub parse_msgid($$) {
	my($self, $msgid) = @_;
	$msgid =~ /
		^<	#			 Starts with left angle bracket
		(.+?)\@				# Followed by whatever it takes to get an @ ($1)
		(				# Followed by ... ($2)
			(?:story|journal)	# "story" or "journal"
			(?:_comment)?		# and maybe "_comment"
		)\.				# Followed by "."
		(html|text)\.			# Followed by "html" or "text" ($3), "."
	/x or return ();
	return ($1, $3, $2);
}

sub num2id($$$) {
	my($self, $group, $msgnum) = @_;

	my($id, $format, $type) = $self->parsegroup($group);
	my($idtype, $idid);

	if($type eq "section") {
		$idtype = "story";
		$idid = $self->{slash_db}->sqlSelect("sid", "stories",
			"nntp_snum=$msgnum") or return undef;
	} elsif($type eq "journals") {
		$idtype = "journal";
		$idid = $self->{slash_db}->sqlSelect("id", "journals",
			"id=$msgnum") or return undef;
	} elsif($type eq "story") {
		$idtype = "story_comment";
		$idid = $self->{slash_db}->sqlSelect("cid", "comments",
			"cid=$msgnum") or return undef;
	} elsif($type eq "journal") {
		$idtype = "journal_comment";
		$idid = $self->{slash_db}->sqlSelect("cid", "comments",
			"cid=$msgnum") or return undef;
	}

	my $msgid = $self->form_msgid($idid, $format, $idtype);
	#$self->log("num2id: $group.$msgnum -> $msgid", LOG_NOTICE);
	return $msgid;
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
	$self->log("Yum yum, subscriptions are delicious!", LOG_NOTICE);
	$self->{slash_db}->setUser($self->{slash_user}->{uid}, {hits_paidfor => $self->{slash_db}->getUser($self->{slash_user}->{uid}, 'hist_paidfor') + 1});
}

sub description($$) {
	my($self, $group) = @_;
	my($id, $format, $type) = $self->parsegroup($group);

	my $sitename = $self->{slash_db}->getVar("sitename", "value");
	if($type eq "section") {
		return "$sitename front page stories" unless $id;
		return "$sitename $id stories";
	} elsif($type eq "story") {
		my $sid = $self->{slash_db}->sqlSelect('sid', 'stories', "discussion=$id");
		my $story = $self->{slash_db}->getStory($sid);
		my $topic = $self->{slash_db}->getTopic($story->{tid}, 'name');
		return "$story->{title} ($topic)";
	} elsif($type eq "journals") {
		return "All $sitename journals" unless $id;
		my $nick = $self->{slash_db}->getUser($id, 'nickname');
		return "$sitename journals for $nick (UID $id)";
	} elsif($type eq "journal") {
		my $journal_obj = getObject("Slash::Journal");
		my $journal = $journal_obj->get($id);
		return $journal->{description};
	}
}

sub groups($;$) {
	my($self, $time) = @_;
	my %ret = ();

	$self->auth_status_ok() or return $self->fail("480 Authorization Required");

	$time ||= 0;
	$time =~ tr/0-9//dc;

	# slash.slashsite.{text,html}
	#                            .stories
	#                                    .section_sectid
	#                                            .discussionID
	#                            .journals
	#                                     .nick_uid
	#                                              .jid

	my $sitename = $self->{slash_db}->getVar("sitename", "value");
	my $textroot = "$self->{root}.text";
	my $htmlroot = "$self->{root}.html";
	$ret{"$textroot.stories"} = "$sitename front page stories";
	$ret{"$htmlroot.stories"} = "$sitename front page stories";

	my $sections = $self->{slash_db}->getSections();

	foreach my $section (values %$sections) {
		next unless timeCalc($section->{nntp_ctime}, "%s") > $time;

		my $group = $self->groupname("$section->{section}_$section->{id}");
		$ret{"$textroot.stories.$group"} = "$sitename $section->{title} stories";
		$ret{"$htmlroot.stories.$group"} = "$sitename $section->{title} stories";
	}

	# Not using cache == bad, true.
	# But in order to use the cache, I'd have to call getStories().
	# Do you *really* want to burden the cache with SELECT * FROM stories?
	# Keep in mind that since we fork for each client, the cache wouldn't
	#  be shared between clients.

	my $stories =  $self->{slash_db}->sqlSelectAllHashref(
		'discussion',
		'discussion, tid, section, title',
		'stories',
		"NOT ISNULL(discussion) AND UNIX_TIMESTAMP(nntp_ctime) > $time"
	);


	foreach my $story (values %$stories) {
		my $storygroup = $self->groupname("$story->{section}_".$self->{slash_db}->getSection($story->{section}, 'id'), $story->{discussion});
		my $topic = $self->{slash_db}->getTopic($story->{tid}, 'name');

		$ret{"$textroot.stories.$storygroup"} = "$story->{title} ($topic)";
		$ret{"$htmlroot.stories.$storygroup"} = "$story->{title} ($topic)";
	}

	if($self->{slash_db}->getDescriptions("plugins")->{Journal}) {
		$ret{"$textroot.journals"} = "All $sitename journals";
		$ret{"$htmlroot.journals"} = "All $sitename journals";

		my $jusers = $self->{slash_db}->sqlSelectAllHashref(
			'nickname',
			'nickname, journals.uid AS uid, UNIX_TIMESTAMP(MIN(date)) AS jdate',
			'journals, users',
			'users.uid = journals.uid GROUP BY nickname, uid HAVING jdate > '.$time
		);
		foreach my $juser(values %$jusers) {
			# No getJournals...
			my $journalgroup = $self->groupname("journals", "$juser->{nickname}_$juser->{uid}");

			$ret{"$textroot.$journalgroup"} = "$sitename journals for $juser->{nickname} (UID $juser->{uid})";
			$ret{"$htmlroot.$journalgroup"} = "$sitename journals for $juser->{nickname} ($juser->{uid})";

			my $journals = $self->{slash_db}->sqlSelectAllHashref(
				'id', 'id, description', 'journals',
				"UNIX_TIMESTAMP(date) > $time AND uid=$juser->{uid} AND NOT ISNULL(discussion)"
			);
			foreach my $journal(values %$journals) {
				$ret{"$textroot.$journalgroup.$journal->{id}"} = $journal->{description};
				$ret{"$htmlroot.$journalgroup.$journal->{id}"} = $journal->{description};
			}
		}
	}

	return %ret;
}

# This neat thing updates stories.nntp_{snum,ctime}.
# It's called from sub articles and sub groupstats (but only when checking section groups).
# Have to be careful to avoid race conditions...
# This lock is a bit too coarse-grained for my tastes.
# However, except for the first time it runs, it should be fairly quick.
sub update_stories($) {
	my $self = shift;

	open SEM, ">$self->{slash_snum_lockfile}" or croak "Couldn't open $self->{slash_snum_lockfile} for output: $!";
	flock SEM, LOCK_EX;
	autoflush SEM 1;

	my $stories = $self->{slash_db}->sqlSelectAllHashref(
		'sid', 'sid, UNIX_TIMESTAMP(time) AS time',
		'stories',
		'ISNULL(nntp_snum) AND displaystatus > -1'
	);

	my $snum = $self->{slash_db}->sqlSelect('MAX(nntp_snum)', 'stories');

	foreach my $story (sort { $a->{time} <=> $b->{time} } values %$stories) {
		$self->{slash_db}->sqlUpdate(
			'stories',
			{
				nntp_snum => ++$snum,
				-nntp_ctime => 'NOW()'
			},
			'sid = '.$self->{slash_db}->sqlQuote($story->{sid})
		);
	}

	close SEM;
}

sub articles($$;$) {
	my($self, $group, $time) = @_;
	$self->auth_status_ok() or return $self->fail("480 Authorization Required");

	my %ret;
	my($id, $format, $grouptype) = $self->parsegroup($group);

	if($grouptype eq "section") {
		my $sect = "";
		$sect = "_section" if $grouptype eq "section";

		my $where = "NOT ISNULL(nntp_ctime)";
		$where .= " AND UNIX_TIMESTAMP(nntp_ctime) > $time" if $time;
		if($id) {
			$where .= " AND section=".$self->{slash_db}->sqlQuote($id);
		} else {
			$where .= " AND displaystatus = 0";
		}

		$self->update_stories();

		my $stories = $self->{slash_db}->sqlSelectAllHashref(
			"nntp_snum",
			"nntp_snum, id",
			"stories",
			$where
		);

		foreach my $story (values %$stories) {
			$ret{$story->{"nntp_snum"}} = $self->form_msgid($story->{id}, $format, "story");
		}
	} elsif($grouptype eq "journals") {
		my $where = "1 = 1";
		$where .= " AND uid=$id" if $id;
		$where .= " AND UNIX_TIMESTAMP(date) > $time" if $time;

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

		my $where = "1 = 1";
		$where .= " AND UNIX_TIMESTAMP(nntp_posttime) > $time" if $time;

		if($grouptype eq "story") {
			$where .= " comments.sid = $id";
		} else {
			$from .= ", journals";
			$where .= " AND journals.discussion = comments.sid";
			$where .= " AND journals.id = $id";
		}

		my $comments = $self->{slash_db}->sqlSelectAllHashref(
			"cid",
			"cid",
			$from,
			$where
		);

		foreach my $comment (values %$comments) {
			$ret{$comment->{cid}} = $self->form_msgid($comment->{cid}, $format, "comment");
		}
	}

	return %ret;
}

sub article($$$;@) {
	my($self, $type, $msgid, @headers) = @_;
	$self->auth_status_ok() or return $self->fail("480 Authorization Required");

	my(%headers, $body);
	my %get_headers = map { $_ => 1 } @headers;
	my($id, $format, $msgtype) = $self->parse_msgid($msgid) or return undef;

	$headers{path} = "$self->{slash_slashsite}!not-for-mail";
	$headers{"message-id"} = $msgid;
	$headers{"content-type"} = "text/html; charset=us-ascii" if $format eq "html";

	my($uid, $date);

	if($msgtype eq "story") {
		my $story = $self->{slash_db}->getStory($id) or return undef;
		$body = "$story->{introtext}<p>$story->{bodytext}";
		$uid = $story->{uid};
		$date = $story->{time};

		if($type eq "head" or $type eq "article") {
			my $sectiongroup = "$self->{root}." . $self->groupname($format, "stories", "$story->{section}_".$self->{slash_db}->getSection($story->{section}, 'id'));
			my $fpgroup = "";
			$fpgroup = "$self->{root}." . $self->groupname($format, "stories") if $story->{displaystatus} == 0;

			$headers{subject} = $story->{title};
			$headers{newsgroups} = $sectiongroup;
			$headers{newsgroups} .= ",$fpgroup" if $fpgroup;
			$headers{xref} = $self->{slash_db}->getVar('nntp_host', 'value') . " $sectiongroup:$story->{nntp_snum}";
			$headers{xref} .= " $fpgroup:$story->{nntp_snum}" if $fpgroup;
			$headers{"followup-to"} = "$sectiongroup.$story->{discussion}" if $story->{discussion};
			$headers{"x-slash-url"} = "http:" . $self->{slash_db}->getVar('rootdir', 'value') . "/article.pl?sid=$story->{sid}";
			$headers{"x-slash-topic"} = $self->{slash_db}->getTopic($story->{tid}, 'name');
			$headers{"x-slash-dept"} = $story->{dept};
			$headers{"x-slash-can-post"} = $self->can_post("$sectiongroup.$story->{sid}");
		}
	} elsif($msgtype eq "story_comment" or $msgtype eq "journal_comment") {
		my $comment = $self->{slash_db}->getComment($id) or return undef;

		# Ick, is this really the name of the function to do this?
		$body = $self->{slash_db}->_getCommentTextOld($id);

		$uid = $comment->{uid};
		$date = $comment->{date};

		if($type eq "head" or $type eq "article") {
			my $discussion = $self->{slash_db}->getDiscussion($comment->{sid});
			my $group;

			if($msgtype eq "story_comment") {
				my($section, $sid) = ($discussion->{section}, $discussion->{sid});
				my $secid = $self->{slash_db}->getSection($section, 'id');

				$group = "$self->{root}." . $self->groupname($format, "stories", "${section}_$secid", $comment->{sid});
			} else {
				$self->log("Discussion $comment->{sid}", LOG_DEBUG);
				my $jid = $self->{slash_db}->sqlSelect("id", "journals", "discussion=$comment->{sid}");
				my $journal_obj = getObject("Slash::Journal");
				my $journal = $journal_obj->get($jid);
				my $juid = $journal->{uid};
				my $jnick = $self->{slash_db}->getUser($juid, 'nickname');

				$group = "$self->{root}." . $self->groupname($format, "journals", "${jnick}_$juid", $jid);
			}

			$headers{subject} = $comment->{subject};
			$headers{newsgroups} = $group;
			$headers{xref} = $self->{slash_db}->getVar('nntp_host', 'value') . " $group:$comment->{cid}";
			$headers{"x-slash-url"} = "http:" . $self->{slash_db}->getVar('rootdir', 'value') . "/comments.pl?sid=$comment->{sid}&cid=$comment->{cid}";
			$headers{"x-slash-score"} = $comment->{points};

			#if($comment->{reason}) {
				$headers{"x-slash-mod-reason"} = (split(/\|/, $self->{slash_db}->getVar("reasons", "value")))[$comment->{reason}];
			#}

			my @references = ();
			while($comment->{pid}) {
				$comment = $self->{slash_db}->getComment($comment->{pid});
				unshift @references, $self->form_msgid($comment->{cid}, $format, $msgtype);
			}

			$headers{references} = join(" ", @references) if @references;
		}
	} elsif($msgtype eq "journal") {
		my $journal_obj = getObject("Slash::Journal") or return $self->fail("500 Couldn't get Slash::Journal");
		my $journal = $journal_obj->get($id) or return undef;
		$body = $journal->{article};
		$uid = $journal->{uid};
		$date = $journal->{date};

		if($type eq "head" or $type eq "article") {
			my $group = "$self->{root}." . $self->groupname($format, "journals", $self->{slash_db}->getUser($journal->{uid}, 'nickname')."_$journal->{uid}");

			$headers{subject} = $journal->{description};
			$headers{newsgroups} = "$group,$self->{root}.$format.journals";
			$headers{xref} = $self->{slash_db}->getVar('nntp_host', 'value') . " $group:$journal->{id}";
			$headers{"followup-to"} = "$group.$journal->{id}" if $journal->{discussion};
			$headers{"x-slash-url"} = "http:" . $self->{slash_db}->getVar('rootdir', 'value') . "/journal.pl?op=display&uid=$journal->{uid}&id=$journal->{id}";
			$headers{"x-slash-topic"} = $self->{slash_db}->getTopic($journal->{tid}, 'name');
			$headers{"x-slash-can-post"} = $journal->{discussion} ? 1 : 0;
		}
	}

	if($type eq "head" or $type eq "article") {
		my $uinfo = $self->{slash_db}->getUser($uid);
		my $email = $uinfo->{fakeemail} || $uinfo->{realemail};
		my $name = $uinfo->{realname};
		$headers{from} = $name ?
			"$name <$email>" :
			$email;
		$headers{"x-slash-user"} = $self->{slash_db}->getUser($uid, 'nickname') . " ($uid)" if !@headers or $get_headers{"x-slash-user"};

		$headers{date} = timeCalc($date, "%d %b %Y %H:%M:%S ". $self->{slash_user}->{off_set}/60/60);
	}

	$self->consume_subscription() unless $type eq "head";

	if($type ne "head" or !@headers or $get_headers{lines} or $get_headers{bytes}) {
		$body = $self->html2txt($body) if $format eq "text";
		$self->log("Body: $body", LOG_DEBUG);
		my @lines = split(/\n/, $body);
		$headers{lines} = scalar @lines;
		$headers{bytes} = length($body);
	}

	return 1, $body, %headers;
}

sub auth($$$) {
	my($self, $user, $pass) = @_;

	$self->log("Authenticating $user...", LOG_NOTICE);
	my($uid) = $self->{slash_db}->getUserAuthenticate($self->{slash_db}->getUserUID($user), $pass);
	return 0 unless $uid;
	$self->{slash_user} = $self->{slash_db}->getUser($uid);
	$self->log("User authenticated!", LOG_NOTICE);
	return 1;
}

sub post($$$) {
	my($self, $head, $body) = @_;
	$self->auth_status_ok() or return $self->fail("480 Authorization Required");

	my $journal_obj;

	$self->log("Posting an article...", LOG_NOTICE);

	my $uid = $self->{slash_user}->{uid};
	$uid = $self->{slash_constants}->{anonymous_coward_uid} if
		$head->{"x-slash-anon"} or
		$head->{"x-slash-anonymous"} or
		$head->{"x-slash-post-anon"} or
		$head->{"x-slash-post-anonymous"} or
		$head->{"x-slash-post-anonymously"};

	return $self->fail("500 Anonymous posting not allowed")
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
	my $pid = 0;

	if($type eq "journal") {
		$journal_obj = getObject("Slash::Journal") or return $self->fail("500 Couldn't get Slash::Journal");
		my $journal = $journal_obj->get($id) or return $self->fail("500 Couldn't find journal");
		$sid = $journal->{discussion};
		return $self->fail("500 Comments are not allowed on that journal") unless $sid;

		if($head->{references}) {
			my $type;
			($pid, undef, $type) = $self->parse_msgid($head->{references});

			if($type eq "journal") {
				$pid = 0;
			} else { # comment
				my $parent = $self->{slash_db}->getComment($pid)
					or return $self->fail("500 That comment could not be located");
				$parent->{sid} == $sid
					or return $self->fail("500 That comment is not part of this journal.");
			}
		}
	} elsif($type eq "story") { # comment
		($pid, undef, $type) = $self->parse_msgid($head->{references});
		if($type eq "story") {
			return $self->fail("500 Comment posting has been disabled for that story")
				unless $self->{slash_db}->getStory($pid, "commentstatus") == 0;
			$sid = $self->{slash_db}->getStory($pid, "discussion");
			$pid = 0;
		} else {
			$sid = $self->{slash_db}->getComment($pid, "sid");
		}
	} elsif($type eq "journals") { # journal
		return $self->fail("500 Can't make top-level post in someone else's journal") unless $id and $id == $self->{slash_user}->{uid};
		$posttype = "journal";
	} else { # Attempt to post to frontpage, section, or journals group
		return $self->fail("500 Can't post to that group");
	}

	my $subject = $head->{subject} || "";

	my $mode = "";
	if($head->{"content-type"} =~ m!\btext/html\b!) {
		$mode = HTML;
	} else {
		$mode = PLAINTEXT;
	}
	$body = Slash::Utility::Data::stripByMode($body, $mode, 0);

	unless($posttype eq "journal") {
		(undef, undef, $type) = $self->parse_msgid($head->{references});

		# Yay for having to C+P code from sub createAccessLog!
		my $ipid = md5_hex($self->client_ip);
		my $subnetid = $self->client_ip;
		$subnetid =~ s/^(\d+\.\d+\.\d+)\.\d+$/$1.0/;
		$subnetid = md5_hex($subnetid);

		my $err_message;
		filterOk('comments', 'postersubj', $subject, \$err_message)
			or return $self->fail("500 Lameness filter encountered on subject: $err_message");
		compressOk('comments', 'postersubj', $subject)
			or return $self->fail("500 Compression filter encountered on subject");
		filterOk('comments', 'postercomment', $body, \$err_message)
			or return $self->fail("500 Lameness filter encountered on body: $err_message");
		compressOk('comments', 'postercomment', $subject)
			or return $self->fail("500 Compression filter encountered on body");

		$self->log("Posting comment: SID=$sid, PID=$pid, subject=$subject", LOG_NOTICE);

		my $comment = {
			sid => $sid,
			pid => $pid,
			ipid => $ipid,
			subnetid => $subnetid,
			subject => $subject,
			uid => $uid,
			points => $score,
			comment => $body
		};
		$self->{slash_db}->createComment($comment) != -1 or return $self->fail("500 Couldn't post comment: $DBI::errstr");
	} else {
		$ENV{SLASH_USER} = $self->{slash_user}->{uid};
		my $topic = $head->{"x-slash-topic"} || "journal";
		my($tid) = map { $_->{tid} } grep { $_->{name} eq $topic } values %{$self->{slash_db}->getTopics()};
		$tid ||= map { $_->{tid} } grep { $_->{name} eq "journal" } values %{$self->{slash_db}->getTopics()};

		$self->log("Posting journal", LOG_NOTICE);

		$journal_obj = getObject("Slash::Journal") or return $self->fail("500 Couldn't get Slash::Journal");
		$self->log("Posting journal: ($subject, body, 2, $tid)", LOG_NOTICE);
		my $jid = $journal_obj->create(
			$subject,
			$body,
			2, # posttype?
			$tid
		) or return $self->fail("500 Couldn't post journal");

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
			$self->log("Creating journal discussion: JID=$jid", LOG_NOTICE);

			my $did = $self->{slash_db}->createDiscussion({
				title => $subject,
				topic => $tid,
				url => $self->{slash_db}->getVar('rootdir', 'value') . "/~" . fixparam($self->{slash_user}->{nickname}) . "/journal/$jid",
			});
			$journal_obj->set($jid, { discussion => $did });
		}
	}

	$self->consume_subscription();
	return 1;
}

sub is_group($$) {
	my($self, $group) = @_;
	$self->auth_status_ok() or return $self->fail("480 Authorization Required");

	#$self->log("is_group($group)", LOG_DEBUG);

	$group = lc($group);
	my $root = substr($group, 0, length($self->{root}) + 1, "");
	return 0 unless $root eq lc($self->{root}) . ".";

	#$self->log("Down to $group", LOG_DEBUG);

	return 0 unless $group;
	my @groupparts = split(/\./, $group);

	my $format = shift @groupparts or return 0;
	#$self->log("format $format", LOG_DEBUG);
	return 0 unless $format eq "text" or $format eq "html";

	my $type = shift @groupparts or return 0;
	#$self->log("type $type", LOG_DEBUG);

	if($type eq "stories") {
		my $section = shift @groupparts or return 1;
		$section =~ s/_(\d+)$// or return 0;
		my $sectid = $1;
		#$self->log("section $section, ID $sectid", LOG_DEBUG);
		return 0 unless $section;

		my($section_data) = grep { $_->{id} == $sectid } values %{$self->{slash_db}->getSections()};

		return 0 unless $section_data;
		return 0 unless lc($self->groupname($section_data->{section})) eq $section;

		my $did = shift @groupparts or return 1;
		#$self->log("discussion $did", LOG_DEBUG);
		return 0 unless my $discussion = $self->{slash_db}->getDiscussion($did);
		return 0 unless $discussion->{section} eq $section;

		return 1;
	} elsif($type eq "journals") {
		my $nick = shift @groupparts or return 1;
		$nick =~ s/_(\d+)$// or return 0;
		my $uid = $1;
		#$self->log("nick $nick, UID $uid", LOG_DEBUG);
		return 0 unless $nick;

		return 0 unless lc($self->groupname($self->{slash_db}->getUser($uid, 'nickname'))) eq $nick;

		my $jid = shift @groupparts or return 1;
		my $journal_obj = getObject("Slash::Journal") or return 0;
		my $journal = $journal_obj->get($jid) or return 0;
		return 0 unless $journal->{uid} == $uid;

		#$self->log("Ok!", LOG_DEBUG);
		return 1;
	} else {
		return 0;
	}
}

sub can_post($$) {
	my($self, $group) = @_;
	$self->auth_status_ok() or return $self->fail("480 Authorization Required");

	return 0 if $self->{slash_user}->{uid} == 
			$self->{slash_constants}->{anonymous_coward_uid} and
				!$self->{slash_db}->getVar("allow_anonymous", "value");

	my($id, $format, $type) = $self->parsegroup($group);

	if($type eq "section") {
		return 0;
	} elsif($type eq "story") {
		my $story = $self->{slash_db}->getStory($id);
		return 0 unless $story->{commentstatus} == 0;
		return 1;
	} elsif($type eq "journals") {
		return 0 if $self->{slash_user}->{uid} ==
			$self->{slash_constants}->{anonymous_coward_uid};

		return 0 unless $id and $id == $self->{slash_user}->{uid};
		return 1;
	} elsif($type eq "journal") {
		return 1; # We don't create groups for no-discussion journals.
	}
}

sub groupstats($$) { 
	my($self, $group) = @_;
	$self->auth_status_ok() or return $self->fail("480 Authorization Required");

	#$self->log("groupstats($group)", LOG_DEBUG);

	my($first, $last, $num) = (1, 0, 0);
	my($id, $format, $type) = $self->parsegroup($group);

	#$self->log("(id, type): ($id, $type)", LOG_DEBUG);

	if($type eq "section") {
		$self->update_stories();

		my $where = "NOT ISNULL(nntp_snum)";
		if($id) {
			$where .= " AND section=".$self->{slash_db}->sqlQuote($id);
		} else {
			$where .= " AND displaystatus = 0";
		}

		($first, $last, $num) = $self->{slash_db}->sqlSelect(
						"MIN(nntp_snum), MAX(nntp_snum), COUNT(nntp_snum)",
						"stories",
						$where);
	} elsif($type eq "story") {
		($first, $last, $num) = $self->{slash_db}->sqlSelect(
						"MIN(cid), MAX(cid), COUNT(cid)",
						"comments",
						"sid=$id");
	} elsif($type eq "journals") {
		my $where = "";
		$where = "uid=$id" if $id;

		($first, $last, $num) = $self->{slash_db}->sqlSelect(
						"MIN(id), MAX(id), COUNT(id)",
						"journals",
						$where);
	} elsif($type eq "journal") {
		my $journal_obj = getObject("Slash::Journal") or return (1, 0, 0);
		my $journal = $journal_obj->get($id);

		($first, $last, $num) = $self->{slash_db}->sqlSelect(
						"MIN(cid), MAX(cid), COUNT(cid)",
						"comments",
						"sid=$journal->{discussion}");
	}

	#$self->log("Returning ($first, $last, $num)", LOG_DEBUG);
	return ($first, $last, $num);
}

sub prev_next($$$$$) {
	my($self, $group, $msgnum, $comparator, $sqlgroup) = @_;
	my($id, $format, $type) = $self->parsegroup($group);

	if($type eq "section") {
		my $where = "nntp_snum $comparator $msgnum";
		$where .= " AND section=".$self->{slash_db}->sqlQuote($id) if $id;

		return scalar $self->{slash_db}->sqlSelect(
				"$sqlgroup(nntp_snum)",
				'stories',
				$where
		);
	} elsif($type eq "story") {
		return scalar $self->{slash_db}->sqlSelect(
				"$sqlgroup(cid)",
				'comments',
				"cid $comparator $msgnum AND discussion=$id"
		);
	} elsif($type eq "journals") {
		my $where = "id $comparator $msgnum";
		$where .= " AND uid=$id" if $id;

		return scalar $self->{slash_db}->sqlSelect(
				"$sqlgroup(id)",
				'journals',
				$where
		);
	} elsif($type eq "journal") {
		return scalar $self->{slash_db}->sqlSelect(
				"$sqlgroup(cid)",
				'comments, journals',
				"cid $comparator $msgnum AND comments.sid = journals.discussion"
		);
	}
}

sub prev($$$) { shift->prev_next(@_, "<", "MAX"); }
sub next($$$) { shift->prev_next(@_, ">", "MIN"); }

sub msgnums($$$$) {
	my($self, $group, $min, $max) = @_;
	my($id, $format, $type) = $self->parsegroup($group);
	my $ret;

	$self->log("msgnums($group, $min, $max)", LOG_DEBUG);

	if($type eq "section") {
		my $where = "nntp_snum >= $min AND nntp_snum <= $max";
		if($id) {
			$where .= " AND section=".$self->{slash_db}->sqlQuote($id);
		} else {
			$where .= " AND displaystatus = 0";
		}

		$self->log("msgnums where: $where", LOG_DEBUG);
		$ret = $self->{slash_db}->sqlSelectAll('nntp_snum', 'stories', $where);
	} elsif($type eq "story") {
		$ret = $self->{slash_db}->sqlSelectAll('cid', 'comments', "sid = $id AND cid >= $min AND cid <= $max");
	} elsif($type eq "journals") {
		my $where = "id >= $min AND id <= $max";
		$where .= " AND uid=$id" if $id;

		$ret = $self->{slash_db}->sqlSelectAll('id', 'journals', $where);
	} elsif($type eq "journal") {
		$ret = $self->{slash_db}->sqlSelectAll('cid', 'comments, journals', "journals.id=$id AND comments.sid = journals.discussion AND cid >= $min AND cid <= $max");
	}

	$self->log("Returning: ", join(", ", sort map {@$_} @$ret), LOG_DEBUG);
	return sort map { @$_ } @$ret;
}

1;
