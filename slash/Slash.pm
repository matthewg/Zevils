package Slash;
use strict;
use vars qw($query $imagedir $rootdir $ssidir $sitename $slogan $currentSection $currentMode $userMode $dbh $datadir &getSlash &linkStory &getSection &adminMenu &selectForm &selectGeneric &selectTopic &selectSection &getvars &getvar &setvar &newvar &getapptags &getfile &geturl &prog2file &url2file &getUser &getblock &getsid &getsiddir &writelog &pollbooth &sqlSelectMany &sqlSelect &sqlSelectHash &sqlSelectHashref &sqlUpdate &sqlInsert &sqlconnect &stripByMode &stripBadHtml &approvetag &header &footer &prepEvalBlock &prepBlock &nukeBlockCache &blockCache &titlebar &fancybox &printComments &dispComment &dispStory &displayStory &sendEmail &pollItem &printComments2 &getOlderStories &displayStories &selectStories &currentAdminUsers);
use DBI;
use Carp;

sub BEGIN {
	use Exporter   ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);      
	$VERSION     = 0.30;

	@ISA=qw(Exporter);
	@EXPORT=qw($query $imagedir $rootdir $ssidir $sitename $slogan $currentSection $currentMode $userMode $dbh $datadir &getSlash &linkStory &getSection &adminMenu &selectForm &selectGeneric &selectTopic &selectSection &getvars &getvar &setvar &newvar &getapptags &getfile &geturl &prog2file &url2file &getUser &getblock &getsid &getsiddir &writelog &pollbooth &sqlSelectMany &sqlSelect &sqlSelectHash &sqlSelectHashref &sqlUpdate &sqlInsert &sqlconnect &stripByMode &stripBadHtml &approvetag &header &footer &prepEvalBlock &prepBlock &nukeBlockCache &blockCache &titlebar &fancybox &printComments &dispComment &dispStory &displayStory &sendEmail &pollItem &printComments2 &getOlderStories &displayStories &selectStories &currentAdminUsers);
	#Uncomment the following to enable stack traces:
	#$Carp::Verbose = 1;
	$SIG{__WARN__} = sub { carp $_[0] };
	$SIG{__DIE__ } = sub { croak $_[0] };

	use vars @EXPORT;
}

$dbh||=DBI->connect("DBI:mysql:slash", "slash", "wegotitallonUHF");
kill 9,$$ unless $dbh;
($imagedir,$rootdir,$datadir,$sitename,$slogan,$ssidir)
		=getvars("imagedir","rootdir","datadir","sitename","slogan","ssidir") unless $imagedir;
$ssidir ||= $rootdir;

my %blockBank;
my @approvedtags = (
        'B','I','P .*','P','A',
        'LI','OL','UL','EM','BR',
	'STRONG','BLOCKQUOTE',
	'HR','DIV .*','DIV','TT'
	);

sub getSlash
{
	my ($r)=@_;
	#$r->content_type("text/html");

	require CGI;
	#use CGI::Switch ();
	$query = "";
	$query = new CGI; 
	my @names = $query->param;
	my $FORM;
	foreach (@names) { $$FORM{$_}=$query->param($_) };

	print "HTTP/1.1 200 OK
Server: $ENV{SERVER_SOFTWARE}\n" unless $$FORM{ssi} eq "yes";

        my ($uid,$passwd);
	my $op=$$FORM{op};
	if($op eq "userlogin" and length $$FORM{upasswd} > 1) {
            	($uid,$passwd)=userLogin($$FORM{unickname},$$FORM{upasswd},$$FORM{expires});
        } elsif($op eq "userclose") {
		print "Set-Cookie: ",$query->cookie(-name=>'user',-value=>' '),"\n";
	} elsif($op eq "adminclose") {
		print "Set-Cookie: ",$query->cookie(-name=>'session',-value=>' '),"\n";
        } elsif($query->cookie('user')) {
                ($uid,$passwd)=userCheckCookie($query->cookie('user'));
        } else {
		$uid=-1;
	}      

        my $USER={getUser($uid,$passwd)};   
	($$USER{aid},$$USER{aseclev},$$USER{asection},$$USER{url})
		=getadmininfo($query->cookie('session')) 
		if $query->cookie('session');

	if($$FORM{op} eq "adminlogin") {
         	($$USER{aid},$$USER{aseclev})=setadmininfo($$FORM{aaid},$$FORM{apasswd});
        }

	$currentMode=$$USER{mode}=$$FORM{mode}=$$FORM{mode} || $$USER{mode} || "thread";
	$$USER{threshold}=$$FORM{threshold}=$$FORM{threshold} || $$USER{threshold} || "0";
	$$USER{posttype}=$$FORM{posttype} || "plaintext";

	$$USER{seclev}=$$USER{aseclev} if $$USER{asecleev} > $$USER{seclev};

        print "Content-Type: text/html\n\n" unless $$FORM{ssi} eq "yes";
	return ($FORM,$USER);
}


sub currentAdminUsers
{
        my($USER)=@_;

        print "<P align=right>Authors: <B>";
	my $c=sqlSelectMany("distinct aid,lasttitle","sessions",
		"aid!=".$dbh->quote($$USER{aid}));
        while(my ($aid,$lasttitle)=$c->fetchrow()) {
                print " <A
                   href=$ENV{SCRIPT_NAME}?op=authors;thisaid=$aid>" 
			if $$USER{aseclev} > 10000;
                print "$aid";
                print "</A> " if $$USER{aseclev} > 10000;
                print " ($lasttitle) " if $lasttitle;
        }
        $c->finish();
}



