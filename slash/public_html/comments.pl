#!/usr/bin/perl

my $r = Apache->request unless $ENV{SLASH_UID};

use FindBin qw($Bin);
use lib "$Bin/..";
use strict;   
use DBI;
use Slash;

sub main
{
        $dbh||=sqlConnect();
	my ($FORM,$USER)=getSlash($r);

	# Seek Section for Appropriate L&F
	my ($s,$title)=sqlSelect("section,title","stories","sid=".$dbh->quote($$FORM{sid}));
	my $SECT=getSection($s);
	$$FORM{pid}||="0";
	$title||="Comments";
	
	header("$$SECT{title}:$title",$$SECT{section});

	if($$USER{uid} < 1 and length($$FORM{upasswd}) > 1) {
		print "<P><B>Login for \"$$FORM{unickname}\" has failed</B>.  
			Please try again. $$FORM{op}<BR><P>";
		$$FORM{mode}="Preview";
	}

	if($$FORM{mode} eq "Submit" ) {
		submitComment($FORM,$USER);
	} elsif($$FORM{mode} eq "Edit" or $$FORM{op} eq "post" or $$FORM{mode} eq "Preview") {
		editComment($FORM,$USER);
  	} elsif($$FORM{op} eq "delete" and $$USER{aseclev}) {
                titlebar("99%","Delete $$FORM{cid}");
                my $delCount=deleteThread($$FORM{sid},$$FORM{cid});
                $dbh->do("UPDATE stories SET
                        commentcount=commentcount-$delCount,writestatus=1
                        WHERE sid=".$dbh->quote($$FORM{sid}));
                print "Deleted $delCount items from story $$FORM{sid}\n";
        } elsif($$FORM{op} eq "moderate") {
                titlebar("99%","Moderating $$FORM{sid}");
                moderate($FORM,$USER);   
	} elsif($$FORM{cid}) {
		#print "$$USER{mode} $$USER{threshold} $$FORM{threshold} $$FORM{mode}";
        	printComments2($USER,$$FORM{sid},$$FORM{cid},$$FORM{cid});
	} elsif($$FORM{sid}) {

		# print "$$USER{mode} $$USER{threshold} $$FORM{threshold} $$FORM{mode} $currentMode";
        	printComments2($USER,$$FORM{sid},$$FORM{pid});
	} else {
		print "Huh?";
	}
	writelog("comments",$$FORM{sid}, $$FORM{op});

	footer();
}

sub editComment
{
	my($FORM,$USER)=@_;
	my $reply=sqlSelectHashref("date_format(date,\"W M d, \@h:i\") as time,
		subject,comment,realname,nickname,fakeemail,homepage,users.uid as uid",
		"comments,users",
		"sid=".$dbh->quote($$FORM{sid})."
		  AND cid=".$dbh->quote($$FORM{pid})."
		  AND users.uid=comments.uid");

	$$FORM{postersubj}||=$$reply{subject};

	# Display parent comment if we got one
	if($$FORM{pid}) {
		titlebar("95%", " $$reply{subject}");
		print "<TABLE border=0 cellpadding=0 cellspacing=0 width=95% align=center>"; 
		dispComment($USER,$reply);
		print "</TABLE><P>";
	}
	
	if($$FORM{mode} eq "Preview") {
		titlebar("95%","Preview Comment"); 
		previewForm($FORM,$USER);
		print "<P>\n";
	}

       	titlebar("95%","Post Comment");
	print "\n<FORM
	    action=\"$ENV{SCRIPT_NAME}\" 
            method=post>\n";
	print "<input type=hidden name=sid value=\"$$FORM{sid}\">\n";
	print "<input type=hidden name=pid value=\"$$FORM{pid}\">\n";
	print "<table border=0 cellspacing=0 cellpadding=1>\n";
	print "<TR><TD> </TD><TD>
		You are not logged in.  You can login or <A href=\"$rootdir/users.pl\">Create
		an Account</A>. If you fill in your name and passwd as well as the Subject and 
		Comment field, you can submit a comment without requiring a cookie. If you 
		don't login, your comment will be posted as <B>$$USER{nickname}</B></TD></TR>
		
		<INPUT type=hidden name=op value=userlogin>
		<TR><TD align=right>Nick</TD><TD>
		<INPUT type=text name=unickname VALUE=\"$$FORM{unickname}\"></TD></TR>
		<TR><TD align=right>Passwd</TD><TD>
		<INPUT type=password name=upasswd></TD></TR>" if $$USER{uid} < 1;
	print "<tr><td width=130 align=right>Name</td><td
		width=500><A href=\"$rootdir/users.pl\">$$USER{nickname}</A> [";
	if($$USER{uid} > 0) {
		print " <A href=\"$rootdir/users.pl?op=userclose\">Log Out</A> ";
		} else {
		print " <A href=\"$rootdir/users.pl\">Create Account</A> ";
	}
			
	print " ] </TD></TR>\n";
	print "<tr><td align=right>Email</td>
		<td>$$USER{fakeemail}</td></tr>\n" if $$USER{fakeemail};
			
	print "<tr><td align=right>URL</td><TD><A
		href=\"$$USER{homepage}\">$$USER{homepage}</A>
		</TD></TR>\n" if $$USER{homepage};
	print "<tr><td align=right>Subject</td>";

	if($$FORM{pid} and not $$FORM{postersubj}) { 
		$$FORM{postersubj}=$$reply{subject};
		$$FORM{postersubj}=~s/Re://gi;
		$$FORM{postersubj}=~s/\s\s/ /g;
		$$FORM{postersubj}="Re:$$FORM{postersubj}";
	} 
                
                 
	print "<td>",
		$query->textfield(-name=>postersubj, -default=>$$FORM{postersubj}, 
			-size=>50, -maxlength=>50),
		"</td></tr>\n";   
	print "<tr><td align=right valign=top>Comment</td>";
	print "<td><textarea wrap=virtual name=postercomment rows=10 cols=50>";
	print $$FORM{postercomment};
	print "</textarea></td></tr>\n";
	print "<tr><td> </TD><TD>\n";

	print "<input type=submit name=mode value=\"Submit\">";
	print "<input type=submit name=mode value=\"Preview\">\n"; 

	selectGeneric("postmodes","posttype","code","name",$$USER{posttype});
	print "</td></tr><TR><TD valign=top align=right>Allowed HTML</TD><TD><FONT size=1>\n";
	foreach my $tag (getapptags) { print "&lt;$tag&gt; \n"; }
	print "</FONT></TD></TR></table>\n\n";
	print "</FORM>\n";

}

sub previewForm
{
	my($FORM,$USER)=@_;
	my $tempComment=stripByMode($$FORM{postercomment},$$FORM{posttype},$$USER{aseclev},
                        getapptags())."<BR>".$$USER{sig};

       	my $preview={nickname=>$$USER{nickname},
               homepage=>$$USER{homepage},
               fakeemail=>$$USER{fakeemail},
               time=>'now',
               subject=>
                        stripByMode($$FORM{postersubj},"nohtml",$$USER{aseclev},
                        ("B")),
               comment=>$tempComment};
         print "<TABLE border=0 cellpadding=0 cellspacing=0 width=95% align=center>\n";
	 $$USER{mode}="archive";
         dispComment($USER,$preview);       
	 print "</TABLE>\n";
}

sub submitComment
{
	my($FORM,$USER)=@_;
	titlebar("95%","Submitted Comment");

	$$FORM{postersubj}||="No Subject Given";
	$$FORM{postersubj}=stripByMode($$FORM{postersubj},
		"nohtml",$$USER{aseclev},(""));
	$$FORM{postercomment}=stripByMode($$FORM{postercomment},
		$$FORM{posttype},$$USER{aseclev},getapptags()); 

	if($$FORM{postercomment}) {  	
		my ($maxCid)=sqlSelect("max(cid)","comments",
			"sid=".$dbh->quote($$FORM{sid}));
               	$maxCid+=(int(rand 25)+1);
		$maxCid||=1;

		my ($dupRows)=sqlSelect("count(*)","comments","
			comment=".$dbh->quote($$FORM{postercomment})." 
		 	and sid=".$dbh->quote($$FORM{sid}));

		my $pts=$$USER{defaultpoints};
		$pts=0 if $$USER{uid} < 1;
		my $ident;
		if($$USER{uid} > 0) {
			$ident=$ENV{REMOTE_ADDR};
		} else {
			$ident="anonymous";
		}
		my $insline=("INSERT into comments values (
                                ".$dbh->quote($$FORM{sid})." ,$maxCid,$$FORM{pid},
                                 now(),'UNUSED','UNUSED',
                                 '$ident','',0,
                                 ".$dbh->quote($$FORM{postersubj}).",
                                 ".$dbh->quote($$FORM{postercomment}).",
                                 0,$$USER{uid},$pts,-1)");
			
		if($$FORM{pid}>$maxCid or $dupRows or $$FORM{sid} eq "") {
			print "Something is wrong: $$FORM{pid} - $maxCid - 
				$dupRows - $$FORM{sid}\n";
			print "<ul>\n";
			print "<li>Child older than Parent.\n"
				if $$FORM{pid} > $maxCid;
			print "<li>Duplicate.  Did you try to submit twice?" if $dupRows;
			print "<li>Space aliens have eaten your data."
					unless $$FORM{sid} ne "";
			print "<LI>Let us know if anything exceptionally strange
				happens\n";

		} elsif ($$FORM{postersubj} =~ /\w{80}/  or 
			 $$FORM{postercomment} =~ /\w{80}/)  {
			print "Lameness filter encountered.  Post aborted.";
		} else {
       	       		if($dbh->do($insline)) {
				print "Comment Submitted. There will be a delay before
				  the comment becomes part of the static page. What you
				  submitted appears below.  If there is a mistake, you
				  should have used the Preview button!";
				$dbh->do("update stories set 
					commentcount=commentcount+1,
					writestatus=1 where 
					sid=".$dbh->quote($$FORM{sid}));
				previewForm($FORM,$USER);

				my ($tc,$mp,$cpp)=getvars(
					"totalComments","maxPoints",
					"commentsPerPoint");
				$tc++;
				sqlUpdate("vars","name='totalcomments'",value=>$tc);

				if(!($tc % $cpp)) {
					$dbh->do("UPDATE users SET
						points=points+1
						WHERE seclev>0 and points<$mp");
				}
			} else {
				open ERROR,">>$rootdir/logs/commSubErr";
				print ERROR localtime()."$DBI::errstr $insline\n";
				close ERROR;
				print "<p>There was an unknown error in the 
					submission<br>  I think it might just be AC posting,
					so try logging in.  I'm working on it as fast as
					I can.\n\n";
			}
		}
	}
}

sub checkWords {
	my ($str,@wordList)=@_;
        foreach (@wordList) {
                if($str=~/$_/i) {
                        print "Please refrain from using joke names
                                for companies, it makes Linux users
                                look petty and childish<br>\n";
                }
        }
}


sub moderate
{
        my($FORM,$USER)=@_;
        my $totalDel=0;
        print "<ul>\n";
        # Handle Deletions, Points & Reparenting
        foreach (sort keys %$FORM) {
                if(/\Adel_(.*)/ and $$USER{aseclev}) {
                        my $delCount=deleteThread($$FORM{sid},$1);
                        $totalDel+=$delCount;
                        $dbh->do("UPDATE stories SET
                                commentcount=commentcount-$delCount,
                                writestatus=1
                                WHERE sid=".$dbh->quote($$FORM{sid}));
                        print "<li>Deleted $delCount items from story $$FORM{sid}
                                under comment $$FORM{$_}\n" if $totalDel;
                } elsif(/\Apar_(.*)/) {
                        moderateCid($$FORM{sid},$1,$USER,$$FORM{"mod_".$1},$$FORM{$_});
                }
        }
        print "</ul>\n";
        if($$USER{aseclev} and $totalDel) {
                my ($cc)=sqlSelect("count(sid)","comments",
                        "sid=".$dbh->quote($$FORM{sid}));
                sqlUpdate("stories","sid=".$dbh->quote($$FORM{sid}),(commentcount=>$cc));
                print "$totalDel comments deleted.  Comment count set to $cc<br>\n";
        }
}              


sub moderateCid
{
        my($sid,$cid,$USER,$val,$rep)=@_;
        # Check if $uid has seclev and Credits

        my $sign="+0";
        if($val eq "pos") {
                $sign="+1";
        } elsif($val eq "neg") {
                $sign="-1"
        }

        if($$USER{seclev} > 0 and $$USER{points} > 0) {
                my ($cuid,$ppid)=sqlSelect("uid,pid","comments","cid=$cid and sid='$sid'");
                if($rep eq "1") {
                        ($ppid)=sqlSelect("pid","comments",
                                "sid=".$dbh->quote($sid)." and cid=".$dbh->quote($ppid));
                        $ppid||=int(0)
                } elsif($rep eq "top") {
                        $ppid=0;
                }

	        my $strsql="UPDATE comments SET
        	        points=points$sign,
			lastmod=$$USER{uid},
                        pid=$ppid
                       	WHERE sid='$sid' and cid=$cid";

		if($sign ne "+0" and $dbh->do($strsql)) {
			open MODLOG,">>$datadir/logs/moderation.log";
			print MODLOG localtime()."\t",
				$$USER{uid},"\t",$sid,"\t",$cid,"\t",$sign,"\n";
			close MODLOG;
		}
		
                $dbh->do("UPDATE users SET score=score$sign WHERE uid=$cuid") if $val;

		if($val or $rep) {
                	$$USER{points}-- if $val or $rep;
                	$dbh->do("UPDATE users SET points=points-1 WHERE uid=$$USER{uid}");
                	print "<LI>$sid/$cid mod=$sign rep=$rep ($ppid) ($$USER{points} points left)\n";
		}
        } else {
                print "Out of points.\n";
        }
}

sub deleteThread
{
        my($sid,$cid)=@_;
#	return unless $cid;
        my $delCount=0;
	print "Delete thread s=$sid d=$cid ";
        my $delkids=$dbh->prepare("select cid from comments where sid='$sid' and pid='$cid'");
        $delkids->execute();
        while(my ($scid)=$delkids->fetchrow_array) {
                $delCount+=deleteThread($sid,$scid);
        }
        $delkids->finish();
        $dbh->do("delete from comments
                WHERE sid=".$dbh->quote($sid)." and cid=".$dbh->quote($cid));

	print "<BR>";
        return $delCount+1;
}                         




main;
# $dbh->disconnect;
0;
