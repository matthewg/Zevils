#!/usr/bin/perl
my $r = Apache->request unless $ENV{SLASH_UID};

require File::Basename;
my $self = $ENV{SCRIPT_FILENAME} || $0;
push @INC, File::Basename::dirname($self);                
push @INC, File::Basename::dirname($self) . "/..";

use DBI;
use lib '/home/slash';
use strict;   
use Slash;

sub main
{
        $dbh ||= sqlConnect();
        my($FORM,$USER)=getSlash($r);

	header("$sitename Poll",$$FORM{section},$$FORM{mode},$$FORM{ssi});

	if($$USER{aseclev} > 99) { 
		adminMenu($USER);
		print "<FONT size=2>[ <A href=$ENV{SCRIPT_NAME}?op=edit>New Poll</A> ]";
	}
	my $op=$$FORM{op};
	if($$USER{aseclev} > 99 and $op eq "edit") {
		editpoll($$FORM{qid});
	} elsif($$USER{aseclev} > 99 and $op eq "save") {
		savepoll($FORM);
	} elsif(not defined $$FORM{qid} ) {
		listpolls($$USER{aseclev},$$FORM{min});
	} elsif(not defined $$FORM{aid}) {
		print "<CENTER><P>";
	 	pollbooth($$FORM{qid});
		print "</CENTER>";
	} else {
		vote($$FORM{qid},$$FORM{aid}, $USER);
		if(not getvar("nocomment") ) {
		   print "<P>[ <A href=\"$rootdir/comments.pl?op=post;sid=$$FORM{qid};pid=0\"><B>Post a Comment About this Poll</B></A> ]<P>";
		   titlebar("99%","Comments");
                   printComments2($USER,$$FORM{qid});

		}
	}	
	writelog("pollbooth",$$FORM{qid});
	footer();

}

