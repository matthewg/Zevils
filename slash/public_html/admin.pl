#!/usr/bin/perl

my $r = Apache->request if $ENV{SERVER_PROTOCOL};

require File::Basename;
my $self = $ENV{SCRIPT_FILENAME} || $0;
push @INC, File::Basename::dirname($self);
push @INC, File::Basename::dirname($self) . "/..";

use DBI;
require Slash;
require strict vars;
require htmlutils;

sub main
{
        $dbh ||= sqlConnect();
	my ($FORM,$USER)=getSlash($r);
	header("backSlash","admin");

	# Admin Menu
	if($$USER{aseclev}) {
		adminMenu($USER);
	} else {
		print "<P>\&nbsp;<P>";
	}

	my $op=$$FORM{op};
	if(!$$USER{aseclev}) {
		titlebar("99%","back<I>Slash</I> Login");
		adminLoginForm();	
	} elsif($op eq "logout") {
		$dbh->do("DELETE FROM sessions WHERE aid=".$dbh->quote($$USER{aid}));
		titlebar("99%","back<I>Slash</I> Bub Bye");
		adminLoginForm();
	} elsif($op eq "topiced") {
		topiced($FORM);
	} elsif($op eq "save") {
		saveStory($USER,$FORM);
	} elsif($op eq "update") {
		updateStory($USER,$FORM);
	} elsif($op eq "list") {
		titlebar("99%","Story List","c");
		liststories($USER,$FORM);
	} elsif($op eq "delete") {
		rmstory($$USER{aid},$$FORM{sid});
		liststories($USER,$FORM);
	} elsif($op eq "preview") {
		editstory($USER,"",$FORM);
	} elsif($op eq "edit") {
		editstory($USER,$$FORM{sid});
	} elsif($op eq "topics") {
		listtopics($$USER{aseclev});
	} elsif($op eq "blocked") {
		blockEdit($$USER{aseclev},$$FORM{bid});
	} elsif($op eq "blocksave") {
		blockSave($FORM,$USER);
		blockEdit($$USER{aseclev},$$FORM{bid});
	} elsif($op eq "authors") {
		authorEdit($$FORM{thisaid},$USER);
	} elsif($op eq "authorsave") {
		authorSave($FORM);
		authorEdit($$FORM{myaid},$USER);
	} elsif($op eq "vars") {
		varEdit($$FORM{name});	
	} elsif($op eq "varsave") {
		varSave($FORM);
		varEdit($$FORM{name});
	} else {
		titlebar("99%","Story List","c");
		liststories($USER,$FORM);
	}
	writelog("admin",$$USER{aid});

	# Display who is logged in right now.
	currentAdminUsers($USER) if $$USER{aseclev} > 0;
	footer();

}

sub updateStory
{
	my($USER,$FORM)=@_;

	# Some users can only post to a fixed section
	if($$USER{asection}) {
		$$FORM{section}=$$USER{asection};
		$$FORM{displaystatus}=0;
		$$FORM{writestatus}=0;
	}
	$$FORM{dept}=~s/ /-/g;

	sqlUpdate("stories","sid=".$dbh->quote($$FORM{sid}),(
		   	tid=>$$FORM{tid},
			dept=>$$FORM{dept},
			title=>$$FORM{title},
			section=>$$FORM{section},
			bodytext=>$$FORM{bodytext},
			introtext=>$$FORM{introtext},
			writestatus=>$$FORM{writestatus},
			displaystatus=>$$FORM{displaystatus},
			commentstatus=>$$FORM{commentstatus}
			));
	$dbh->do("UPDATE stories SET time=now() WHERE sid=".$dbh->quote($$FORM{sid}))
			if $$FORM{fastforward} eq "on";
	titlebar("99%","Article $$FORM{sid} Saved","c");
	liststories($USER,$USER);
}

