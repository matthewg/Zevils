#!/usr/bin/perl

sub BEGIN {
        require File::Basename;
        my $self = $ENV{SCRIPT_FILENAME} || $0;
        push @INC, File::Basename::dirname($self);                
        push @INC, File::Basenane::dirname("$self/..");
}

my $r = Apache->request unless $ENV{SLASH_UID};

use DBI;
use strict 'vars';
use Slash;

sub main
{
        $dbh||=sqlconnect();
        my ($FORM, $USER)=getSlash($r);
	my ($section,$op,$seclev,$aid)=($$FORM{section},$$FORM{op},$$USER{aseclev},$$USER{aid});
	$section="admin" if $seclev > 100;
 	header("$sitename Submissions",$section);
	adminMenu($USER) if $seclev > 100;

        if($op eq "list" and $seclev > 99) {
                titlebar("99%","Submissions Admin");
                submissioned($FORM,$USER);                           
	} elsif($op eq "Update" and $seclev > 99) {
		titlebar("99%","Deleting $$FORM{subid}");
		rmSub($FORM);
		submissioned($FORM,$USER);
	} elsif($op eq "GenQuickies" and $seclev > 99) {
		titlebar("99%","Quickies Generated");
		genQuickies($FORM);
		submissioned($FORM,$USER);
	} elsif(not defined $op) {
	    	titlebar("99%","$sitename Submissions","c");
	     	displayForm($$USER{nickname},$$USER{fakeemail},$$FORM{section});	    
	} elsif($op eq "viewsub" and $seclev > 99) {
		previewForm($aid,$$FORM{subid});
	} elsif($op eq "SubmitStory") {
		titlebar("99%","Saving");
		saveSub($FORM);
	} else {
		print "Huh?";
		foreach (keys %$USER) { print "$_ = $$USER{$_}<BR>" }
	}
        currentAdminUsers($USER) if $$USER{aseclev} > 0;

	footer();

}



