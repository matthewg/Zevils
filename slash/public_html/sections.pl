#!/usr/bin/perl


my $r = Apache->request unless $ENV{SLASH_UID};

use DBI;
use FindBin qw($Bin);
use lib "$Bin/..";
use strict;   
use Slash;

sub main
{
        $dbh ||= sqlconnect();
	my ($FORM,$USER)=getSlash($r);

 	header("Section Editor","admin");
	if($$USER{aseclev} > 100) {
		adminMenu($USER);
	} else { 
		print "<PRE>
         I woke up in the Soho bar when a policeman knew my name. He said,
         \"You can go sleep at home tonite if you can get up and walk away.\"
         I staggered back to the underground and a breeze threw back my
         head. I remember throwing punches around and preachin' from my chair.
                         From 'Who Are You' by God (aka Pete Townshend)<BR></PRE>";
		footer();
		return 
	}

	my $op=$$FORM{op};
	my $seclev=$$USER{aseclev};
	if($op eq "rmsub" and $seclev > 99) {
  	} elsif((not defined $op or $op eq "list") and $seclev > 499) {
		titlebar("100%","Sections");
		listSections($USER,$FORM);
	} elsif($op eq "addsection") {
		titlebar("100%","Added Section");
		addSection($$FORM{section});
		listSections($USER,$FORM);
	} elsif($op eq "rmsection") {
		titlebar("100%","Dropped Section");
		delSection($$FORM{section});
		listSections($USER,$FORM);
	} elsif($op eq "editsection") {
		titlebar("100%","Editing $$FORM{section}");
		editSection($seclev,$$FORM{section});
		# Edit Section
	} elsif($op eq "savesection") {
		titlebar("100%","Saving $$FORM{section}");
		saveSection($FORM);
		listSections($USER,$FORM);
	} elsif($op eq "addblock") {
		titlebar("100%","Adding $$FORM{newbid}");
		addSectionBlock($$FORM{section},$$FORM{newbid});
		editSection($seclev,$$FORM{section});
	} elsif($op eq "rmblock") {
		titlebar("100%","Dropping $$FORM{bid}");
		dropSectionBlock($$FORM{section},$$FORM{bid});
		editSection($seclev,$$FORM{section});
	}
	footer();

}


sub listSections
{
	my($USER,$FORM)=@_;
	if($$USER{asection}) {
		editSection($$USER{aseclev},$$USER{asection});
		return;
	}

	my $c=$dbh->prepare("SELECT section,title FROM sections ORDER BY section");
	$c->execute();
	print "<B>";
	while(my($section,$title)=$c->fetchrow()) {
		print "<P><A 
		href=$ENV{SCRIPT_NAME}?section=$section;op=editsection>$section</A> $title"
			if $section;
	}
	$c->finish();
	print "</B>";
	# New section Form
	print "<FORM action=$ENV{SCRIPT_NAME}>
		<INPUT type=hidden name=op value=addsection>
		<INPUT type=text name=section>
		<INPUt type=submit value=\"Add Section\">
		</FORM>";

}


sub delSection
{
	my($section)=@_;
	$dbh->do("DELETE from sections WHERE section='$section'");
	print "Delete $section <BR>";
}

sub addSection
{
	my($section)=@_;
	$dbh->do("INSERT into sections (section) VALUES('$section')");
	print "Inserted $section <BR>";
}


sub editSection
{
	my($seclev,$section)=@_;
	
	my($artcount,$title,$qid,$isolate,$issue)=sqlSelect("artcount,title,qid,isolate,issue",
		"sections","section='$section'");
	print "<FORM action=$ENV{SCRIPT_NAME} method=post>
		<INPUT type=hidden name=section value=$section>
		[ 
	<A href=$rootdir/admin.pl?section=$section>Stories</A> |
	<A href=$rootdir/submit.pl?section=$section;op=list>Submissions</A> |
	<A href=$rootdir/index.pl?section=$section>Preview</A> |
	<A href=$rootdir/admin.pl?op=blocked;bid=$section>Default Block</A> |
	<A href=$rootdir/admin.pl?op=blocked;bid=$section"."_index>Index </A> (ignore) |
	<A href=$rootdir/admin.pl?op=blocked;bid=$section"."_header>Header</A> |
	<A href=$rootdir/admin.pl?op=blocked;bid=$section"."_footer>Footer</A> |	
	<A href=$rootdir/admin.pl?op=blocked;bid=$section"."_fancybox>Fancybox</A> |	
	<A href=$rootdir/admin.pl?op=blocked;bid=$section"."_titlebar>TitleBar</A> |	
	<A href=$rootdir/admin.pl?op=blocked;bid=$section"."_story>Story</A> |	
	<A href=$rootdir/admin.pl?op=blocked;bid=$section"."_comment>Comment</A> |	
		<A href=$ENV{SCRIPT_NAME}?section=$section;op=rmsection>delete</A> 
		]
		<P><B>Article Count</B> (how many articles to display on section index)
		<BR><INPUT type=text name=artcount size=4 value=$artcount> 1/3rd of these will display intro text, 2/3rds just headers
		<P><B>Title</B>
		<BR><INPUT type=text name=title size=30 value=\"$title\"><BR>";
	selectGeneric("pollquestions","qid","qid","question",$qid,
			"","date DESC",25);
	selectGeneric("isolatemodes","isolate","code","name",$isolate);
	selectGeneric("issuemodes","issue","code","name",$issue);
	print "	<BR><INPUT type=submit name=op value=savesection>
		</FORM>";
	

}

sub saveSection
{
	my($FORM)=@_;
	print "Saving $$FORM{section}<BR>";
	#addSectionBlock($$FORM{section},$$FORM{newblock});
	sqlUpdate("sections","section=".$dbh->quote($$FORM{section}),(artcount=>$$FORM{artcount},title=>$$FORM{title},
		qid=>$$FORM{qid},isolate=>$$FORM{isolate},issue=>$$FORM{issue}));
}

sub dropSectionBlock
{
	my($section,$bid)=@_;
	$dbh->do("DELETE from sectionblocks WHERE section=".$dbh->quote($section)." 
			and bid=".$dbh->quote($bid));
	print "Removed $bid from $section<BR>";
}

sub addSectionBlock
{
	my($section,$bid)=@_;
	if(!$section or !$bid) { return }
	sqlInsert("sectionblocks",section=>$section, bid=>$bid, ordernum=>10, 
		title=>'This is a dumb title');
	print "Inserted $bid into $section<BR>";

}



main;
$dbh->disconnect() if $dbh;