sub saveStory
{
	my($USER,$FORM)=@_;
	$$FORM{sid}=getsid();
   	$$FORM{displaystatus}||="1" if $$USER{asection};
	$$FORM{section}=$$USER{asection} if $$USER{asection};
	$$FORM{dept}=~ s/ /-/g;
	sqlInsert("stories",(sid=>$$FORM{sid},
			-time=>'now()',
			aid=>$$USER{aid},
		   	tid=>$$FORM{tid},
			dept=>$$FORM{dept},
			title=>$$FORM{title},
			section=>$$FORM{section},
			bodytext=>$$FORM{bodytext},
			introtext=>$$FORM{introtext},
			writestatus=>$$FORM{writestatus},
			displaystatus=>$$FORM{displaystatus},
			commentstatus=>$$FORM{commentstatus}));
	titlebar("100%","Inserted $$FORM{sid} $$FORM{title}");
	liststories($USER,$FORM);
}


sub adminLoginForm
{	
	print "<FORM action=$ENV{SCRIPT_NAME} method=POST>
		<INPUT type=hidden name=op value=adminlogin>
		<CENTER><TABLE>
		 <TR>
		  <TD align=right>Login</TD>
		  <TD><INPUT type=text name=aaid></TD>
		 </TR><TR>
		  <TD align=right>Password</TD>
		  <TD><INPUT type=password name=apasswd></TD>
		 </TR><TR>
		  <TD> </TD><TD><INPUT type=submit
		  value=\"Login\"></TD></FORM>
		</TR></TABLE></CENTER></FORM>
";
}

sub varEdit
{
	my($name)=@_;
	print "<FORM action=$ENV{SCRIPT_NAME} method=post>";
        selectGeneric("vars","name","name","name",$name);
	my ($value,$desc)=sqlSelect("value,description",
		"vars","name='$name'");
	print "Next<BR>
	   	<P><B>Var</B><BR>".formName(name=>thisname, value=>$name)."<BR>
	   	<P><B>Value</B><BR>".formName(name=>value, value=>$value)."<BR>
	   	<P><B>Description</B><BR>".formName(name=>desc, value=>$desc, size=>60)."<BR>
		<INPUT type=submit value=varsave name=op>
		</FORM>";
}

sub varSave
{
	my($FORM)=@_;
	if($$FORM{thisname}) {
		my ($exists)=sqlSelect("count(*)","vars",
			"name='$$FORM{thisname}'");
		if($exists==0) {
			sqlInsert("vars",(name=>$$FORM{thisname}));
			print "Inserted $$FORM{thisname}<BR>";
		}
		if($$FORM{desc}) {
			print "Saved $$FORM{thisname}<BR>";
			sqlUpdate("vars","name=".$dbh->quote($$FORM{thisname}),(value=>$$FORM{value},description=>$$FORM{desc}));
		} else {
			print "Deleted $$FORM{thisname}<BR>";
			$dbh->do("DELETE from vars WHERE name='$$FORM{thisname}'");
		}
	}
}




sub authorEdit
{
	my($aid,$USER)=@_;
	print "<FORM action=$ENV{SCRIPT_NAME} method=post>";
        selectGeneric("authors","myaid","aid","aid",$aid);
	my $a=sqlSelectHashref("*","authors","aid=".$dbh->quote($aid));
		
	print "Next<BR>
	   	<P><B>Aid</B><BR>
        	<INPUT type=text name=thisaid value=\"$aid\"><BR>
	   	<P><B>Name</B><BR>
        	<INPUT type=text name=name value=\"$$a{name}\" size=60><BR>
	   	<P><B>URL</B><BR>
        	<INPUT type=text name=url value=\"$$a{url}\" size=60><BR>
	   	<P><B>Email</B><BR>
        	<INPUT type=text name=email value=\"$$a{email}\" size=60><BR>
	   	<P><B>Passwd</B><BR>
        	<INPUT type=password name=pwd value=\"$$a{pwd}\" size=20><BR>
	   	<P><B>Seclev</B><BR>
        	<INPUT type=text name=seclev value=\"$$a{seclev}\" size=6><BR>
		<P><B>Restrict to Section</B><BR>";
	my $SECT=getSection($$a{section});
	selectSection("section",$$a{section},$SECT,$USER);
	print "	<BR><INPUT type=submit value=authorsave name=op>
		</FORM>";
}

