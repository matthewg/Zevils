#!/usr/bin/perl

my $r = Apache->request if $ENV{SCRIPT_NAME};

sub BEGIN {
        require File::Basename;
        my $self = $ENV{SCRIPT_FILENAME} || $0;
        push @INC, File::Basename::dirname($self);                
        push @INC, File::Basename::dirname("$self/..");
}

use strict;
use Slash;

sub main
{
 	$dbh ||= sqlConnect();
	die unless $dbh;
	my($FORM,$USER)=getSlash($r);

	if($$FORM{refresh}) {
		sqlUpdate("stories","sid=".$dbh->quote($$FORM{sid})." and writestatus=0",(writestatus=>1));
		print "<FONT color=white size=5>How Refreshing! ($$FORM{sid}) </FONT>";
	}

	my $S=sqlSelectHashref("*","stories","sid=".$dbh->quote($$FORM{sid}));
	my $SECT=getSection($$S{section});

	my $title=$sitename.":".$$S{title};
	$title=$$SECT{title}.":".$$S{title} if $$SECT{isolate};

	# This area needs to be templatified like index.pl
	# it is very much a work in progress :)
        header($title,$$S{section},$$FORM{mode},$$FORM{ssi});

	my ($S,$A,$T)=displayStory($USER,$$FORM{sid},"Full");
	articleMenu($S,$FORM,$SECT);
	print "</TD><TD valign=top bgcolor=FFFFFF>";

	# Poll Booth
	my ($poll)=sqlSelect("qid","pollquestions","qid='$$S{sid}'");
	pollbooth($$FORM{sid}) if $poll;

	# Related Links
	my $related=getRelated("$$S{title} $$S{bodytext} $$S{introtext}");
	$related.="<LI><A href=\"$rootdir/search.pl?topic=$$S{tid}\"> More on $$T{alttext} </A> 
		   <LI><A href=\"$rootdir/search.pl?author=$$S{aid}\"> Also by $$S{aid} </A>\n";
	fancybox(200,"Related Links", $related,"nc");

	# First block from sectionblocks
	if(my ($block,$title)=sqlSelect("block,title","blocks,sectionblocks",
			"section='$$S{section}' AND blocks.bid=sectionblocks.bid")) {
                fancybox(200,$title,$block,"nc");
        }
	if($$USER{seclev} > 0 or $$USER{aseclev} > 99) {
		my $u=$$USER{aid};
		$u||=$$USER{nickname};
		my $m.="<P>I probably should put some buttons here to
			allow administrators to do stuff here, but I haven't really
			thought of much beyond linking back to
			<A href=$rootdir/admin.pl>Admin</A> and to this page's
			<A href=$rootdir/admin.pl?op=edit;sid=$$S{sid}>Editor</A>"
			if $$USER{aseclev} > 99 and $$USER{aid};
		
		fancybox(200, $u,"<A href=$rootdir/users.pl?op=userinfo>You</A> have 
			<B>$$USER{points}</B> points with which
 			to moderate.  By clicking the left or right radio button, you
 			will demote or promote it.  When you're done, click the moderate
			button at the bottom of the page.\n$m");


	}

	print "</TD></TR><TR><TD colspan=3>";


	if(not getvar("nocomment") and $$S{commentstatus} > -1) {
		my ($cc)=sqlSelect("count(*)","comments","sid='$$FORM{sid}'");

		if($$FORM{mode} eq "irclog") {
			ircLog($$S{sid});
		} elsif($cc < 100 or $$FORM{mode} eq "flat" or $$FORM{mode} eq "archive") {
                	printComments2($USER,$$FORM{sid},0,0);
		} else {
			print "Over 100 comments:Printing out Index Only";	
			$$USER{mode}="index";
			printComments2($USER,$$FORM{sid},0,0);
		}
	}
	print "</TD></TR>\n";

        writelog("article",$$FORM{sid}) unless $$FORM{ssi};
        footer($$FORM{ssi});
}

sub articleMenu
{
	my($story,$FORM,$SECT)=@_;
	print " &lt;&nbsp; ",nextStory("<",$story,$FORM,$SECT);
	print " | ", nextStory(">",$story,$FORM,$SECT)," &nbsp;&gt; <P>&nbsp;";
} 



sub getRelated
{
	($_)=@_;
	my %related=getLinkList();
	my $r;
        foreach my $key (keys %related) {
		if(defined $related{$key} and /\W$key\W/i) {
			my ($t,$u)=split(";",$related{$key});
			$t=~ s/(\S{20})/$1 /g;
			$r.="<LI><A HREF=$u>$t</A>\n";
		}
	}

	# And slurp in all the URLs just for good measure
	while(/\<A(.*?)\>(.*?)<\/A\>/sgi) {
		my ($u,$t)=($1,$2);
		$t=~s/(\S{30})/$1 /g;
		$r.="<LI><A$u>$t</A>\n";
	}
	return $r;
}


sub nextStory
{
	my ($sign,$story,$FORM,$SECT)=@_;

	my $order="ASC";
	$order="DESC" if $sign eq "<";

	my $where;
	if($$SECT{isolate}) {
		$where="and section=".$dbh->quote($$story{section}) if $$SECT{isolate}==1;
	} else {
		$where="and displaystatus=0";
	}
	if(my ($title,$psid,$section)=sqlSelect("title, sid, section","stories",
		"time $sign '$$story{sqltime}' and writestatus >= 0 $where",
		"ORDER BY time $order LIMIT 1")) {
		return linkStory($title,$$FORM{mode},$psid,$section);
	}
	return "";
}


sub getLinkList
{
	# Ok, this could be a table, but for now...
	my %related=(
		intel	=>"Intel;http://www.intel.com",
		linux	=>"Linux;http://www.linux.org",
		lycos	=>"Lycos;http://www.lycos.com",
		redhat	=>"Red Hat;http://www.redhat.com",
		'red hat'=>"Red Hat;http://www.redhat.com",
		wired	=>"Wired;http://www.wired.com",
		netscape=>"Netscape;http://www.netscape.com",
		slashdot=>"Slashdot;http://slashdot.org",
		malda	=>"Rob Malda;http://slashdot.org/malda",
		apple	=>"Apple;http://www.apple.com",
		debian	=>"Debian;http://www.debian.org",
		zdnet	=>"ZDNet;http://www.zdnet.com",
		'news.com'=>"News.com;http://www.news.com",
		cnn	=>"CNN;http://www.cnn.com");

	return %related;

}

main;
$dbh->disconnect() if $dbh;
1;