sub editpoll
{
	my ($qid)=@_;
	# Display a form for the Question
	my ($question, $voters)=sqlSelect("question, voters","pollquestions",
							"qid='$qid'");
	if(not defined $voters) { $voters=0; }
	print "<FORM action=$ENV{SCRIPT_NAME} method=post>
		<B>id</B> (if this mataches a story's ID, it will apear with the story,
				else just pick a unique string)
		<BR>
		<INPUT type=text name=qid value=\"$qid\" size=20>";

	my ($currentqid)=getvar("currentqid");
	print "<INPUT type=checkbox name=currentqid ";	
	if($currentqid eq $qid) {
		print "CHECKED";
	}
	print "> (appears on homepage)\n";

	print "<BR>
		<B>The Question</B> (followed by the total number of voters so far)<BR>
		<INPUT type=text name=question value=\"$question\" size=40>
		<INPUT type=text name=voters value=$voters size=5>
		<BR><B>The Answers</B> (voters)<BR>
		";


	my $c=$dbh->prepare("SELECT answer,votes FROM pollanswers
				WHERE qid='$qid'
				ORDER BY aid");
	$c->execute();
	my $x=0;
	while(my ($answers, $votes)=$c->fetchrow) {
		$x++;
		print "<INPUT type=text name=aid$x value=\"$answers\" size=40>
			<INPUT type=text name=votes$x value=$votes size=5><BR>";
	}
	$c->finish();
	while($x < 8) {
		$x++;
		print "<INPUT type=text name=aid$x value=\"\" size=40>
			<INPUT type=text name=votes$x value=0 size=5><BR>";
	}
	print "<INPUT type=submit value=Save>
		<INPUT type=hidden name=op value=save>
		</FORM>";

}

sub savepoll
{
	my ($FORM)=@_;
	return unless $$FORM{qid};
	print $$FORM{qid};
	# Check if QID exists, and either update/insert

	sqlInsert("pollquestions",qid=>$$FORM{qid},question=>$$FORM{question},voters=>0,
		-date=>'now()');
	sqlUpdate("pollquestions","qid=".$dbh->quote($$FORM{qid}),(question=>$$FORM{question},voters=>$$FORM{voters}));
			
	if(defined $$FORM{currentqid}) { 
		setvar("currentqid",$$FORM{qid});
		print "$$FORM{qid} is now on homepage<BR>\n";
	}

	# Loop through 1..8 and insert/update if defined
	for(my $x=1;$x<9;$x++) {
		# If aid$x defined,
		my ($thisaid,$thisvotes)=("aid$x","votes$x");
		print "<BR>Answer $x=$$FORM{$thisaid} $$FORM{$thisvotes} $$FORM{qid} ";
		if($$FORM{$thisaid}) {
			print "In";
			my %h=(aid=>$x, answer=>$$FORM{$thisaid},
				votes=>$$FORM{$thisvotes},qid=>$$FORM{qid});
			sqlInsert("pollanswers",%h);
			sqlUpdate("pollanswers","aid=$x and qid=".$dbh->quote($$FORM{qid}),%h);
		} else { 
			print "Out";
			$dbh->do("DELETE from pollanswers WHERE 
				qid='$$FORM{qid}' and aid=$x"); 
		}
	}
}


sub vote
{
	my ($qid, $aid, $USER) =@_;
	my ($notes)="Displaying poll results $aid";
	if($aid>0) {
		my ($id)=sqlSelect("id","pollvoters",
			"qid=".$dbh->quote($qid)." AND 
			 id=".$dbh->quote($ENV{REMOTE_ADDR})." AND
			 uid=".$dbh->quote($$USER{uid}));
		if ($id) {
			$notes=$$USER{nickname}." at ".$ENV{REMOTE_ADDR}." has already voted.";
		} else {
			$notes="Your vote ($aid) has been registered.";
			sqlInsert("pollvoters",qid=>$qid, id=>$ENV{REMOTE_ADDR}, 
				time=>"now()", uid=>$$USER{uid});
			$dbh->do("update pollquestions set voters=voters+1 where qid=".
				$dbh->quote($qid));
			$dbh->do("update pollanswers set votes=votes+1 where 
				qid=".$dbh->quote($qid)." and aid=".$dbh->quote($aid));
		}
	} 

	my ($totalvotes,$question)=sqlSelect("voters,question","pollquestions",
						"qid='$qid'");
	my ($maxvotes)=sqlSelect("max(votes)","pollanswers","qid='$qid'");
	print "<CENTER>";
	titlebar("99%","$question");
	print "<TABLE border=0 cellpadding=2 cellspacing=0 width=500>
		<TR>
		 <TD> </TD><TD colspan=1>$notes</TD>
		</TR>";

	
		
	my $a=$dbh->prepare("SELECT answer, votes from pollanswers
				where qid='$qid' ORDER by aid");
	$a->execute;
	while(my ($answer, $votes)=$a->fetchrow) {
		my ($imagewidth,$percent);
		$imagewidth=int (350*$votes/($maxvotes)) +1;
		$percent=int (100*$votes/($totalvotes));
		pollItem($answer, $imagewidth, $votes, $percent);
	}
	$a->finish();
	print "	<TR>
		 <TD colspan=2 align=right>
		  <FONT size=4><B>$totalvotes total votes.
		  </B></FONT>
		 </TD>
		</TR><TR>
		 <TD colspan=2><P>
		  <CENTER>
		   [ <A href=$ENV{SCRIPT_NAME}?qid=$qid>Voting Booth</A>
		   | <A href=$ENV{SCRIPT_NAME}>Other Polls</A>
		   | <A href=$rootdir/>Back Home</A> ]
		 </TD>
		</TR><TR>
		 <TD colspan=2>";
	print getblock("postvote");
		
	print "</TABLE>";
}




sub listpolls
{
	my ($seclev,$min)=@_;


        my $cursor = $dbh->prepare("
                select qid, question, date_format(date,\"W M D\")  from
pollquestions order by date DESC
                ");
        $cursor->execute; 
        my ($question, $qid,$date);
	titlebar("99%","$sitename Polls");
	my $thisid;
	while($thisid++ < $min) { $cursor->fetchrow(); }
        while (($qid, $question,$date) = $cursor->fetchrow and ($min+20) > $thisid++) {
                print "<BR><LI><A href=pollBooth.pl?qid=$qid>$question</A>
		$date ";
		if($seclev >= 100) {
			print "(<A href=$ENV{SCRIPT_NAME}?op=edit;qid=$qid>Edit</A>)";
		}
        }
	$cursor->execute();
	print "<P><FONT size=4><B><A href=pollBooth.pl?min=$thisid>More Polls</A></B></FONT>" 
		unless not $cursor->fetchrow();

	$cursor->finish;
}


main;
$dbh->disconnect() if $dbh;
1;