sub authorSave
{
	my($FORM)=@_;
	if($$FORM{thisaid}) {
		my ($exists)=sqlSelect("count(*)","authors",
			"aid=".$dbh->quote($$FORM{thisaid}));
		if(!$exists) {
			sqlInsert("authors",(aid=>$$FORM{thisaid}));
			print "Inserted $$FORM{thisaid}<BR>";
		}
		if($$FORM{thisaid}) {
			print "Saved $$FORM{thisaid}<BR>";
			sqlUpdate("authors","aid=".$dbh->quote($$FORM{thisaid}),(
				name=>$$FORM{name},
				pwd=>$$FORM{pwd},
				email=>$$FORM{email},
				url=>$$FORM{url},
				seclev=>$$FORM{seclev}));
		} else {
			print "Deleted $$FORM{thisaid}<BR>";
			$dbh->do("DELETE from authors WHERE aid=".$dbh->quote($$FORM{thisaid}));
		}
	}
}






sub blockEdit
{
	my($seclev,$bid)=@_;
	print "<FORM action=$ENV{SCRIPT_NAME} method=post>";
        selectGeneric("blocks","bid","bid","bid",$bid,"$seclev >= seclev");
	my ($block,$bseclev)=sqlSelect("block,seclev","blocks","bid='$bid'");
	$block=~s/\&/\&amp\;/g;
	print "Next<BR>
	   	<P><B>Block ID / Seclev</B><BR>
        	<INPUT type=text name=thisbid value=\"$bid\">
		<INPUT type=text name=bseclev value=\"$bseclev\" size=6>
		<P><B>Block</B><BR>
		<TEXTAREA rows=8 cols=60 name=block>$block</TEXTAREA><BR>
		<INPUT type=submit value=blocksave name=op>
		</FORM>";
	my $c=$dbh->prepare("SELECT section FROM sectionblocks WHERE bid='$bid'");
	if($c->execute()) {
		print "Sections:";
		while(my ($section)=$c->fetchrow()) {
			print "<A href=$rootdir/sections.pl?section=$section;op=editsection>$section</A> ";
		}
		print "<BR>";
	}
	$c->finish();

}

sub blockSave
{
	my($FORM,$USER)=@_;
	if($$FORM{thisbid}) {
		my ($exists)=sqlSelect("count(*)","blocks",
			"bid=".$dbh->quote($$FORM{thisbid}));
		if($exists==0) {
			sqlInsert("blocks", bid=>$$FORM{thisbid}, seclev=>500);
			print "Inserted $$FORM{thisbid}<BR>";
		}
		if($$FORM{block}) {
			print "Saved $$FORM{thisbid}<BR>";
			
	                $$FORM{block}=autoUrl($USER,$$FORM{section},$$FORM{block});

			sqlUpdate("blocks","bid=".$dbh->quote($$FORM{thisbid}),(seclev=>$$FORM{bseclev}, block=>$$FORM{block}));
		} else {
			print "Deleted $$FORM{thisbid}<BR>";
			$dbh->do("DELETE from blocks WHERE bid=".$dbh->quote($$FORM{thisbid}));
		}
	}
}


