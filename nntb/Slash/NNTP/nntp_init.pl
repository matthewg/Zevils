#!/usr/bin/perl

use strict;
use warnings;
use Slash;

# This has a race condition - could it be made atomic?
sub nextSnum($;$) {
	my($db, $section) = @_;

	if(!$section) {
		my $snum = $db->getVar("nntp_next_snum", "value");
		$db->setVar("nntp_next_snum", $snum + 1);
		return $snum;
	} else {
		my($snum) = $db->sqlSelectAll("next_snum", "nntp_sectiondata", "section=$section");
		return undef unless $snum;
		$db->sqlUpdate("nntp_sectiondata", {next_snum => $snum + 1}, "section=$section");
		return $snum;
	}
}


my $virtuser = shift or die "Usage: $0 virtual-user\n";
createEnvironment($virtuser);

my $db = getCurrentDB();
my $nntp = getObject("Slash::NNTP") or die "Couldn't get Slash::NNTP - is the NNTP plugin installed?\n";

my $stories = $db->sqlSelectAllHashref(
	"sid",
	"sid, sections.id AS section, displaystatus",
	"sections, stories",
	"sections.section = stories.section AND displaystatus != -1"
);

my $storynum = 0;
my %sectionnums;

foreach my $story (values %stories) {
	# This creates a race condition - could it be made atomic?
	my $section_snum = nextSnum($db, $story->{section});

	my %values = (
		sid => $story->{sid},
		section_snum => $section_snum
	);
	$values{snum} = $nntp->nextSnum() if $story->displaystatus == 0;

	$db->sqlInsert("nntp_storynums", \%values);
}

$db->setVar("nntp_initialized", 1);

print "NNTP initialized!\n";
