#!/usr/bin/perl

require File::Basename;
my $self = $ENV{SCRIPT_FILENAME} || $0;
push @INC, File::Basename::dirname($self);        
push @INC, File::Basename::dirname($self) . "/..";

my $r = Apache->request unless $ENV{SLASH_UID};

use DBI;
use lib '/home/slash';
use strict;   
use Slash;

sub main
{
        $dbh ||= sqlConnect();
        my($FORM,$USER,$COOKIES)=getSlash($r);
	my $op=$$FORM{op};

	header("$sitename Users");
	if($op ne "userclose") {
	    print " [
		  <A href=$ENV{SCRIPT_NAME}>User Info</A> |
		  <A href=$ENV{SCRIPT_NAME}?op=sendpw>Mail Passwd</A> |
		  <A href=$ENV{SCRIPT_NAME}?op=edituser>Preferences</A> |
		  <A href=$ENV{SCRIPT_NAME}?op=userclose>Logout</A> " if $$USER{uid} > 0;
	    print " | <A href=$ENV{SCRIPT_NAME}?op=futuremods>Hiscores</A> 
	      | <A href=$ENV{SCRIPT_NAME}?op=listmoderators>Moderators</A>" if $$USER{aseclev};
	    print "	] " if $$USER{uid} > 0;
	    miniAdminMenu($USER,$FORM) if $$USER{aseclev} > 100;
	}

	if($op eq "newuser") { newUser($FORM);
	} elsif($op eq "edituser") { editUser($$USER{nickname},$USER);
	} elsif($op eq "userinfo" or !$op) {
		if($$FORM{nick}) { userInfo($$FORM{nick},$USER,$FORM);
		} elsif($$USER{uid} < 1) { displayForm($FORM);
		} else { userInfo($$USER{nickname},$USER,$FORM); }
	} elsif($op eq "saveuser") {
		saveUser($USER,$FORM,$$USER{uid});
		userInfo($$USER{nickname},$USER,$FORM);
	} elsif($op eq "sendpw") { mailPassword($$USER{nickname});
	} elsif($op eq "mailpasswd") {  mailPassword($$FORM{unickname});
	} elsif($op eq "listmoderators") { listModerators();
	} elsif($op eq "futuremods" and $$USER{aseclev} > 100) {
		futureModerators();
	} elsif($op eq "suedituser" and $$USER{aseclev} > 100) {
		editUser($$FORM{name},$USER);
	} elsif($op eq "susaveuser" and $$USER{aseclev} > 100) {
		saveUser($USER,$FORM,$$FORM{uid});	
	} elsif($op eq "sudeluser" and $$USER{aseclev} > 100) {
		delUser($$FORM{uid});
	} elsif($op eq "userclose") {
		print "ok bubbye now.";
		displayForm($FORM);
	} elsif($$FORM{op} eq "userlogin" and $$USER{uid} > 0) {
		userInfo($$USER{nickname},$USER);
	} elsif($$USER{uid} > 0) { userInfo($$FORM{nick},$USER);
	} else { displayForm($FORM); }
		
	
	writelog("users",$$USER{nickname});
	footer();
}