sub previewForm
{
	my($aid,$subid)=@_;

	my($writestatus)=getvars("defaultwritestatus");
   	my($subid, $email, $name, $title, $tid, $introtext)=
        	sqlSelect("subid,email,name,subj,tid,story",
                                    "submissions","subid='$subid'");        

        $introtext=~s/\n\n/\n<P>/gi;
	$introtext=$introtext." ";
        $introtext=~s/(?!"|=)(.|\n|^)(http|ftp|gopher|telnet):\/\/(.*?)(\W\s)?[\s]/ <A href="$2:\/\/$3"> link <\/A> /gi;
        $introtext="<I>\"$introtext\"</I>" if $name;

	if($email) {
		$_=$email;
        	if(/@/) { $email="mailto:$email"; 
		} elsif(!/http/) { $email="http://$email"; }
	        $introtext="<A href=\"$email\">$name</A> writes $introtext" if $name;
	} else {
		$introtext="$name writes $introtext" if $name;
	}

        print "<P><B>$name <A href=$email>$email</A></B>
        <P>$introtext<P>
        [ <A href=$ENV{SCRIPT_NAME}?op=Update;subid=$subid>Delete Submission</A> ]<BR>
                        
	<FORM action=$rootdir/admin.pl method=POST>
        <BR>title ",                                                                                   $query->textfield(-name=>title,-default=>$title,-size=>50),
                "\n<BR>dept ",                                                                                  $query->textfield(-name=>dept, -default=>'', -size=>50),
                "<BR>";
	selectTopic("tid",$tid);
	selectSection("section","articles");
        print "<INPUT type=submit name=op value=preview><BR>
        <BR>Intro Copy<BR>
        <TEXTAREA name=introtext cols=60 rows=10>$introtext</TEXTAREA><BR>
        <INPUT type=submit name=op value=preview><BR>";
	print "</FORM>";



}


sub rmSub
{
	my($FORM)=@_;
	$dbh->do("DELETE from submissions where  subid=".$dbh->quote($$FORM{subid}));
				
	delete $$FORM{op};
	delete $$FORM{subid};
	delete $$FORM{mode};
	delete $$FORM{threshold};
		
	foreach my $key (keys %$FORM) {
		my ($t,$n)=split("_",$key);
		if($t eq "note") {
			if($$FORM{$key}) {
				  print "$n " if
				  $dbh->do("UPDATE submissions
					set note='$$FORM{$key}'
					WHERE subid='$n'") 
			}
		} else {
			print "$key " if
			$dbh->do("DELETE from submissions
				WHERE subid='$key'");
		}
	}
}

sub genQuickies
{
	my ($FORM)=@_;
	my ($stuff)=sqlSelect("story","submissions",
		"subid='quickies'");
	$dbh->do("DELETE FROM submissions WHERE subid='quickies'");
	my $c=$dbh->prepare("SELECT subid,subj,email,name,story
			 FROM submissions
		        WHERE note='Quik'");
	$c->execute();
	while(my ($subid, $subj, $email, 
		$name, $story)=$c->fetchrow()) {
		$stuff.="\n<P><A href=\"mailto:$email\">$name</A> writes\n$story ";
	}

	$stuff=~s/'/''/g;
	my $strSQL="INSERT into submissions
		(subid,subj,email,name,time,story)
		VALUES('quickies','Generated Quickies',
			'','',now(),'$stuff')";
	print "Generating Quickies: $strSQL";
	$dbh->do($strSQL);
	$c->finish();
}
	
	

sub submissioned
{
	my ($FORM,$USER)=@_;

	
	print "<FORM action=$ENV{SCRIPT_NAME} method=post>";

	my ($c)=sqlSelect("count(*)","submissions");
	print "<B>$c Total Submissions</B><BR>";
	my $c=sqlSelectMany("note,count(*)","submissions GROUP BY note");
	print "<TABLE border=0 cellspacing=0 cellspacing=3><TR>";
	print $$FORM{note}?"<TD>":"<TD bgcolor=CCCCCC><B>";
	print "<A href=$ENV{SCRIPT_NAME}?op=list;section=$$FORM{section}>Unclassified</A> ";
	print $$FORM{note}?"</TD>":"</B></TD>";
	while(my ($note,$cnt)=$c->fetchrow()) {
		print $$FORM{note} eq $note?"<TD bgcolor=CCCCCC><B>":"<TD>";
		print "<A href=$ENV{SCRIPT_NAME}?op=list;section=$$FORM{section};note=$note>$note</A> ($cnt) ";
		print $$FORM{note} eq $note?"</B></TD>":"</TD>";
	}
	$c->finish();
	if(!$$USER{asection}) {
		print "<TD> | </TD>";
		print $$FORM{section}?"<TD>":"<TD bgcolor=CCCCCC><B>";
		print "<A href=$ENV{SCRIPT_NAME}?op=list;note=$$FORM{note}>All Sections</A> ";
		print $$FORM{section}?"</TD>":"</B></TD>";
		my $c=sqlSelectMany("section, count(*)","submissions
			GROUP BY section");
		while(my ($section, $cnt)=$c->fetchrow()) {
			print $section eq $$FORM{section}?"<TD bgcolor=CCCCCC><B>":"<TD>";
			print "<A href=$ENV{SCRIPT_NAME}?op=list;section=$section;note=$$FORM{note}>$section</A> ($cnt) ";
			print $section eq $$FORM{section}?"</B></TD>":"</TD>";
		}
		$c->finish();
	}
	print "</TR></TABLE>";

	my $sql="SELECT subid, subj, date_format(time,\"m/d  H:i\"),
			tid,note,email,name,section
		  FROM submissions ";
	$sql.="  WHERE ";
	$sql.=$$FORM{note}?"note=".$dbh->quote($$FORM{note}):"isnull(note)";
	$sql.="		and tid='$$FORM{tid}' " if $$FORM{tid};
	$sql.="         and section='$$USER{asection}' " if $$USER{asection};
	$sql.="         and section='$$FORM{section}' " if $$FORM{section};
	$sql.="	  ORDER BY time";
#	print $sql;
	my $cursor=$dbh->prepare($sql);
	$cursor->execute;
	my ($bgcolor);
	print "<TABLE width=95\% cellpadding=0 cellspacing=0 border=0>";
	while(my ($subid, $subj, $time,$tid,$note,$email,$name,$section)=$cursor->fetchrow) {
          	if($bgcolor eq "") {
                        $bgcolor="\#cccccc";
                } else { $bgcolor=""; }   
		print "<TR bgcolor=$bgcolor><TD>$time</TD>
			<TD>
			<SELECT name=note_$subid>
				<OPTION>$note
				<OPTION>Nope
				<OPTION>Wait
				<OPTION>Old!
				<OPTION>Post
				<OPTION>Quik</A>
			</SELECT>
			<INPUT type=checkbox name=$subid>\&nbsp;</TD><TD>
			<A
	href=$ENV{SCRIPT_NAME}?op=viewsub;subid=$subid>".substr($subj,0,40)."&nbsp;</A></TD>
			<TD><FONT size=2>
			(<A 
			href=$ENV{SCRIPT_NAME}?op=Update;subid=$subid>delete!</a>)<BR>
			(<A href=$ENV{SCRIPT_NAME}?op=list;tid=$tid>$tid</A>)<BR>";
		print " (<A href=$ENV{SCRIPT_NAME}?section=$section;op=list>$section</A>)"
			unless $$USER{asection};	
		print "	</FONT></TD><TD><FONT size=2>
			".substr($name,0,30)."<BR>
			".substr($email,0,30)."</FONT>
			<TD></TR>";
				
		}
	
	print "</TABLE><P><INPUT type=submit name=op value=\"Update\">
		  <INPUT type=submit name=op value=\"GenQuickies\"> 
	</FORM>";
	$cursor->finish;
}	

sub displayForm
{
	my($user,$fakeemail,$section)=@_;
	$section="articles" unless $section;
    	print "<FORM action=$ENV{SCRIPT_NAME} method=post>";
	print getblock("submit_before");
	print "	<P><FONT color=006666><B>Your Name</B></FONT><BR>
		<INPUT type=text name=from value=\"$user\" size=50>

		<P><FONT color=006666><B>Your Email or Homepage</B></FONT><BR>
		<INPUT type=text name=email value=\"$fakeemail\" size=50><BR>
		<FONT size=2>(Leave these blank if you want to 
			be anonymous)</FONT><BR>

		<P><FONT color=006666><B>Subject</B>  (descriptive!  clear!  simple!)</FONT><BR>
		<INPUT type=text name=subj value=\"\" size=50><BR>
		<FONT size=2>(bad subjects='Check This Out!' or 'An Article'.  We get 
		hundreds of submissions each day, if yours isn't clear, it'll
		be deleted!)</FONT>
		<P><FONT color=006666><B>Please select the closest topic and section</B></FONT><BR>
	";
	selectTopic("tid","news");
	selectSection("section",$section);
	print "<BR><FONT size=2>(Almost everything should go under Articles)</FONT>";
	print "<P><FONT color=006666><B>The Scoop  (HTML is fine, but double check
			those URLS and Tags!)</B></FONT><BR>
		<TEXTAREA wrap=virtual cols=50 rows=12 name=story></TEXTAREA><BR>
		<FONT size=2>(Are you sure you included a URL?)</FONT>
		";
	print "
		<P><INPUT type=submit name=op value=\"SubmitStory\">
		</FORM>
		<P> <P>
	";
}

sub saveSub
{
	my($FORM)=@_;
	if(length $$FORM{subj} < 2) {
		print "Please enter a reasonable subject.";
	} else {
	  print "Perhaps you would like to enter an
		email address or a URL next time.<BR>" 
				unless length $$FORM{email} > 2;
				
	  print "This story has been submittedly anonymously<BR>"						  unless length $$FORM{from} > 2;
		
	  print getblock("submit_after");
          my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
                                            localtime(time);
          $mon++;
	  $year += 1900;
          my $subid="$hour$min$sec.$mon$mday$year";               
	  $$FORM{story}=~s/'/''/g;
	  $$FORM{subj}=~s/'/''/g;
	
	  $dbh->do("INSERT into submissions
		(email,name,story,time,subid,subj,tid,section)
		VALUES('$$FORM{email}','$$FORM{from}',
		  '$$FORM{story}', NOW(),'$subid','$$FORM{subj}','$$FORM{tid}',
		  '$$FORM{section}')");
	  }
}


main;
$dbh->disconnect() if $dbh;
1;
