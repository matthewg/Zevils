#!/usr/bin/perl -w
# This code is a part of NNTB, and is released under the GPL.
# Copyright 2002 by Matthew Sachs. See README and COPYING for
# more information, or see http://www.zevils.com/programs/nntb/.
# $Id$

use strict;

my $me = 'nntp.pl';

use vars qw( %task );

$task{$me}{timespec} = '1-59/2 * * * *';
$task{$me}{timespec_panic_1} = '1-59/5 * * * *'; # less often
$task{$me}{code} = sub {
	my($virtual_user, $constants, $slashdb, $user) = @_;

	my $nntp = getObject('Slash::NNTP');
	unless ($nntp) {
		slashdLog("$me: could not instantiate Slash::NNTP object");
		return;
	}

	nntpLog("$me begin");

	# None of this stuff uses the cache.
	# However, we are only interested in things we haven't seen before.
	# This is going to be the new stuff that likely isn't in the cache anyway.
	# Also, we have extremely specific WHERE criteria; we'd have to do that by
	# grepping the entire (story/comment/journal) list if we were just going
	# to use getFoos...  OTOH, I could be completely mistaken.

	my $where = "displaystatus != -1";
	$where .= " AND (ISNULL(nntp_section_snum) OR (displaystatus = 0 AND ISNULL(nntp_snum)))";
	$where .= " AND time < NOW()";

	my $stories = $slashdb->sqlSelectAllHashref(
		"sid",
		"sid, section, displaystatus, nntp_snum, nntp_section_snum",
		"stories",
		$where,
		"ORDER BY time"
	);

	my $storycount = 0;
	foreach my $story (values %$stories) {
		my %values = ();

		if(!$story->{nntp_section_snum}) {
			$values{nntp_section_snum} = $nntp->next_num("section_snum", $story->{section});
			$values{nntp_section_posttime} = "NOW()";
		}

		if($story->{displaystatus} == 0 and !$story->{nntp_snum}) {
			$values{nntp_snum} = $nntp->next_num("snum");
			$values{nntp_posttime} = "NOW()";
		}

		next unless keys %values;
		nntpLog("Updating story $story->{sid}");
		$slashdb->sqlUpdate("stories", \%values, "sid=".$slashdb->sqlQuote($story->{id}));
		$storycount++;
	}

	my $from = "comments";
	$where = "ISNULL(nntp_cnum)";

	if($slashdb->getDescriptions("plugins")->{Journal}) {
		$from .= ", topics";
		$where .= " AND stories.tid = topics.tid";
		$where .= " AND topics.name != \"journal\"";
	}

	my $comments = $slashdb->sqlSelectAllHashref(
		"cid",
		"sid, cid",
		$from,
		$where,
		"ORDER BY sid, cid"
	);

	my $commentcount = 0;
	foreach my $comment (values %$comments) {
		nntpLog("Updating comment $comment->{cid} (SID $comment->{sid})");
		$slashdb->sqlUpdate("comments", {
			nntp_cnum => $nntp->next_num("cnum", $comment->{sid}),
			nntp_posttime => "NOW()"
		}, "cid=$comment->{cid}");
		$commentcount++;
	}

	my $journalcount = 0;
	if($slashdb->getDescriptions("plugins")->{Journal}) {
		my $journals = $slashdb->sqlSelectAllHashref(
			"id",
			"id, uid",
			"journals",
			"ISNULL(nntp_cnum)",
			"ORDER BY uid, id"
		);

		$journalcount = 0;
		foreach my $journal (values %$journals) {
			nntpLog("Updating journal $journal->{id} (UID $journal->{uid})");
			$slashdb->sqlUpdate("journals", {
				nntp_cnum => $nntp->next_num("journal_cnum", $journal->{uid}),
				nntp_posttime => "NOW()"
			}, "id=$journal->{id}");
			$journalcount++;
		}

		$where = "ISNULL(nntp_cnum)";
		$where .= " AND comments.sid = discussions.id";
		$where .= " AND discussions.topic = topics.tid";
		$where .= " AND topics.name = \"journal\"";
		$where .= " AND comments.sid = journals.discussion";

		$comments = $slashdb->sqlSelectAllHashref(
			"cid",
			"comments.sid AS sid, cid, journals.uid AS uid",
			"comments, discussions, topics, journals",
			$where,
			"ORDER BY sid, cid"
		);

		foreach my $comment (values %$comments) {
			nntpLog("Updating journal comment $comment->{cid} (SID $comment->{sid})");
			$slashdb->sqlUpdate("comments", {
				nntp_cnum => $nntp->next_num("journal_cnum", $comment->{uid}),
				nntp_posttime => "NOW()"
			}, "cid=$comment->{cid}");
			$commentcount++;
		}
	}

	nntpLog("$me end");
	if ($storycount || $commentcount || $journalcount) {
		return "updated NNTP information for $storycount stories, $commentcount comments, and $journalcount journals";
	} else {
		return ;
	}
};

my $errsub = sub {
	doLog('nntp', \@_);
};

*nntpLog = $errsub unless defined &nntpLog;

1;
