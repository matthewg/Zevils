#!/usr/bin/perl


my $r = Apache->request if $ENV{SCRIPT_NAME};

use DBI;
use FindBin qw($Bin);
use lib "$Bin/..";
use strict;   
use Slash;


sub main
{
        $dbh ||= sqlConnect();
	my ($FORM,$USER)=getSlash($r);
	my $SECT=getSection($$FORM{section});
	
	# Decide Upon Title
	my $title="$sitename:$slogan";
	$title="$sitename:$$SECT{title}" if $$SECT{title};
        $title=$$SECT{title} if $$SECT{isolate};

	$$SECT{artcount}||=30;
	$$SECT{mainsize}=int($$SECT{artcount} / 3);
	$$SECT{issue}||=3; # Default to issue/art mode.

	# pseudo section template:-------------------------
	#header($title,$$SECT{section},$$FORM{mode},$$FORM{ssi});
		
  	my $pagetitle=$title;
        my $block=blockCache($$SECT{section}."_index") || blockCache("index");
        my $execme=prepEvalBlock($block);
        print eval $execme;
        if($@) { print "\nError:$@\n" }



	# Get some stories and display them
	#my $stories=selectStories($SECT,$FORM,$USER);
	#displayStories($USER,$$SECT{mainsize},$FORM,$stories);
	
	# Make a new column
	#print "</TD><TD width=210 align=center valign=top>";
	
	# And fill it with stuff
	#displayStandardBlocks($SECT,$FORM,$USER,$stories); # Obsolete
	#$stories->finish() if $stories;
	#footer($$FORM{ssi});
	# End of the template------------------------------

	writelog($$FORM{section}) unless $$FORM{ssi};
}


sub displayStandardBlocks
{
	my($SECT,$FORM,$USER,$olderStuff)=@_;

	my $getblocks=$$SECT{section};
	$getblocks||="index";
		 
	# Display Blocks
	my $strsql="SELECT block,title 
                   FROM blocks,sectionblocks
	  	  WHERE section='$getblocks' 
		    AND blocks.bid=sectionblocks.bid 
 		  ORDER BY ordernum";
	my $c=$dbh->prepare($strsql);
	$c->execute();

	# Get the first Block In there
	if(my ($block,$title)=$c->fetchrow()) {
		fancybox(200,$title,$block);
	}

	pollbooth($$SECT{qid}) if $$SECT{qid} or !$$FORM{section};
	fancybox(200,"Older Stuff",
		getOlderStories($SECT,$FORM,$USER,$olderStuff),
		"nc") if $olderStuff;
	$olderStuff->finish() if $olderStuff;

	# Print out the rest of the sections blocks
	$c->execute();
	while(my ($block,$title)=$c->fetchrow()) {
		fancybox(200,$title,$block,"nc");
	}
	$c->finish();
}


main;
$dbh->disconnect() if $dbh;