sub setupUser
{
	my($section,$mode)=@_;

	$userMode=$mode eq "flat" ? "_F" : "" ;
	$currentSection=$section || "";
}


sub linkStory
{
        my($text,$mode,$sid,$sect)=@_;
	$sid=($mode eq "dynamic" 
		    or !$sect)?"article.pl?sid=$sid":"$sect/$sid$userMode".".shtml";
        return "<A href=\"$rootdir/$sid\">$text</A>";
}



sub getSection
{
	my($section)=@_;
	return { title=>$slogan,artcount=>30,issue=>3 } unless $section;
	return sqlSelectHashref("*","sections",	
		"section=".$dbh->quote($section));
}

sub ssiHead
{
	#print "$ssidir\n";
        print "<!--#include virtual=\"$ssidir/";
        print "$currentSection/" if $currentSection;
        print "slashhead$userMode",".inc\"-->\n";
}
                       
sub ssiFoot
{
        print "<!--#include virtual=\"$ssidir/";
        print "$currentSection/" if $currentSection;
        print "slashfoot$userMode",".inc\"-->\n";
        print "<!--#perl sub=\"Apache::Include\" arg=\"/slashlog.pl\"-->\n";
}      

sub adminMenu
{
	my($USER)=@_;
	my $seclev=$$USER{aseclev};
	return unless $seclev;
    	print "\n<FONT size=2>";
        print " [ <A href=$rootdir/admin.pl?op=adminclose>Logout $$USER{aid}</A>
                | <A href=$rootdir/index.pl>Home</A>
                | <A href=$rootdir/admin.pl>Stories</A>
                | <A href=$rootdir/admin.pl?op=topics>Topics</A>
                " if $seclev > 0;
        print " | <A href=$rootdir/admin.pl?op=edit>New</A>
                " if $seclev > 10;

	my ($cnt)=sqlSelect("count(*)","submissions");
        print " | <A href=$rootdir/submit.pl?op=list>$cnt Submissions</A>
                | <A href=$rootdir/admin.pl?op=blocked>Blocks</A>
                | <A href=$rootdir/users.pl>Users</A>
                | <A href=$rootdir/pollBooth.pl>Polls</A>
                " if $seclev > 499;
        print " | <A href=$rootdir/sections.pl?op=list>Sections</A>
		" if ($seclev > 999 or ($$USER{asection} and $seclev > 499));
	print " | <A href=$rootdir/admin.pl?op=authors>Authors</A>
                | <A href=$rootdir/admin.pl?op=vars>Variables</A>
                " if $seclev > 10000;
        print "] </FONT><P>\n\n" if $seclev > 0;                 
}

	
# What follows are a bunch of pseudo random functions for advanced HTML widget
# creation.  Good if you happen to be lazy :)
sub selectForm
{
	my ($table,$label,$default,$where)=@_;
	my ($thiscode, $thisname)=sqlSelect("code,name",$table,
		"code=".$dbh->quote($default) );
	print "\n<SELECT name=\"$label\">\n<OPTION value=\"$thiscode\">$thisname\n";
	my $sql="SELECT code,name FROM $table ";
	$sql.=" WHERE $where " if $where;
	$sql.="	ORDER BY name";
	my $c=$dbh->prepare($sql);
	$c->execute();
	while(my ($code,$name)=$c->fetchrow()) {
		print "<OPTION value=\"$code\">$name\n" unless $code eq $thiscode;
	}
	$c->finish();
	print "</SELECT>\n";
}

sub selectGeneric
{
        my ($table,$label,$code,$name,$default,$where,$order,$limit)=@_;
        my ($thiscode,$thisname)=sqlSelect("$code,$name",$table,"$code=".$dbh->quote($default)) if $default;

	$thisname=$default unless $thisname;
        print "\n<SELECT name=\"$label\">\n<OPTION value=\"$thiscode\">$thisname\n";
	my $sql=" SELECT $code,$name FROM $table ";
	$sql.="    WHERE $where" if $where;
	$sql.="	ORDER BY $name" unless $order;
	$sql.=" ORDER BY $order" if $order;
	$sql.="    LIMIT $limit" if $limit;
	my $c=$dbh->prepare($sql);
        $c->execute();
        while(my ($code,$name)=$c->fetchrow()) {
                print "<OPTION value=\"$code\">$name\n" unless $code eq $thiscode;
        }
        $c->finish();
        print "</SELECT>\n";
}

sub selectTopic
{
        my($name,$tid)=@_;
        selectGeneric("topics",$name,"tid","alttext",$tid);
}

sub selectSection
{
        my($name,$section,$SECT,$USER)=@_;
	
	if($SECT && $$SECT{isolate}) {
		print "<INPUT type=hidden name=$name value=$section>";
	} else {	
		my $where="isolate=0" unless $$USER{aseclev} > 499;
        	selectGeneric("sections",$name,"section","title",$section,$where);
	}
}                   


sub getvars
{
	my @invars=@_;
	my @vars;
	for(my $x=0;$x<@invars;$x++) {
		($vars[$x])=sqlSelect("value","vars","name='$invars[$x]'");
	}
	return @vars;
}


sub getvar
{
	my ($value, $desc)=sqlSelect("value,description","vars","name='$_[0]'");
}