sub topiced
{
	my ($FORM)=@_;
	if($$FORM{tid}) {
		$dbh->do("DELETE from topics WHERE tid='$$FORM{tid}'");
		foreach (keys %$FORM) { print "$_ = $$FORM{$_} "; }
		sqlInsert("topics", tid=>$$FORM{tid}, image=>$$FORM{image},
			alttext=>$$FORM{alttext}, width=>$$FORM{width}, height=>$$FORM{height});
		sqlUpdate("topics","tid=".$dbh->quote($$FORM{tid}),(image=>$$FORM{image}, alttext=>$$FORM{alttext}, 
			width=>$$FORM{width}, height=>$$FORM{height}));
	}

	print "<FORM action=$ENV{SCRIPT_NAME} method=post>
		<INPUT type=hidden name=op value=topiced>";
	selectTopic("nexttid",$$FORM{nexttid});
	print "<INPUT type=submit value=Select><BR>";

	my ($tid,$width,$height,$alttext,$image)=sqlSelect(
		"tid,width,height,alttext,image","topics","tid='$$FORM{nexttid}'");

	if($$FORM{nexttid}) {
     		print "<BR><IMG src=$imagedir/topics/$image alt=\"$alttext\"
                       width=$width height=$height>";
	}
	print "Tid<BR>
		<INPUT type=text name=tid value=$tid><BR>";

	print "Dimensions<BR>
		<INPUT type=text name=width value=$width size=4>
		<INPUT type=text name=height value=$height size=4><BR>
	       Alt Text<BR>
		<INPUT type=text name=alttext value=\"$alttext\"><BR>
	       Image<BR>
		<INPUT type=text name=image value=$image><BR>
		<INPUT type=submit value=Select></FORM>
		";

}


