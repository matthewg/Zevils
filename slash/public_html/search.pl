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
        $dbh||=sqlconnect();
        my ($FORM,$USER)=getSlash($r);

	header("$sitename:Search $$FORM{query}",$$FORM{section});
	titlebar("99%","Searching $$FORM{query}");

	$$FORM{min}||=0;
	$$FORM{max}||=$$FORM{min}+30; 

	searchForm($FORM,$USER);

	if($$FORM{op} eq "comments") {
		commentSearch($FORM,$USER);
	} elsif($$FORM{op} eq "users") {
		userSearch($FORM,$USER);
	} else {
		storySearch($FORM,$USER);
	}
	
}

sub upanddown
{
	my $char=@_[0];
	return "[".uc($char).lc($char)."]";
}

sub regexify
{
	my $in=@_[0];
	$in=~s/([A-Za-z])/upanddown($1)/ge;
	$in=~s/(\s+?)/ /g;
#	$in=~s/"(.*?)"/(s| |_|g)/ge;	
#	my @t=split(" ",$in);
#	return return "(".join(")+(",@t).")+";
	return $in;
}

sub searchForm
{
	my($FORM,$USER)=@_;
	my $SECT=getSection($$FORM{section});

	my $t=lc($sitename);
	$t=$$FORM{topic} if $$FORM{topic};
	my $tref=sqlSelectHashref("width,height,alttext,image","topics","tid='$t'");
	print "<IMG src=\"$imagedir/topics/$$tref{image}\"
			ALIGN=right BORDER=0 ALT=\"$$tref{alttext}\"
			HSPACE=30 VSPACE=10 WIDTH=$$tref{width} HEIGHT=$$tref{height}>

	<FORM action=\"$ENV{SCRIPT_NAME}\" method=POST>
		<INPUT type=text name=query value=\"$$FORM{query}\">
		<INPUT type=submit value=\"Search\">\n";

	my %ch;
	$$FORM{op}||="stories";
	$ch{$$FORM{op}}="CHECKED";
	print "<INPUT type=radio name=op value=stories $ch{stories}> Stories";
	print "<INPUT type=radio name=op value=comments $ch{comments}> Comments";
	print "<INPUT type=radio name=op value=users $ch{users}> Users";
	print "<BR>";
	if($$FORM{op} eq "stories") {
		#$$FORM{topic}||="";
		selectTopic("topic",$$FORM{topic});

		$t=$$FORM{author};
		$t||="All Authors";
		selectGeneric("authors","author","aid","aid",$t);
	} elsif($$FORM{op} eq "comments") {
		print "Threshold <INPUT type=text size=3 name=threshold value=$$USER{threshold}>";
	}

	selectSection("section",$$FORM{section},$SECT) unless $$FORM{op} eq "users";
	
	print "<P></FORM>";
}