# A few handy functions for getting dates for use with cookies- thanx nate.
sub cookietime
{
        my ($time) = @_;
        my @nums = gmtime($time);

        foreach my $num (@nums) {
                if (length($num)==1) { $num = 0 . $num; }
        }

        my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst)=@nums;
	$year += 1900;
        $wday = ("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday",
                "Friday", "Saturday")[$wday];

        $mon = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug",
                "Sep", "Nov", "Dec")[$mon-1];
        "$wday, $mday-$mon-$year $hour:$min:$sec GMT";
}

# thanks Michael Mittelstadt <meek@execpc.com> 
sub expiretime {
    my @a=gmtime(time+$_[0]);
    my @w=qw|Sun Mon Tue Wed Thu Fri Sat|;
    my @m=qw|Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec|;
    sprintf "%s, %02d %s %04d %02d:%02d:%02d GMT",
        $w[$a[6]], $a[3], $m[$a[4]], $a[5]+1900, $a[2], $a[1], $a[0];
}    

sub expireTime
{
        cookietime(time+60*30);
}                           

sub setvar
{
	my ($name, $value)=@_;
	sqlUpdate("vars","name=".$dbh->quote($name),(value=>$value));
}

sub newvar
{
	my ($name, $value, $desc)=@_;
	sqlInsert("vars",(name=>$name, value=>$value, description=>$desc));
}
	
 
sub getapptags
{
	return @approvedtags;
}

sub generatesession
{
        my $user = $_[0];
        my $newsid = crypt(rand, $user);
        $newsid =~ tr/A-Za-z0-9//dcs;
        return $newsid;
}      

sub getadmininfo
{
	my ($session)=@_;

	return ("",-1,"","") unless $session;

	my ($aid,$seclev,$section,$url)=("",-1,"","");

	# Need to kill older sessions
	$dbh->do("DELETE from sessions WHERE now() - lasttime > 10000");

	my $c=sqlSelectMany("sessions.aid, authors.seclev, section, url","sessions, authors",
		"sessions.aid=authors.aid AND session=".$dbh->quote($session));

	if($c and not ($aid, $seclev,$section,$url)=$c->fetchrow_array) {
		($aid,$seclev,$section,$url)=("",0,"","");
	} else {
		sqlUpdate("sessions","session=".$dbh->quote($session),(-lasttime=>'now()'));
	}
	$c->finish();
	return ($aid, $seclev,$section,$url);
}

