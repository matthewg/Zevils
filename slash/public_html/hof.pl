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
        my($FORM,$USER)=getSlash($r);
        my $SECT=getSection($$FORM{section});

        header("$sitename:Hall of Fame",$$SECT{section},$$FORM{mode},$$FORM{ssi});              

	my $storyDisp=sub { "<B><FONT size=4>$_[3]</FONT></B>
                        <A href=$rootdir/$_[2]/$_[0]".".shtml>$_[1]</A>  by $_[4]<BR>" };  

	# Top 10 Hit Generating Articles
	titlebar("98%","Most Active Stories");
	displayCursor($storyDisp,sqlSelectMany("sid,title,section,commentcount,aid",
						"stories","",
						"ORDER BY commentcount DESC LIMIT 10"));

	print "<P>";
	titlebar("98%","Most Visited Stories");
	displayCursor($storyDisp,sqlSelectMany("sid,title,section,hits,aid",
						"stories","",
						"ORDER BY hits DESC LIMIT 10"));
	
	print "<P>";	
	titlebar("98%","Most Active Authors");
	displayCursor(sub{"<B>$_[0]</B> <A href=$_[2]>$_[1]</A><BR>"},
			sqlSelectMany("count(*) as c, stories.aid, email", "stories, authors",
				"authors.aid=stories.aid", "GROUP BY aid ORDER BY c DESC LIMIT 10"));
		
	print "<P>";	
	titlebar("98%","Most Active Poll Topics");
	displayCursor(sub{"<B>$_[0]</B> <A href=$rootdir/pollBooth.pl?qid=$_[2]>$_[1]</A><BR>"},
		sqlSelectMany("voters,question,qid",
			    "pollquestions","1=1",
			    "ORDER by voters DESC LIMIT 10"));
	


	print "<BR><FONT size=2><CENTER>generated on ".localtime()."</CENTER></FONT><BR>";

	writelog("hof");
	footer($$FORM{ssi});
}


sub displayCursor
{
	my ($d,$c)=@_;
	return unless $c;
	while(@_=$c->fetchrow) {
		print $d->(@_);
	}
	$c->finish();
}


main;
$dbh->disconnect() if $dbh;