sub commentSearch
{
	my($FORM,$USER)=@_;

	print "<P>This search covers the name, email, subject and contents of
           each of the last 30,000 or so comments posted.  Older comments
	   are removed and currently only visible as static HTML.<P>";
	
	$$FORM{min}=int($$FORM{min});
	my $prev=$$FORM{min}-20;
	if($prev >=  0) {
		print "<A
	href=\"$ENV{SCRIPT_NAME}?section=$$FORM{section};op=$$FORM{op};author=$$FORM{author};topic=$$FORM{topic};min=$prev;query=$$FORM{query}\"><P><B>$$FORM{min} previous matches...</b></A><P>"; 
	}
	
	# select comment ID, comment Title, Author, Email, link to comment
        # and SID, article title, type and a link to the article
	my $sqlquery="SELECT section, stories.sid, aid, title, 
			     pid, subject, 
			     date_format(date,\"\%W \%M \%D \%Y \@h:m\"),
			     date_format(time,\"\%W \%M \%D \%Y \@h:m\"), uid, cid
		        FROM stories, comments
		       WHERE stories.sid=comments.sid  and points >= $$USER{threshold} ";
	my $q=$dbh->quote(regexify($$FORM{query}));

	$sqlquery.="AND section=".$dbh->quote($$FORM{section}) if $$FORM{section};
	$sqlquery.="AND (subject regexp $q
		     OR comment regexp $q
		     OR name regexp $q
		     OR email regexp $q)" if $$FORM{query};

	$sqlquery.=" ORDER BY time DESC LIMIT $$FORM{min},20 ";

	my $cursor=$dbh->prepare($sqlquery);
	$cursor->execute;

	my $x=$$FORM{min};
	while(my ($section, $sid, $aid, $title, $pid, $subj, $sdate, $cdate, $uid, $cid) = 
		$cursor->fetchrow) {

		$x++;
		my ($cname,$cemail)=sqlSelect("nickname,fakeemail","users","uid=$uid");
		print "<BR><B>$x </B>
		       <A href=comments.pl?sid=$sid;pid=$pid\#$cid>$subj</A> 
		       by <A href=mailto:$cemail>$cname</A> on $cdate<BR>
		       <FONT size=2>attached to 
		       <A href=$section/$sid.shtml>$title</A> 
		       posted on $sdate by $aid</FONT><BR>";
	}
	$cursor->finish();

	print "No Matches Found for your query" unless ($x > 0 or $$FORM{query});
	
	my $remaining="";
	print "<A
	href=\"$ENV{SCRIPT_NAME}?section=$$FORM{section};op=$$FORM{op};author=$$FORM{author};topic=$$FORM{topic};min=$x;query=$$FORM{query}\"><P><B>$remaining Matches Left</b></A>" 
		unless $x-$$FORM{min}<20;
	writelog("search",$ENV{query});
	footer();

}



sub userSearch
{
	my ($FORM,$USER)=@_;

	my $prev=int($$FORM{min})-30;
	if($prev >=  0) {
		print "<A
	href=\"$ENV{SCRIPT_NAME}?section=$$FORM{section};op=$$FORM{op};min=$prev;query=$$FORM{query}\"><P><B>$$FORM{min} previous matches...</b></A><P>"; 
	}
	
	my $q=$dbh->quote(regexify($$FORM{query}));
	print "$q<BR>" if $$USER{uid} == 1;
	my $c=sqlSelectMany ("fakeemail,nickname,uid","users",
			"(fakeemail regexp $q OR nickname regexp $q)",
			"ORDER BY nickname");

	my $total=$c->{rows};
	my ($x,$cnt)=0;
	while(my $U=$c->fetchrow_hashref() ) {
		my $ln=$$U{nickname};
		$ln=~s/ /+/g;
		print "<LI><B><A href=$rootdir/users.pl?nick=$ln>$$U{nickname}</A></B> &nbsp;";
		print "<A href=mailto:$$U{fakeemail}>$$U{fakeemail}</A>" if $$U{fakeemail};
		print " ($$U{uid}) ";
		
		$x++;
	}
	$c->finish();

	print "No Matches Found for your query" if $x<1;

	my $remaining=$total - $$FORM{max};
	print "<A
	href=\"$ENV{SCRIPT_NAME}?op=$$FORM{op};min=$$FORM{max};query=$$FORM{query}\"><P><B>$remaining matches left</b></A>" unless $x<29;

	writelog("search",$ENV{query});
	footer();
}


sub storySearch
{
	my ($FORM,$USER)=@_;

	my $prev=int($$FORM{min})-30;
	if($prev >=  0) {
		print "<A
	href=\"$ENV{SCRIPT_NAME}?section=$$FORM{section};op=$$FORM{op};author=$$FORM{author};topic=$$FORM{topic};min=$prev;query=$$FORM{query}\"><P><B>$$FORM{min} previous matches...</b></A><P>"; 
	}
	
	my $q=$dbh->quote(regexify($$FORM{query}));
	print "$q<BR>" if $$USER{uid} == 1;
	my $normalquery="SELECT authors.aid,title,sid,
			date_format(time,\"\%W \%M \%D \%Y \@h:m\"),
			commentcount,url,stories.section";
	my $cntQuery="SELECT count(*) ";
	my $sqlquery="  FROM stories, authors 
		     WHERE writestatus >= 0 
		       AND stories.aid=authors.aid ";
	$sqlquery.="   AND (title regexp $q OR introtext regexp $q)" if length($$FORM{query}) >1;
	$sqlquery.="   AND authors.aid=\"$$FORM{author}\" " if $$FORM{author};
	$sqlquery.="   AND stories.section=\"$$FORM{section}\" " if $$FORM{section};
	$sqlquery.="   AND tid=\"$$FORM{topic}\" " if $$FORM{topic};
	$sqlquery.=" ORDER BY time DESC LIMIT $$FORM{min},30 ";

	my $c=$dbh->prepare($cntQuery.$sqlquery);
	$c->execute();
	my ($total)=$c->fetchrow();
	$c->finish();

	my $cursor=$dbh->prepare($normalquery.$sqlquery);
	$cursor->execute;
	my ($x,$cnt)=0;
	while(my ($aid, $title, $sid,$time,$commentcount,$url,$section,$cnt) = 
		$cursor->fetchrow) {
		print "<A href=$section/$sid.shtml><B>$title</B></A> 
			by <A href=$url>$aid</A> 
			<FONT size=2>on $time <b>$commentcount</b></FONT><BR>";
		$x++;
	}
	$cursor->finish();

	if($x < 1) {
		print "No Matches Found for your query";
	}
	my $remaining=$total - $$FORM{max};
	#my $remaining;
	print "<A
	href=\"$ENV{SCRIPT_NAME}?section=$$FORM{section};op=$$FORM{op};author=$$FORM{author};topic=$$FORM{topic};min=$$FORM{max};query=$$FORM{query}\"><P><B>$remaining matches left</b></A>" unless $x<29;

	writelog("search",$ENV{query});
	footer();

}


main;
$dbh->disconnect() if $dbh;
1;