sub miniAdminMenu
{
	my($USER,$FORM)=@_;
	print "<FORM action=$ENV{SCRIPT_NAME}>
		[ <A href=$rootdir/admin.pl>Admin</A> |
		<FONT size=2>
		<INPUT type=hidden name=op value=suedituser>
		<INPUT type=text name=name value=\"$$FORM{nick}\">
		</FONT>
		<INPUT type=submit value=\"Edit\"> ]
		</FORM>";
}

sub arbitraryUserList
{
	my($where,$other,$what)=@_;
	$what=",$what" if $what;
	my $c=sqlSelectMany("uid,nickname $what", "users",$where, $other);
	while(my ($uid,$nick,@misc)=$c->fetchrow()) {
		my $n=$nick;
		$n=~s/ /+/g;
		print "($uid) <A href=$ENV{SCRIPT_NAME}?op=userinfo;nick=$n>$nick</A> @misc<BR>";
	}
	$c->finish();

}

sub listModerators
{
	titlebar("100%","Moderators");
	arbitraryUserList("seclev > 0","ORDER BY uid","points");
}

sub futureModerators
{
	titlebar("100%","High Scores (future moderators?)");
	arbitraryUserList("seclev = 0 and uid > 0 and score > 0","ORDER BY score DESC LIMIT 20","score");
}

sub userInfo
{
	my($nick,$USER,$FORM)=@_;

	my $c=$dbh->prepare("SELECT homepage,fakeemail,uid,bio,points,seclev FROM users
			WHERE nickname='$nick' and uid > 0");
	$c->execute();
	if(my ($home,$email,$uid,$bio,$points,$useclev)=$c->fetchrow()) {
		$c->finish();
		if($$USER{nickname} eq $nick) {

			titlebar("95%","Welcome back $nick ($uid)");
			print "<P>You've logged in.  This is your user page.  I
				eventually will have other nifty features availabe
				from here.  Perhaps a story list filtered to
				the categories you like.  I think it will need
				a better name then 'My Slashdot' tho.  Anyway,
				that's on my TODO list, but not until after I
				get caught up on my homework.";
			if($$USER{seclev}) {
				print "<P>You're a moderator with $points points.
					Try starting at <A
					href=$rootdir/index.pl?mode=dynamic>the
					dynamic moderator page</A> if you
					want to use them.  One point will
					be deducted any time you + or - an
					article.  One point is given to
					each moderator for every 50 comments
					posted.
					All the numbers
					are variables.  We'll tweak them until
					thing run smoothly.  For some general
					information, try reading my super beta
					<A href=/moderation.shtml>Moderator
					Guidelines</A>.<BR><P>\n";
			}
			print "<CENTER><IMG src=$imagedir/greendot.gif width=75\% height=1 
				align=center><BR></CENTER>\n";
		} else {
			titlebar("95%","User Info for $nick ($uid)");
		}


		print "<A href=$home>$home</A><BR>
		       <A HREF=mailto:$email>$email</A><BR>";
		print "<B>User Bio</B><BR>$bio<P>" if $bio;
		my ($count)=sqlSelect("count(*)","comments","uid=$uid");
		print "<B>$nick has posted $count comments</B> (this only
				counts the last few weeks)<BR><P>";
		$$FORM{min}=0 unless $$FORM{min};

		my $sqlquery="SELECT pid,sid,cid,subject,
                            date_format(date,\"W M D\@h:ip\")
                     	 FROM comments 
			WHERE uid=$uid ";
	        $sqlquery.=" ORDER BY date DESC LIMIT $$FORM{min},20 ";
       		my $c=$dbh->prepare($sqlquery);
	        $c->execute;
		my $x;
        	while(my ($pid, $sid, $cid, $subj, $cdate) =$c->fetchrow) {
               		$x++;
	                print "<BR><B>$x </B><A
        	               href=comments.pl?sid=$sid;pid=$pid\#$cid>$subj</A>
				posted on $cdate<FONT size=2>";
			my $S=sqlSelectHashref("section, title","stories","sid='$sid'");
			if($S) {
				print "<BR>attached to <A 
					href=$$S{section}/$sid.shtml>$$S{title}</A>";
			} else {
				my $P=sqlSelectHashref("question","pollquestions","qid='$sid'");
				print "<BR>attached to <A href=$rootdir/pollBooth.pl?qid=$sid>
					$$P{question}</A>" if $$P{question};
			}
			print "</FONT>";

		}
	} else {
		print "$nick not found.";
	}
	$c->finish();

}


sub delUser
{
	my ($uid)=@_;
	$dbh->do("DELETE from users WHERE uid=".$dbh->quote($uid));
}

sub editUser
{
	my($name,$USER)=@_;

	my($uid, $realname, $realemail, $fakeemail,$homepage,$mode,$posttype,
		$nickname,$passwd,$maillist,$mailreplies,$sig,$bio,
		$useclev,$score,$points,$threshold,$commentsort,$defaultpoints)=
							sqlSelect(
		"uid,realname,realemail,fakeemail,homepage,mode,posttype,
		 nickname,passwd,maillist,mailreplies,sig,bio,
		 seclev,score,points,threshold,commentsort,defaultpoints","users","nickname='$name'");

	return if $uid < 1;
	titlebar("95%","Editing $name ($uid) $realemail");

	$posttype||="plaintext";
	$mode||="thread";
	$homepage||="http://";
	print "You can automatically login by clicking
		<A 
		href=$ENV{SCRIPT_NAME}?op=userlogin;upasswd=$passwd;unickname=$nickname>This 
		Link</A> and Bookmarking the resulting page.
		This is totally insecure, but very convenient.";
	print "<FORM action=$ENV{SCRIPT_NAME} method=post>
		<B>Real Name</B> (optional)<BR>
		<INPUT type=text name=realname value=\"$realname\" size=40><BR>
		<INPUT type=hidden name=uid value=\"$uid\">
		<INPUT type=hidden name=passwd value=\"$passwd\">
		<INPUT type=hidden name=name value=\"$nickname\">
		<B>Real Email</B> (required but never displayed publicly.  This is
				where your passwd is mailed.  If you change your
				email, notification will be sent)<BR>
		<INPUT type=text name=realemail value=\"$realemail\" size=40><BR>
		<B>Fake Email</B> (optional:This email publicly displayed by your
			comments, you may spam proof it, leave it blank, or just type in
			your address)<BR>
		<INPUT type=text name=fakeemail value=\"$fakeemail\" size=40><BR>
		<B>Homepage</B> (optional:you must enter a fully qualified URL!)<BR>
		<INPUT type=text name=homepage value=\"$homepage\" size=60><BR>
		<B>Preferences</B> (roughly implemented.  It'll get better)<BR>
		display mode=<SELECT name=umode>
			<OPTION>$mode
			<OPTION>thread<OPTION>flat</SELECT>
		post mode=<SELECT name=posttype>
			<OPTION>$posttype
			<OPTION>html<OPTION>plaintext<OPTION>exttrans</SELECT>";

		print "<P><B>Headline Mailing List</B> (this will send you email!)<BR>\n";
		selectForm("maillist","maillist",$maillist);
	print "<P><B>Threshold</B> comments scored less than this will not be 
			displayed on comment display scripts<BR>
		<INPUT type=text name=uthreshold size=3 value=$threshold>";

	if($$USER{aseclev} >0) {
		print "<P><B>Top level comment sort order</B> (doesn't work on static pages)<BR>\n";
		selectForm("sortcodes","commentsort",$commentsort);
		print "
		<P><B>Mail Replies</B> (Sends email to your real email address if
			a public reply is posted to one of your comments.  This
			is a number that limits how many emails you want to
			receive.  Leave 0 to not get any mail.  Not in use.)<BR>
		<INPUT type=text name=mailreplies size=3 value=$mailreplies>
		<P><B>Seclev</B> User security.  If > 0, they can moderate<BR>
		<INPUT type=text name=useclev size=3 value=$useclev>
		<P><B>Points</B> (number of points delete to moderate with)<BR>
		<INPUT type=text name=points size=3 value=$points>
		<P><B>Score</B> (comment posting alignment)<BR>
		<INPUT type=text name=score size=3 value=$score>
		<P><B>Default Points</B> (default points to this users comments)<BR>
		<INPUT type=text name=defaultpoints size=3 value=$defaultpoints>
		";
		
	}

	print"	<P><B>Sig</B> (appended to the end of comments you post, 120 chars)<BR>
		<TEXTAREA name=sig rows=2 cols=60>$sig</TEXTAREA>
                <P><B>Bio</B> (this information is publicly displayed on your user
			page.  255 chars)<BR>
	 	<TEXTAREA name=bio rows=5 cols=60 wrap=virtual>$bio</TEXTAREA>
		<P><B>Password</B> Enter new passwd twice to change it. (must be > 5 chars)<BR>
		<INPUT type=password name=pass1 size=20>
		<INPUT type=password name=pass2 size=20><BR>";
	print "	<INPUT type=submit name=op value=saveuser>";
	print "	<INPUT type=submit name=op value=susaveuser>
		<INPUT type=submit name=op value=sudeluser>" if $$USER{aseclev}> 499;
	print "		</FORM>";
}


sub saveUser
{
	my($USER,$FORM,$uid)=@_;
	$uid=$$USER{uid} unless $$USER{aseclev};
	my $name=$$USER{nickname};
	$name=$$FORM{name} if $$USER{aseclev};
	
	print "<P>Saving $$FORM{name}<BR><P>" if $$FORM{name};
	print "<P>Something isn't working!" unless $name;
	print "<P>You're browser didn't save a cookie properly.
		This could mean you are behind a filter that
		eliminates them, you are using a browser
	        that doesn't support them, or you rejected it.
		" if $uid < 1;	
	$name=~s/'/''/g;
	my ($oldEmail)=sqlSelect("realemail","users","nickname='$name'");
	if($oldEmail ne $$FORM{realemail}) {
		sqlUpdate("users","nickname=".$dbh->quote($name),(realemail=>$$FORM{realemail}));
		print "\nNotifying $oldEmail of the change to their account.<BR>\n";
    		sendEmail2($oldEmail,"$sitename user email change for $name","
The user account '$name' on $sitename had this email
associated with it.  A web user from $ENV{REMOTE_ADDR} has
just changed it to $$FORM{realemail}.

If this is wrong, well then we have a problem.
");

	}

	$$FORM{sig}=stripByMode($$FORM{sig},"",0,getapptags());
	$$FORM{homepage}=stripByMode($$FORM{homepage},"",0,getapptags());

	sqlUpdate("users","uid>0 and nickname=".$dbh->quote($name),(seclev=>$$FORM{useclev}, points=>$$FORM{points},
		  score=>$$FORM{score}, mailreplies=>$$FORM{mailreplies},
		  defaultpoints=>$$FORM{defaultpoints})) if $$USER{aseclev} > 1;

	sqlUpdate("users","nickname=".$dbh->quote($name)." and uid>0",(threshold=>$$FORM{uthreshold}, realname=>$$FORM{realname},
		  fakeemail=>$$FORM{fakeemail},homepage=>$$FORM{homepage},
  		  mode=>$$FORM{umode},posttype=>$$FORM{posttype},sig=>$$FORM{sig},
		  maillist=>$$FORM{maillist},bio=>$$FORM{bio},commentsort=>$$FORM{commentsort}));

	if($$FORM{pass1} eq $$FORM{pass2} and length($$FORM{pass1}) > 5) {
		sqlUpdate("users","uid > 0 and nickname=".$dbh->quote($name),passwd=>$$FORM{pass1});
		print "Password Changed  (You'll need to log 
			<A href=$ENV{SCRIPT_NAME}>back in</A> now.)<BR>";
	} elsif($$FORM{pass1} ne $$FORM{pass2}) {
		print "Passwords don't match.<BR>";
	} elsif(length $$FORM{pass1} < 6 and $$FORM{pass1}) {
		print "Password is too short and was not changed.";
	}
}

sub newUser
{
	my ($FORM)=@_;
	# Check if User Exists
	my ($cnt)=sqlSelect("count(*)","users","nickname='$$FORM{newuser}'
				OR realemail='$$FORM{email}'");
	$_=$$FORM{newuser};
	if($cnt==0 and !/Anonymous Coward/i) {
		my ($uid)=sqlSelect("max(uid)","users");
		$uid++;
		fancybox(200,"User \#$uid created.",
			"<B>email</B>=$$FORM{email}<BR>
			<B>nick</B>=$$FORM{newuser}<BR>
			<B>passwd</B>=mailed to $$FORM{email}<BR>
			<P>Once you receive your password, you can log in and
			<A href=$rootdir/users.pl>set your account up</A>.");

		$$FORM{newuser}=~s/\s+/ /g;
		$$FORM{newuser}=stripByMode($$FORM{newuser},"plaintext");
		sqlInsert("users", uid=>$uid, realemail=>$$FORM{email}, 
			nickname=>$$FORM{newuser}, mailreplies=>0, 
			maillist=>0, seclev=>0, threshold=>0, score=>0, points=>0);
			
		changePassword($$FORM{newuser});
		mailPassword($$FORM{newuser});
	} else {
		print "A user already exists with that name or email address.
			Press that back button and try a new one.  If you
			<B>are</B> that person, than you can just login.
			If you forgot your password, type your nick in, 
			and click the 'mail password button to be sent it.
			If you forgot your nick, you have bigger problems.
			";
	}
}

sub changePassword
{
	my $r=crypt($_[0],rand);
	$r=~s/[i1I]/x/g;
	$r=substr($r,2,8);
	sqlUpdate("users","nickname=".$dbh->quote($_[0]),(passwd=>$r)) if $_[0];
}

sub mailPassword
{
	my($name)=@_;
	print "Name is $name";
	my ($passwd,$email)=sqlSelect("passwd,realemail",
					"users","nickname='$name'");

	my $msg=blockCache("newusermsg");
	$msg=prepBlock($msg);
	$msg=eval $msg;
	sendEmail2($email,"$sitename user password for $name",$msg) if $name;
	print "Passwd for $name was just emailed.<BR>\n";
}

sub displayForm
{
	my ($FORM)=@_;

	print "<P><FORM action=$ENV{SCRIPT_NAME} method=post>";
	titlebar("95%","Login");
	print "<P>Logging in will allow you to post comments as
		yourself.  If you don't login, you will only
		be able to post as The Anonymous Coward.<BR>";
	print "	<B>Nick:</B><BR>
		<INPUT type=text name=unickname size=20><BR>
		<B>Password:</B><BR>
		<INPUT type=password name=upasswd size=20><BR>";
	#	<B>Save my cookie</B><BR>";
	#	<INPUT type=radio name=cookie value=forever>Forever<BR>
	#	<INPUT type=radio name=cookie value=session CHECKED>Until I close my Browser<BR>

	print "	<INPUT type=submit name=op value=userlogin>
		<INPUT type=submit name=op value=mailpasswd>
		";
	titlebar("95%","New User");
	print "	<P>What, You don't have an account yet?  Well enter your
		preferred <B>nick</B> name here:<BR>
		<INPUT type=text name=newuser size=50><BR>
		And the <B>email</B> address to send your password to:
		(this email address will <B>not</B> be displayed on the website)
		<INPUT type=text name=email size=50><BR>
		click the button to be mailed a password:<BR>	
		<INPUT type=submit name=op value=newuser><BR>
	   	Some notes: I'm not gonna spam you with this.  The email is
		just so I have somewhere to send your password.
		</FORM>
	";
}




# Blame Nate for this one :)
sub sendEmail2
{
	use Socket;
        my ($addr, $subject, $content) = @_;

        socket (SMTP, PF_INET, SOCK_STREAM, getprotobyname('tcp'))
                or die "socket $!";
        connect (SMTP, sockaddr_in(25, inet_aton("127.0.0.1")))
                or die "connect $!";

        my $line = <SMTP>;
        send SMTP, "helo localhost\n", 0;
        $line = <SMTP>;
        send SMTP, "MAIL FROM:nobody\@localhost.org\n", 0;
        $line = <SMTP>;
        send SMTP, "RCPT TO:$addr NOTIFY=NEVER\n", 0;
        $line = <SMTP>;
        send SMTP, "DATA\n", 0;
        $line = <SMTP>;
	send SMTP, "To: $addr
From: nobody\@localhost
Subject: $subject
$content\n.\n", 0;
        $line = <SMTP>;
        send SMTP, "quit\n", 0;
	
	close (SMTP);
}                      




main;
$dbh->disconnect() if $dbh;
1;