sub rmstory
{
	my ($aid, $sid) =@_;
	$dbh->do("UPDATE stories SET writestatus=5
		   WHERE (aid='$aid') AND sid='$sid'");

	titlebar("99%","$sid will probably be deleted in 60 seconds.");
}

sub listtopics
{
	my ($seclev)=@_;
	my $cursor=$dbh->prepare("SELECT tid,image,alttext,width,height
				  FROM topics
				  ORDER BY tid");
	titlebar("99%","Topic Lister");
	my $x=0;
	$cursor->execute;
	print "<TABLE width=600 align=center>";
	while(my ($tid,$image,$alttext,$width,$height)=$cursor->fetchrow) {
		print "</TR><TR>" unless $x++ % 6;
		print "<TD align=center>";
		if($seclev > 500) {
			print "<A href=$ENV{SCRIPT_NAME}?op=topiced;nexttid=$tid>";
		}
		print "	<IMG src=$imagedir/topics/$image alt=\"$alttext\"
			  width=$width height=$height border=0><BR>$tid</A></TD>";
				
	}
	$cursor->finish();
	print "</TR></TABLE>";
}


sub editbuttons
{
	my ($newarticle)=@_;
	print "<INPUT type=submit name=op value=save> " if $newarticle;
	print "<INPUT type=submit name=op value=preview> ";
	print "<INPUT type=submit name=op value=update>
	       <INPUT type=submit name=op value=delete>" unless $newarticle;
}


sub getUrlFromTitle
{
	my ($title)=@_;
	my ($section,$sid)=sqlSelect("section,sid","stories",
		"title like \"\%$title\%\"",
		"order by time desc LIMIT 1");
	return "$rootdir/$section/$sid.shtml";
}

sub importImage
{
	# Check for a file upload
	my $section=@_[0];
 	my $filename=$query->param('importme');
	my $tf=getsiddir().$filename;
	$tf=~s|/|~|g;
	$tf="$section~$tf";
	if($filename) {
		system("mkdir /tmp/slash");
		open (IMAGE,">>/tmp/slash/$tf");
		my ($buffer,$bytesread);
              	while ($bytesread=read($filename,$buffer,1024)) {
                	print IMAGE $buffer;
              	}    
		close IMAGE;
	} else {
		return "<image:not found>";
	}
	use imagesize;
	my ($w,$h)=imagesize::imagesize("/tmp/slash/$tf");
	return "<IMG src=$rootdir/$section/".getsiddir().$filename." WIDTH=$w HEIGHT=$h ALT=\"image\">";
}



sub importText
{
	# Check for a file upload
 	my $filename=$query->param('importme');
	my ($r,$bytesread,$buffer);
	if($filename) {
              	while ($bytesread=read($filename,$buffer,1024)) {
			$r.=$buffer;
              	}    
	}
	return $r;
}

sub autoUrl
{
	my ($USER,$section)=@_;
	$_=@_[2];
	my $initials=substr($$USER{aid},0,1);
	my $more=substr($$USER{aid},1);
	$more=~s/[a-z]//g;
	my $initials=uc($initials.$more);
	my ($now)=sqlSelect("date_format(now(),\"m/d h:i\")");
	s|\<update\>|\<B\>Update: \<date\>\</B\> by \<author\>|ig;
	s|\<date\>|$now|g;
	s|\<upload\>|importText()|ex;
	s|\<author\>|<B><A href=$$USER{url}>$initials</A></B>:|ig;
	s/\<image(.*?)\>/importImage($section)/ex;
	s/\[%(.*?)%\]/getUrlFromTitle($1)/exg;
	$_;
}


sub editstory
{
	my ($USER,$sid,$FORM) = @_;
	my ($S,$A,$T);
	foreach (keys %$FORM) { $$S{$_}=$$FORM{$_} };
	my $newarticle=1 if (!$sid and !$$FORM{sid});

	if($$FORM{title}) { 
		# Preview Mode
		sqlUpdate("sessions","aid=".$dbh->quote($$USER{aid}),(lasttitle=>$$S{title}));
		($$S{writestatus},$$S{displaystatus},$$S{commentstatus})
			=getvars("defaultwritestatus","defaultdisplaystatus",
				"defaultcommentstatus");
		$$S{writestatus}=$$FORM{writestatus} if $$FORM{writestatus};
		$$S{displaystatus}=$$FORM{displaystatus} if $$FORM{displaystatus};
		$$S{commentstatus}=$$FORM{commentstatus} if $$FORM{commentstatus};
		$$S{dept}=~ s/ /-/gi;

		$$S{introtext}=autoUrl($USER,$$FORM{section},$$S{introtext});
		$$S{bodytext}=autoUrl($USER,$$FORM{section},$$S{bodytext});

		$T=sqlSelectHashref("*","topics","tid=".$dbh->quote($$S{tid}));
		$$FORM{aid}||=$$USER{aid};
		$A=sqlSelectHashref("*","authors","aid=".$dbh->quote($$FORM{aid}));
		$sid=$$FORM{sid};
		dispStory($USER,$S,$A,$T,"Full");

		print "	<P><IMG src=$imagedir/greendot.gif width=80% align=center
			hspace=20 height=1><P>";
	} elsif(defined $sid) { # Loading an Old SID
		($S,$A,$T)=displayStory($USER, $sid,"Full");
	} else { # New Story
		($$S{writestatus})=getvars("defaultwritestatus");
		($$S{displaystatus})=getvars("defaultdisplaystatus");
		($$S{commentstatus})=getvars("defaultcommentstatus");
		$$S{tid}||="news";
		$$S{section}||="articles";
		$$S{aid}=$$USER{aid};
	}

	$$S{introtext}=~s/\&/\&amp\;/g;
	$$S{bodytext}=~s/\&/\&amp\;/g;
	my $SECT=getSection($$S{section});

	print"	<FORM ENCTYPE=\"multipart/form-data\" action=$ENV{SCRIPT_NAME} method=POST>";
	editbuttons($newarticle);
	selectTopic("tid",$$S{tid});
	unless($$USER{asection}) {
		selectSection("section",$$S{section},$SECT,$USER) unless $$USER{asection};
	}
	print "\n<INPUT type=hidden name=aid value=\"$$S{aid}\">" if $$S{aid};
	print "\n<INPUT type=hidden name=sid value=\"$$S{sid}\">" if $$S{sid};

	$$S{dept}=~ s/ /-/gi;
	print "\n<BR>title ", 
		$query->textfield(-name=>title,-default=>$$S{title},-size=>50),
		"\n<BR>dept ",
		$query->textfield(-name=>dept, -default=>$$S{dept}, -size=>50),"
		<BR>";


	selectForm("statuscodes","writestatus",$$S{writestatus});
	unless($$USER{asection}) {
		selectForm("displaycodes","displaystatus",$$S{displaystatus});
	}
	selectForm("commentcodes","commentstatus",$$S{commentstatus});
	print "<BR>Change date to Now: ".formCheckbox("",name=>fastforward)."
		[ <A href=$rootdir/pollBooth.pl?qid=$sid;op=edit>Related Poll</A> ]\n" if $sid;
	print "<BR>Intro Copy<BR>
		<TEXTAREA name=introtext cols=60 rows=10>$$S{introtext}</TEXTAREA><BR>";
	editbuttons($newarticle);
	print "	Extended Copy<BR>
		<TEXTAREA name=bodytext cols=60 rows=10>$$S{bodytext}</TEXTAREA><BR>
		Import Image (don't even both trying this yet :)<BR>
		<INPUT type=file name=importme><BR>";
	editbuttons($newarticle);
}


sub liststories
{
	my ($USER,$FORM) = @_;
	my ($x,$first)=(0,$$FORM{next});
	my $sql="SELECT hits, commentcount, sid, title, aid,
			date_format(time,\"m/d h:i\"),tid,section,
			displaystatus,writestatus
			FROM stories ";
	$sql.="		WHERE section='$$USER{asection}'" if $$USER{asection};
	$sql.="		WHERE section='$$FORM{section}'" 
		if $$FORM{section} and !$$USER{asection};
	$sql.="	        ORDER BY time DESC";
	my $cursor=$dbh->prepare($sql);

	$cursor->execute;
	print "<TABLE border=0 celpadding=3 cellspacing=0 width=95\%>";
	while(my ($hits,$comments,$sid,$title,$aid,$time,$tid,$section,
			$displaystatus,$writestatus)=$cursor->fetchrow) {
		my $bgcolor="";
		if($displaystatus>0) {
			$bgcolor="\#cccccc";
		} elsif($writestatus<0 or $displaystatus<0) {
			$bgcolor="\#999999";
		}
		$x++;
		if($x >= $first and $x < ($first+26) ) {
			if (length $title > 45) {
				$title=substr($title,0,40)."...";
			}
			print "<TR bgcolor=$bgcolor>
				<TD align=right><B>$x</B></TD>
				<TD><A href=$rootdir/article.pl?sid=$sid>
				$title\&nbsp;</A></TD>
				<TD><FONT size=2><B>$aid</B></FONT></TD>
				<TD><FONT size=2>".substr($tid,0,5)."</FONT></TD>";
			print "	<TD><FONT size=2><A 
				href=$ENV{SCRIPT_NAME}?section=$section>"
				.substr($section,0,5)."</A></TD>" unless 
				($$USER{asection} or $$FORM{section});
			print "	<TD align=right><FONT size=2>$hits</FONT> </TD>
				<TD><FONT size=2>$comments</FONT></TD>
				<TD><FONT size=2>$time</TD> ";
			if($$USER{aid} eq $aid or $$USER{aseclev} > 100) {
				print "<TD>(<A
				href=$ENV{SCRIPT_NAME}?op=edit;sid=$sid>edit</A>)
				</TD>";
			}
			print "</TR>";
		}

	}
	$cursor->finish();
	print "</TABLE>";
	$first+=25;
	my $left=$x-$first;
	if ($x > $first) {
	print "<P><B><A
		href=$ENV{SCRIPT_NAME}?section=$$FORM{section};op=list;next=$first>$left More</A></B>";
	}
}


main();
$dbh->disconnect() if $dbh;
1;
