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

	messagedLog("$me begin");

	my $where = "displaystatus != -1";
	$where .= " AND (ISNULL(section_snum) OR (displaystatus = 0 AND ISNULL(snum)))";
	$where .= " AND time < NOW()";

	my $stories = $slashdb->sqlSelectAllHashref(
		"sid",
		"sid, displaystatus, snum, section_snum",
		"stories",
		$where,
		"ORDER BY time"
	);

	my $storycount = 0;
	foreach my $story (values %$stories) {
		my %values = ();
		$values{section_snum} = $nntp->next_num("section_snum", $story->{section}) unless $story->{section_snum};
		$values{snum} = $nntp->next_num("snum") if $story->{displaystatus} == 0 and !$story->{snum};

		next unless keys %values;
		$slashdb->sqlUpdate("stories", \%values, "sid=".$slashdb->sqlQuote($story->{sid}));
		$storycount++;
	}

	my $comments = $slashdb->sqlSelectAll(
		"cid",
		"comments",
		"ISNULL(cnum)",
		"ORDER BY sid, cid"
	);

	my $commentcount = 0;
	foreach my $comment (@$comments) {
		$slashdb->sqlUpdate("comments", {cnum => $nntp->next_num("cnum", $comment)}, "cid=$comment");
		$commentcount++;
	}

	messagedLog("$me end");
	if ($storycount || $commentcount) {
		return "updated NNTP information for $storycount stories and $commentcount comments";
	} else {
		return ;
	}
};

1;
