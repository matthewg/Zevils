#!/usr/bin/perl

sub BEGIN {
        require File::Basename;
        my $self = $ENV{SCRIPT_FILENAME} || $0;
        push @INC, File::Basename::dirname($self);                
        push @INC, File::Basename::dirname("$self/..");
}

my $r = Apache->request if $ENV{SCRIPT_NAME};

use DBI;
use strict;
use Slash;

sub main
{
        $dbh ||= sqlConnect();
        my($FORM,$USER)=getSlash($r);
        my $SECT=getSection($$FORM{section});

        header("$sitename:Topics",$$SECT{section},$$FORM{mode},$$FORM{ssi});              
	titlebar("90%","Topics");
	my $when="AND to_days(now()) - to_days(time) < 14" unless $$FORM{all};

	my $order="ORDER BY cnt DESC";
	$order="ORDER BY alttext" if $$FORM{all};
	my $c=sqlSelectMany("*, count(*) as cnt","topics,stories",
				"topics.tid=stories.tid
				 $when
				 GROUP BY topics.tid
				 $order");
	my $T;
	my $col=0;
	print "[ <A href=$ENV{SCRIPT_NAME}>Recent Topics</A> |
		 <A href=$ENV{SCRIPT_NAME}?all=on>All Topics</A> ]";
	print "<TABLE width=90% border=0 cellpadding=3>";
	while ($T=$c->fetchrow_hashref()) {
		print "<TR><TD align=right valign=top>";
		print "<FONT size=6 color=006666>$$T{alttext}</FONT><BR>";
		print "<A href=$rootdir/search.pl?topic=$$T{tid}><IMG 
			SRC=\"$imagedir/topics/$$T{image}\"
                        BORDER=0 ALT=\"$$T{alttext}\"  ALIGN=right
                        HSPACE=0 VSPACE=10 WIDTH=$$T{width} HEIGHT=$$T{height}></A>";
		print "</TD><TD bgcolor=CCCCCC valign=top>";
		my $limit=$$T{cnt};
		$limit=10 if $limit > 10;
		$limit=3 if $limit < 3 or $$FORM{all};
   		my $stories=selectStories($SECT,$FORM,$USER,$limit,$$T{tid});    
                print getOlderStories($SECT,$FORM,$USER,$stories);
		$stories->finish();
		print "</TD></TR>";
	} 
	print "</TABLE>";
	$c->finish();

        print "<BR><FONT size=2><CENTER>generated on ".localtime()."</CENTER></FONT><BR>";

	writelog("topics");
	footer($$FORM{ssi});
}

main;
$dbh->disconnect() if $dbh;