sub setadmininfo
{
	my ($aid, $pwd)=@_;
	my $seclev=0;

	my $c=$dbh->prepare("SELECT aid,seclev FROM authors
				WHERE aid=".$dbh->quote($aid)." 
				  AND pwd=".$dbh->quote($pwd));
	$c->execute();
	if(($aid,$seclev)=$c->fetchrow) {
		my $sid=generatesession($aid);
		$dbh->do("INSERT into sessions 
			  VALUES('$sid','$aid', now(), now(),'')");
		print "Set-Cookie: ".$query->cookie(-name=>'session',
                                            -value=>$sid,
                                            -expires=>'+10y')."\n";
	} else {
		($aid,$seclev)=("",0);
	}
	$c->finish();
	return ($aid,$seclev);

}

sub getfile
{
	my $f=$_[0];
	open FH,$f;
	my $r="";
	while(<FH>) { $r.=$_; }
	close FH;
	return $r;
}


sub geturl {
  use LWP::UserAgent;
  use HTTP::Request;
  use URI::Escape;

  my $ua = new LWP::UserAgent;
  my $request = new HTTP::Request('GET', $_[0]);

  my $result = $ua->request($request);
  if ($result->is_success) { return $result->content;
  } else { return 0; }
}

        
sub prog2file
{
	my ($c, $f)=@_;
	my $d=`$c`;
	$d=~s/[\t\n\r\s ]+/ /g;
	if(length($d) > 0) {
		open F, ">$f";
		print F $d;
		close F;
		return "1";
	} else {
		return "0";
	}
}


sub url2file
{
	my ($u, $f)=@_;
	my $d=geturl($u);
	if($d ne "0") {
		open FH,">$f";
		print FH $d;
		close FH;
	}
}


sub userLogin
{
        my($name,$passwd,$expires)=@_;
        my $c=$dbh->prepare("SELECT uid FROM users
                                WHERE passwd=".$dbh->quote(substr($passwd,0,12))." 
				  and nickname=".$dbh->quote($name));
        $c->execute();
        my $uid;
        if(($uid)=$c->fetchrow) {
		my $cookie=$uid."::".$passwd;
		$cookie=~s/(.)/sprintf("%%%02x",ord($1))/ge;
		my $expires='+3h' unless $expires eq "session";
		print "Set-Cookie: ".$query->cookie(-name=>'user',
                                            -value=>$cookie,
                                            -expires=>'+10y')."\n";
                                        
        } else {
                $uid=-1;
        }

        $c->finish();
        return ($uid,$passwd);
}
             

sub userCheckCookie
{
        my($cookie)=@_;
	$cookie=~s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;     
        my($uid,$passwd)=split("::",$cookie);
        my $c=sqlSelectMany("uid","users",
                       "uid=".$dbh->quote($uid)." and passwd=".$dbh->quote($passwd));
	if ($c) { $uid=-1 unless $c->fetchrow(); }
        $c->finish() if $c;
        return ($uid, $passwd);
}


sub getUser
{
        my($uid,$passwd)=@_;
        return sqlSelectHash("*","users","uid=".$dbh->quote($uid));
}

	

sub getblock
{
	my ($bid)=@_;
	my ($block)=sqlSelect("block","blocks","bid='$bid'");
	return $block;
}


sub getsid
{
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
	$year += 1900;
        my $sid=sprintf("%02d/%02d/%02d",$year,$mon+1,$mday)."/".
             sprintf("%02d%0d2%02d",$hour,$min,$sec);
	return $sid;
}

sub getsiddir
{
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
	$year += 1900;
        my $sid=sprintf("%02d/%02d/%02d",$year,$mon+1,$mday)."/";
	return $sid;
}


sub writelog
{
     my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =localtime;
     my $l=sprintf("log%02d%02d%04d.txt",$mon+1,$mday,$year+1900);

     if (open(FHandle, ">>$datadir/logs/".$l)){
              print (FHandle $ENV{REMOTE_ADDR}."\t".localtime(time)."\t".
                $ENV{HTTP_USER_AGENT}."\t".join("\t",@_)."\n");
     }         
}


sub latestpoll
{
	my ($qid)=sqlSelect("qid","pollquestions","","ORDER BY date DESC LIMIT 1");
	return $qid;
}


sub pollbooth
{
        my $qid=@_[0];
	if(not defined $qid) { ($qid)=getvar("currentqid"); }
        my $cursor = $dbh->prepare( "
                SELECT question,answer,aid  from pollquestions, pollanswers
                WHERE pollquestions.qid=pollanswers.qid AND
                        pollquestions.qid='$qid'
                ORDER BY pollanswers.aid
                ");
        $cursor->execute;

        my $tablestuff;
	my $x=0;
        while (my ($question, $answer, $aid) = $cursor->fetchrow) {
                if($x==0) { 
                	$tablestuff="<FORM action=\"$rootdir/pollBooth.pl\">
                	<INPUT type=hidden name=qid value=\"$qid\">
                	<B>$question</B>"; 
			$x++;
		}
                $tablestuff.= "<BR><INPUT type=radio name=aid
value=$aid>$answer";
        }
	my ($voters)=sqlSelect("voters","pollquestions"," qid='$qid'");
	my ($comments)=sqlSelect("count(*)","comments"," sid='$qid'");
        $tablestuff.= "<BR><INPUT type=submit value=Vote> [ 
                <A href=$rootdir/pollBooth.pl?qid=$qid;aid=-1><B>Results</B></A> | 
                <A href=$rootdir/pollBooth.pl><B>Polls</B></A> ] <BR>
		Votes:<B>$voters</B> | Comments:<B>$comments</B>
	</FORM>";
        fancybox(200,"Poll",$tablestuff,"c");
        $cursor->finish;
}




# A Batch of Useful SQL/Perl Functions by Rob 
sub sqlSelectMany
{
	my($select,$from,$where,$other)=@_;

	my $sql="SELECT $select ";
	$sql.="FROM $from " if $from;
	$sql.="WHERE $where " if $where;
	$sql.="$other" if $other;

	# Just make sure...
	$dbh||=sqlconnect();
	my $c=$dbh->prepare($sql);
	if($c->execute()) {
		return $c;
	} else {
		$c->finish();
		print "\n<P><B>sqlSelectMany Error</B> <BR>\n";
		return undef;
		kill 9,$$
	}
}

sub sqlSelect
{
	my ($select, $from, $where, $other)=@_;
	my $sql="SELECT $select ";
	$sql.="FROM $from " if $from;
	$sql.="WHERE $where " if $where;
	$sql.="$other" if $other;
	
	$dbh||=sqlconnect();
	my $c=$dbh->prepare($sql) or die "Sql has gone away\n";
	if(not $c->execute()) {
		print "\n<P><B>SQL Error</B><BR>\n";
		return undef;
	}
	my @r=$c->fetchrow();
	$c->finish();
	return @r;
}

sub sqlSelectHash
{
	my $H=sqlSelectHashref(@_);
	return map { $_ => $$H{$_} } keys %$H;
}


sub sqlSelectHashref
{
	my ($select, $from, $where, $other)=@_;

	my $sql="SELECT $select ";
	$sql.="FROM $from " if $from;
	$sql.="WHERE $where " if $where;
	$sql.="$other" if $other;

	$dbh||=sqlconnect();
	my $c=$dbh->prepare($sql);
	my $H = {};
	return $H unless $c->execute();
	$H=$c->fetchrow_hashref();
	$c->finish();
	return $H;
}

sub sqlUpdate
{
        my($table,$where,%data)=@_;
        my $sql="UPDATE $table SET";
        foreach (keys %data) {
		if (/^-/) {
			s/^-//;
			$sql.="\n  $_ = $data{-$_} ";
                } else { 
			$sql.="\n  $_ = ".$dbh->quote($data{$_}).",";
		}
                
        }
        chop($sql);
        $sql.="\nWHERE $where\n";

	$dbh||=sqlconnect();
        if(!$dbh->do($sql)) {
		open FOO,">>$datadir/logs/updatelog";
		print FOO $sql;
		close FOO;
	}
}


sub sqlInsert
{
        my($table,%data)=@_;
        my($names,$values);

        foreach (keys %data) {
   		if (/^-/) {$values.="\n  ".$data{$_}.","; s/^-//;}
                else { $values.="\n  ".$dbh->quote($data{$_}).","; }
                $names.="$_,";  
        }
        chop($names);
        chop($values);
        my $sql="INSERT INTO $table ($names) VALUES($values)\n";
	$dbh||=sqlconnect();
        if(!$dbh->do($sql)) {
		open FOO,">>$datadir/logs/insertlog";
		print FOO $sql." ".$dbh->errstr;
		close FOO;
	}
}   



sub sqlconnect
{
        $dbh ||= DBI->connect("DBI:mysql:slash", "slash", "wegotitallonUHF");
	# die "Unable to connect to SQL Server" unless $dbh;
	kill 9, $$ unless $dbh;
        return \$dbh;
}     

# Some Random Dave Code:
sub stripByMode
{
	my($str,$fmode,$seclev,@apptag)=@_;

	$str=stripBadHtml($str,$seclev,@apptag);

        if($fmode eq "plaintext" || $fmode eq "exttrans") {
                $str=~s/[\n]/<br>/gi;        # pp breaks
                $str=~s/\<br\>\<br\><br\>/<br><br>/gi;
        } elsif($fmode eq "exttrans") {
                $str=~s/\&/&amp;/g;
                $str=~s/\</&lt;/g;
                $str=~s/\>/&gt;/g;
        } elsif($fmode eq "nohtml") {
		$str=~s/\<(.*?)\>//g;
	}

	return $str;
}

sub stripBadHtml 
{
	my ($str,$seclev,@apptag)=@_;
	
      	$str =~ s/(\S{90})/$1 /g;      
	$str =~ s/<(?!.*?>)//; 
	$str =~ s/<(.*?)>/approvetag($1,@apptag)/sge; #replace tags with approved ones 
	return $str;
}

sub approvetag
{
        my ($tag,@apptag) = @_;

        $tag =~ s/^\s*?(.*)\s*?$/$1/e; #trim leading and trailing spaces

        if (uc(substr ($tag, 0, 2)) eq 'A ')
        {
                $tag =~ s/^.*?href="?(.*?)"?$/A HREF="$1"/i; #enforce "s
                return "<" . $tag . ">";
        }

        foreach my $goodtag (@apptag)
        {
                $tag = uc $tag;
                if ($tag eq $goodtag || $tag eq '/' . $goodtag)
                        {return "<" . $tag . ">";}
                #check against my list of tags
        }
        return "";
} 


# Look and Feel Functions Follow this Point
sub header
{
	my ($title,$section,$mode,$ssi) =@_;
	setupUser($section,$mode);
 	$title=~s/\<(.*?)\>//g;        

	print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0//EN\" \"http://validator.w3.org/sgml-lib/REC-html40-19980424/strict.dtd\"><HTML><HEAD><TITLE>$title</TITLE>\n" if $title;
	if($ssi eq "yes") {
		# Meta Expires Tag
		print "<META NAME=\"EXPIRES\" CONTENT=\"".expireTime()."\">\n";
		ssiHead($section,$mode);
		return;
	}

	my $adhtml=blockCache("advertisement");
	my $header=blockCache($section."_header") || blockCache("header");
	my $menu=blockCache("mainmenu");
	my $menu=prepBlock($menu);
	my $vertmenu = $menu = eval $menu;
	my $horizmenu=$menu;
	$horizmenu=~s/\<BR\>/|/gi;


	my $execme=prepBlock($header);
	print eval $execme;
	print "\nError:$@\n" if $@;
}

sub footer
{
	my ($ssi)=@_;
	if($ssi eq "yes") {
		ssiFoot();
		return;
	} 

	my ($section)=$currentSection;
	my $motd=blockCache("motd");
	my $closelayer="";

	my $block=blockCache($section."_footer") || blockCache("footer");

	my $menu=blockCache("mainmenu");
	my $menu=prepBlock($menu);
	my $vertmenu = $menu = eval $menu;
	my $horizmenu=$menu;
	$horizmenu=~s/\<BR\>/|/gi;

	my $execme=prepBlock($block);
	print eval $execme;
	if($@) { print "Error:$@\n" }
}


sub prepEvalBlock
{
	my ($b)=@_;
	$b=~s/\r//g;
	return $b;
}

sub prepBlock
{
	my ($b)=@_;
	$b=~s/\r//g;
	$b=~s/"/\\"/g;
	$b="\"$b\";";
	return $b;
}

sub nukeBlockCache
{
	%blockBank=();
}

sub blockCache
{
	my ($bid)=@_;
	($blockBank{$bid}) = sqlSelect("block","blocks","bid='$bid'") 
		unless ($blockBank{$bid});
	if(!$blockBank{$bid} or $blockBank{$bid}==-1) {
		$blockBank{$bid}=-1;
		return "";
	} else {
		return $blockBank{$bid};
	}

}


sub titlebar
{
        my ($width, $title) = @_;
	my $block=blockCache($currentSection."_titlebar") || blockCache("titlebar");
      	my $execme=prepBlock($block);
        print eval $execme;
        if($@) { print "\nError:$@\n" }
}


sub fancybox
{
        my ($width, $title, $contents) = @_;
	return unless ($title and $contents);
        my $mainwidth=$width-4;
	my $insidewidth=$mainwidth-8;
        my $block=blockCache($currentSection."_fancybox") || blockCache("fancybox");

        my $execme=prepBlock($block);
        print eval $execme;
        if($@) { print "Error:$@\n" }         
}
                 

sub printComments2 
{
        my ($USER,$sid,$pid,$cid)=@_;

        $$USER{threshold}||="0";
        $pid||="0";
        my $message=blockCache("commentswarning")." <P>\n";
    
        if($$USER{mode} ne "archive") {
             $message.=".<BR>( Switch to <A 
		href=$rootdir/comments.pl?sid=$sid;pid=$pid;threshold=$$USER{threshold};mode=";
	     $message.=$currentMode eq "thread" ? "flat>Flat" : "thread>Threaded";
	     $message.="</A> mode ";
	     $message.=" | <A 
		href=$rootdir/comments.pl?op=post;sid=$sid;pid=$pid>Reply</A>" unless getvar("nocomment");
             $message.= " ) <BR> \&lt;
                        <A href=$rootdir/comments.pl?sid=$sid;pid=$pid;threshold=".
                        ($$USER{threshold}-1).">Down One</A> |
                        This Page's Threshold: $$USER{threshold} |
                        <A href=$rootdir/comments.pl?sid=$sid;pid=$pid;threshold=".
                        ($$USER{threshold}+1).">Up One</A> &gt; <BR>";

             $message.="<FONT size=2>You are logged in as <B><A
                           href=$rootdir/users.pl>$$USER{nickname}</A></B>" if $$USER{uid} > 0;
             $message.=" and have <B>$$USER{points}</B> moderator points
                           left" if $$USER{points};
	     $message.="</FONT><BR>" if $$USER{uid} > 0;
             $message.="<FONT size=2><B>(Warning:this stuff 
			<I>might</I> be beta right now)</B></FONT><BR>";
        }
	my ($commentstatus)=sqlSelect("commentstatus","stories","sid=".$dbh->quote($sid));

        my $strsql="SELECT      cid,date_format(date,\"\%W \%M \%d, \%Y \@\%h:\%i \%p\") as time,
                                name,email,url,subject,comment,
                                nickname,homepage,fakeemail,realname,
                                users.uid as uid,sig,
                                comments.points as points,pid,sid,pid
                           FROM comments,users
                          WHERE sid=".$dbh->quote($sid);
        $strsql.="              AND comments.points >= ".$dbh->quote($$USER{threshold})."
                                AND comments.uid=users.uid
                       ORDER BY cid";
        my $thisComment=$dbh->prepare($strsql);
        $thisComment->execute();

        my $comments;
        while(my $C=$thisComment->fetchrow_hashref()) {
		$$C{commentstatus}=$commentstatus;
                $$C{comment}.="<BR>".$$C{sig};
                $$comments[$$C{cid}]=$C;
                push @{$$comments[$$C{pid}]->{kids}}, $$C{cid};
        }
        $thisComment->finish();

	# Mess with sort order, eg, @$comments[0]->{kids}
	# if($$USER{commentorder} == 1) { Reverse
	# } else { randomize }
	
	my $lvl=0 if $$USER{mode} eq "flat" or $$USER{mode} eq "archive";
	$lvl=1 if $$USER{mode} eq "index";

	print "<form action=\"$rootdir/comments.pl\" method=post><INPUT type=hidden name=sid
value=$sid>\n" if $$USER{seclev} or $$USER{aseclev};       
    	print "<TABLE><TR><TD align=center>$message</TD></TR>\n";

	print "<TR><TD>" if $lvl;
        displayComments($USER,$sid,$pid,$lvl,$comments,$cid);
	print "</TD></TR>" if $lvl;

	# Closing message if there are more than 5 comments
        print "<TR><TD align=center>$message</TD></TR>";
	# if @{$$comments[$pid]->{kids}} > 5;
	print "</TABLE>\n";
        print "<input type=submit name=op value=\"moderate\"></form>\n" if $$USER{seclev};
}

sub displayComments
{
        my($USER,$sid,$pid,$lvl,$comments,$cid)=@_;

	if($cid) {
		my $C=$$comments[$cid];
		dispComment($USER,$C) if $cid;
		# Next and previous.
		my ($n,$p);
		my $sibs=$$comments[$$C{pid}]->{kids};
		for(my $x=0; $x< @$sibs; $x++) {
			($n,$p)=($$sibs[$x+1],$$sibs[$x-1]) if $$sibs[$x] == $cid;
		}
		print "<TR><TD align=center>";


		if($p) {
			my $P=$$comments[$p];
                        print "\&lt;\&lt; <A
href=\"$rootdir/comments.pl?sid=$sid;cid=$$P{cid}\">$$P{subject}</a>
by $$P{nickname} \n|";
		}

		if($$C{pid}) {
			my $P=$$comments[$$C{pid}];
			print " <A href=\"$rootdir/comments.pl?sid=$sid;cid=$$P{pid}\">$$P{subject}</A> by $$P{nickname} \n";
		}
		if($n) {
			my $N=$$comments[$n];
                        print "| <A
href=\"$rootdir/comments.pl?sid=$sid;cid=$$N{cid}\">$$N{subject}</a>
by $$N{nickname} \&gt;\&gt; \n";
		}
		print "<BR><IMG src=\"$imagedir/greendot.gif\" height=1 width=\"400\" vspace=15>";
		print "</TD></TR>\n";
	}

	print "<UL>" if $lvl;
        foreach my $cid (@{$$comments[$pid]->{kids}}) {
                my $C=$$comments[$cid];
                if($lvl<1) {
                        $$C{ppid}=0;
                        dispComment($USER,$C);
			if($$C{kids}) {
                            print "<TR><TD>";
                            my $l=$lvl;
                            $l++ unless $$USER{mode} eq "archive" or $$USER{mode} eq "flat";
                            displayComments($USER,$sid,$$C{cid},$l,$comments);
                            print "<P></TD></TR>\n";
			}
                } else {
			my $pcnt=@{$$comments[$$C{pid}]->{kids} }+0;
                        print "<LI><A
href=\"$rootdir/comments.pl?sid=$sid;cid=$$C{cid}\">$$C{subject}</a>
by $$C{nickname} on $$C{time}<br>\n" if $pcnt > 49;
                        print "<LI><A
href=\"$rootdir/comments.pl?sid=$sid;pid=$$C{pid}\#$$C{cid}\">$$C{subject}</a>
by $$C{nickname} on $$C{time}<br>\n" if $pcnt < 50;

			if($$C{kids}) {
                            displayComments($USER,$sid,$$C{cid},$lvl+1,$comments);
			}
                }
        }                                  
	print "</UL>" if $lvl;
}




sub dispComment 
{
	my($USER, $C)=@_;

	my $subj=$$C{subject};
	my $score=$$C{score};
	my $time=$$C{time};
	my $comment=$$C{comment};
	my $username="";
	$username="<A href=\"mailto:$$C{fakeemail}\">$$C{nickname}</A> 
			<B><FONT size=2>($$C{fakeemail})</FONT></B>" if $$C{fakeemail};
	$username||=$$C{nickname};

	$$C{nickname}=~s/ /+/g;
	my $userinfo;
	$userinfo="(<A href=\"$rootdir/users.pl?op=userinfo;nick=$$C{nickname}\">User 
		Info</A>)" unless $$C{nickname} eq "Anonymous+Coward";

	my $userurl="<A href=\"$$C{homepage}\">$$C{homepage}</A><BR>" if $$C{homepage};
	my $score=" (Score:$$C{points})" if $$C{points};

	my $template=blockCache($currentSection."_comment") || blockCache("comment");

	my $execme=prepBlock($template);
        print eval $execme;
        if($@) { print "\nError:$@\n" }      
	
	if($$USER{mode} ne "archive") {
		my($cid,$sid)=($$C{cid},$$C{sid});
		print "<TR><TD><font size=2> [ ";
		print "<A href=\"$rootdir/comments.pl?op=post;sid=$sid;pid=$cid\">Reply to 
			this</A> " if $$USER{commentstatus}==0;

		# Go to parent
		if($$C{pid} > 0) {
			print " | <A 
			  href=$rootdir/comments.pl?sid=$sid;cid=$$C{pid}";
			print "\#$$C{pid}" if $$C{pid};
			print ">Parent</A>"; 
		}

		if($$USER{seclev}>0) {
			print " | Moderate -<INPUT type=radio name=\"mod_$cid\" value=neg>
<INPUT type=radio name=\"mod_$cid\" CHECKED value=>
<INPUT type=radio name=\"mod_$cid\" value=pos>+ 
| Reparent <INPUT type=radio name=par_$cid value=0 CHECKED> 0
<INPUT type=radio name=par_$cid value=1> 1
<INPUT type=radio name=par_$cid value=top> top ";
		}

		if($$USER{aseclev}>100) {
			print " | cid = $$C{cid} $$C{pid} $$C{ppid} ";
			print " | <A 
			href=\"$rootdir/comments.pl?sid=$sid;cid=$cid;op=delete\">Delete</A>";
			print " <input type=checkbox name=del_$cid> ";
		}
		print " ] </font></TD></TR>\n";
		print "<TR><TD> ";
	}
}


sub dispStory
{
	my($USER,$S,$A,$T,$full)=@_;
	titlebar("99%",$$S{title});

	my $template=blockCache($currentSection."_story") || blockCache("story");

	my $bt=$full?"<P>$$S{bodytext}</P>":"<BR>";
	my $author="<A href=$$A{url}>$$S{aid}</A>";

	# Compatibility layer? :)
	my ($tid,$topicimage,$width,$height,$alttext,$date,$dept,$introtext,$bodytext)=
		($$T{tid},$$T{image},$$T{width},$$T{height},$$T{alttext},$$S{time},
		$$S{dept},$$S{introtext},$bt);	

 	my $execme=prepBlock($template);
        print eval $execme;
	print "\nError:$@\n" if $@;
}

sub displayStory
{
        my ($USER,$sid, $full)=@_;

        my $S=sqlSelectHashref("title,dept,time as sqltime,
			    date_format(time,\"\%W \%M \%d, \%Y \@\%h:\%i \%p\") as time,
			    introtext,sid,commentstatus,
                            bodytext,aid,tid,section,commentcount,displaystatus,writestatus",
                           "stories",
                           "stories.sid=".$dbh->quote($sid));

	my $T=sqlSelectHashref("*","topics","tid=".$dbh->quote($$S{tid}));
	my $A=sqlSelectHashref("*","authors","aid=".$dbh->quote($$S{aid}));

	dispStory($USER,$S,$A,$T,$full);
	return ($S,$A,$T);
}         

sub pollItem
{
       	my ($answer, $imagewidth, $votes, $percent) =@_;

	my $pi=blockCache("pollitem");
	my $execme=prepBlock($pi);
        print eval $execme;
        if($@) { print "\nError:$@\n" }       

}


# Blame Nate for this one :)
sub sendEmail
{
	use Socket;
        my ($addr, $subject, $content) = @_;

        socket (SMTP, 'PF_INET', 'SOCK_STREAM', getprotobyname('tcp'))
                or die "socket $!";
        connect (SMTP, sockaddr_in(25, inet_aton("127.0.0.1")))
                or die "connect $!";

        my $line = <SMTP>;
        send SMTP, "helo localhost\n", 0;
        $line = <SMTP>;
        send SMTP, "MAIL FROM:slashdot\@slashdot.org\n", 0;
        $line = <SMTP>;
        send SMTP, "RCPT TO:$addr NOTIFY=NEVER\n", 0;
        $line = <SMTP>;
        send SMTP, "DATA\n", 0;
        $line = <SMTP>;
        send SMTP, "Subject: $subject\n$content\n.\n", 0;
        $line = <SMTP>;
        send SMTP, "quit\n", 0;
	close(SMTP);
}
                        

sub selectStories
{
	my ($SECT,$FORM,$USER,$limit,$tid)=@_;

	my $s="SELECT sid, section, title, date_format(time,\"W M d h i p\"),
		      commentcount, to_days(time)
	         FROM stories
		WHERE ";
	$s.="	      displaystatus=0 " unless $$FORM{section};
	$s.="	      (displaystatus>=0 AND '$$SECT{section}'=section)" if $$FORM{section};
	$s.="	  AND writestatus >= 0 " unless $$USER{seclev} > 100;
	$s.="     AND $$FORM{issue} >= to_days(time) " if $$FORM{issue};
	$s.="	  AND tid='$tid'" if $tid;
	$s.="	  AND time < now() " unless $$USER{aseclev};
	$s.="	ORDER BY time DESC ";
	$s.="   LIMIT $limit" if $limit;
	$s.="   LIMIT $$SECT{artcount}" unless $limit;

	my $cursor=$dbh->prepare($s);
	$cursor->execute();
	return $cursor;
}

# pass it how many, and what.
sub displayStories
{
	my($USER,$cnt,$FORM,$cursor)=@_;	
	my ($today,$x)=("",0);

	TODAY:while(my ($sid,$thissection,$title,$time,$cc)=$cursor->fetchrow()) {

		my ($S)=displayStory($USER,$sid);
		print linkStory("<B>Read More...</B>",$$FORM{mode},$sid,$thissection);
		if($$S{bodytext} or $cc) {	
			print "<BR><B>(";
			print "$cc comment",
			       $cc>1?"s":"" if $cc;
			print ", " if $$S{bodytext} and $cc;
			print length($$S{bodytext})." bytes in body" 
				if($$S{bodytext});
			if($$USER{seclev}) {
				my ($mods)=sqlSelect("count(lastmod)",
					"comments",
					"sid='$sid' and lastmod>0");
	
				print ", <I>",
				      $mods?$mods:"no",
				      " moderated comment",
				      $mods>1?"s":"",
				      "</I>";
			}
			print ")</B>";
		}

		

		print "<P>";

		my ($w, $m, $d, $h, $min, $ampm)=split(" ",$time);
		$today||=$w;
		last TODAY if (++$x >= $cnt and $today ne $w );
	}
}



sub getOlderStories
{
	my ($SECT,$FORM,$USER,$cursor)=@_;
	my ($today,$stuff);

	$cursor||=selectStories($SECT,$FORM,$USER);
	$cursor->execute();
	while(my ($sid, $section, $title, $time, $commentcount, $day)=$cursor->fetchrow) {
		my ($w, $m, $d, $h, $min, $ampm)=split(" ",$time);
		if($today ne $w) {
			$today=$w;
			$stuff.= "<P><B>";
			$stuff.="<A 
href=$rootdir/index.pl?section=$$SECT{section};issue=$day;mode=$$FORM{mode}>" if $$SECT{issue} > 1;
			$stuff.="<FONT size=4>$w</FONT>";
			$stuff.="</A>" if $$SECT{issue} > 1;
			$stuff.=" $m $d</B>\n";
		}
		$stuff.="<LI>".linkStory($title,$$FORM{mode},$sid,$section)."
			($commentcount)\n";
	}	

	if($$SECT{issue}) {
		# KLUDGE:Should really get previous issue with stories;
		my ($yesterday)=sqlSelect("to_days(now())-1") 
			unless $$FORM{issue} > 1 or $$FORM{issue};
		$yesterday||=int($$FORM{issue})-1;
	
		my $min=$$SECT{artcount}+$$FORM{min};
		$stuff.="<P align=right>" if $$SECT{issue};
		$stuff.="<BR><A 
			href=\"$rootdir/search.pl?section=$$SECT{section};min=$min\"><B>Older 
			Articles</B></A>" if $$SECT{issue}==1 or $$SECT{issue}==3;
		$stuff.="<BR><A
href=\"$rootdir/index.pl?section=$$SECT{section};mode=$$FORM{mode};issue=$yesterday\"><B>Yesterday's 
Edition</B></A>\n" if $$SECT{issue}==2 or $$SECT{issue}==3;
	}
	$cursor->finish();
	return $stuff;

}


sub CLOSE { $dbh->disconnect() if $dbh; }
