# MySQL dump 5.10
#
# Host: localhost    Database: slash
#--------------------------------------------------------
# Server version	3.22.14b-gamma-log

#
# Table structure for table 'authors'
#
CREATE TABLE authors (
  aid char(30) DEFAULT '' NOT NULL,
  name char(50),
  url char(50),
  email char(50),
  quote char(50),
  copy char(255),
  pwd char(10),
  seclev int(11),
  lasttitle char(20),
  section char(20),
  PRIMARY KEY (aid)
);

#
# Dumping data for table 'authors'
#

INSERT INTO authors VALUES ('God','God','http://www.god.org/','http://www.god.org/','','','Townshend',1000000,'',NULL);

#
# Table structure for table 'blocks'
#
CREATE TABLE blocks (
  bid varchar(30) DEFAULT '' NOT NULL,
  block text,
  aid varchar(20),
  seclev int(1),
  PRIMARY KEY (bid)
);

#
# Dumping data for table 'blocks'
#

INSERT INTO blocks VALUES ('features','I suppose it really isn\'t surprising that there\r\nreally isn\'t anything to read right here right now.\r\nBut what do you want from me?  I\'m just a field in a database.\r\nI don\'t write features, I just hog disk space.','',500);
INSERT INTO blocks VALUES ('topics','<TD><A href=\"/~slash/search.pl?topic=slashdot\"><IMG\n			SRC=\"/~slash/images/topics/topicslashdot.gif\" width=100 height=34 \n			border=0 alt=\"Slashdot.org\"></A></TD>\n','',10000);
INSERT INTO blocks VALUES ('slashdot','<LI><A href=http://slashdot.org/articles/99/01/13/1933235.shtml>Sony NOT suing Connectix,and Linux Pre-7 out</A> (10)\n<LI><A href=http://slashdot.org/articles/99/01/13/1825203.shtml>XFree86 3.3.3.1 includes Riva TNT >OPEN SOURCE< code</A> (39)\n<LI><A href=http://slashdot.org/articles/99/01/13/1811201.shtml>Source for Pov-Ray modeller now available!</A> (31)\n<LI><A href=http://slashdot.org/articles/99/01/13/1759230.shtml>India\'s Red Alert - no more US software</A> (73)\n<LI><A href=http://slashdot.org/articles/99/01/13/1641250.shtml>Update from thebazaar</A> (16)\n<LI><A href=http://slashdot.org/articles/99/01/13/154205.shtml>Linux in healthcare computing</A> (34)\n<LI><A href=http://slashdot.org/articles/99/01/13/133215.shtml>Slashdot T-Shirt Update</A> (53)\n<LI><A href=http://slashdot.org/articles/99/01/13/1237236.shtml>Yahoo threatens legal action against Yahooka.com</A> (103)\n<LI><A href=http://slashdot.org/articles/99/01/13/1236222.shtml>Infoworld Article on Linux Growth</A> (11)\n<LI><A href=http://slashdot.org/articles/99/01/13/1229255.shtml>IBM Reconsiders making DB2/Linux Free</A> (25)\n<LI><A href=http://slashdot.org/articles/99/01/13/0931237.shtml>Faster Encryption Algorithm Found By 16 Year Old Girl</A> (237)\n<LI><A href=></A> ()\n <P align=right><A\n			href=\"http://slashdot.org\">Visit Slashdot</A>','',1000);
INSERT INTO blocks VALUES ('quicklinks','<A href=http://slashdot.org>Slashdot</A> is the site that\r\ninspired the page you\'re probably looking at right now.\r\n\r\n<P><A href=http://slashdot.org/slash>Slash</A> is the code\r\nbase that this page- as well as Slashdot itself- is based\r\non.  You can snag it from <A href=ftp://ftp.slashdot.org>my\r\nFTP site</A>.\r\n<P>Have you visited <A href=http://freshmeat.net>Freshmeat</A>\r\nyet today?  What about <A href=http://slashdot.org/malda>My Homepage?</A>\r\n','',10000);
INSERT INTO blocks VALUES ('commentswarning','<FONT size=1>\r\nThese comments are the property of Ford Prefect. You\r\ngot a problem with any of this?  Tough.\r\n</FONT>',NULL,10000);
INSERT INTO blocks VALUES ('postvote','  <P>Thanks for voting.','',10000);
INSERT INTO blocks VALUES ('titlebar','<TABLE width=\"$width\" cellpadding=2 cellspacing=0 border=0 bgcolor=\"#006699\">\r\n<TR>\r\n <TD><FONT color=FFFFFF size=4><B>$title</B></FONT></TD>\r\n </TR>\r\n</TABLE>\r\n',NULL,10000);
INSERT INTO blocks VALUES ('fancybox','<TABLE cellpadding=2 cellspacing=0 border=0 width=\"$width\" align=center>\r\n<TR bgcolor=\"#006699\">\r\n <TD valign=top bgcolor=\"#006699\"> <FONT size=4 color=\"#ffffff\" face=\"arial,helvetica\"><B>$title</B></FONT>\r\n </TD>\r\n</TR><TR><TD bgcolor=\"#cccccc\"><FONT \r\n  color=\"#000000\" size=2>$contents</FONT></TD>\r\n</TR>\r\n</TABLE><P>\r\n',NULL,10000);
INSERT INTO blocks VALUES ('advertisement','<!-- If you needed a banner ad, stick it here -->\r\n',NULL,10000);
INSERT INTO blocks VALUES ('footer','</FONT></TD>\r\n         </TR>\r\n        </TABLE><TABLE cellpadding=0 cellspacing=0 border=0 width=\"99%\"\r\n                align=center    bgcolor=\"ffffff\">\r\n            <TR>\r\n             <TD colspan=3 align=center><IMG src=\"$imagedir/greendot.gif\"\r\n                alt=\"\" width=\"80%\" height=1 hspace=10 vspace=30></TD>\r\n            </TR><TR>\r\n             <TD align=center><FONT size=2 face=\"arial,helvetica\">\r\n  <FORM method=GET action=\"$rootdir/search.pl\">\r\n         <INPUT type=name name=query value=\"\" width=20 size=20 length=20>\r\n        <INPUT type=submit value=\"Search\">\r\n  </FORM>\r\n  </FONT>\r\n  </TD>\r\n  <TD bgcolor=\"#ffffff\" width=25>  &nbsp; </TD>\r\n  <TD align=center>\r\n    <FONT size=2 face=\"arial,helvetica\"><I>This site is based on the Slash Engine</I></FONT><BR>\r\n    <A href=http://slashdot.org><IMG src=$imagedir/slashdotlogo.gif width=100 height=34 border=0></A>\r\n    </FONT>\r\n  </TD></TR>\r\n  <TR><TD colspan=3 align=center>\r\n  <FONT size=1 color=\"#00666\" face=\"arial,helvetica\">\r\n\r\n All trademarks and copyrights on this\r\n  page are owned by their respective companies.  Comments\r\n  are owned by the Poster.\r\n  The Rest © 1999 The Management\r\n</FONT></CENTER>\r\n             </TD>\r\n            </TR>\r\n           </TABLE>\r\n        <CENTER>\r\n          <FONT size=2 color=\"#006666\">\r\n	[ $horizmenu ]\r\n           </FONT>\r\n          </CENTER>\r\n\r\n</BODY>\r\n</HTML>',NULL,10000);
INSERT INTO blocks VALUES ('mainmenu','<FONT size=2><B>         \r\n&nbsp;<A href=$rootdir/search.pl>older stuff</A> <BR>\r\n&nbsp;<A href=$rootdir/submit.pl>submit story</A> <BR>\r\n&nbsp;<A href=$rootdir/users.pl>user account</A> <BR>\r\n&nbsp;<A href=$rootdir/pollBooth.pl>past polls</A> <BR>\r\n&nbsp;<A href=$rootdir/features/index$userMode.shtml>features</A> <BR>\r\n&nbsp;<A href=$rootdir/topics.shtml>topics</A> <BR>\r\n&nbsp;<A href=$rootdir/faq.shtml>faq</A> <BR>\r\n&nbsp;<A href=$rootdir/hof.shtml>hof</A>\r\n</B></FONT>\r\n',NULL,10000);
INSERT INTO blocks VALUES ('header','</HEAD>\r\n<BODY bgcolor=\"#000000\" text=\"#333333\" link=\"#006699\" vlink=\"#003366\">\r\n$adhtml\r\n<TABLE bgcolor=\"#ffffff\" cellpadding=0 cellspacing=0 border=0 width=\"99%\" align=center>\r\n <TR>\r\n  <TD valign=top align=left><A href=$rootdir/index$userMode.shtml><IMG\r\n   src=\"$imagedir/title.gif\" width=275 height=72 border=0\r\n   alt=\"Welcome to Slashdot\"></a><BR>\r\n[ $horizmenu ]\r\n</TD>\r\n</TR></TABLE>\r\n<TABLE width=\"99%\" align=center cellpadding=0 cellspacing=0 \r\n  border=0 bgcolor=ffffff><TR><TD>\r\n <P> <BR> </TD><TD valign=top align=left><FONT color=\"#000000\">\r\n',NULL,10000);
INSERT INTO blocks VALUES ('admin_header','</HEAD>\r\n<BODY bgcolor=000000 text=333333 link=006699 vlink=003399>\r\n<TABLE width=99% align=center cellpadding=0 cellspacing=0 \r\n  border=0 bgcolor=ffffff><TR>\r\n<TD valign=top><IMG src=$imagedir/slcblack.gif></TD><TD bgcolor=006699 align=right><FONT size=4 color=ffffff><B>back<I>Slash</I>: $sitename Administration </B></FONT></TD></TR>\r\n<TR><TD valign=top>$vertmenu\r\n <P> <BR> </TD><TD valign=top align=left><FONT color=000000>\r\n',NULL,10000);
INSERT INTO blocks VALUES ('pollitem','<TR>\r\n <TD width=100 align=right>$answer &nbsp;</TD>\r\n <TD width=450><NOBR><IMG src=$imagedir/mainbar.gif height=20\r\n    width=$imagewidth> $votes /\r\n   <FONT color=006699>$percent%</FONT></NOBR>\r\n  </TD>\r\n</TR>',NULL,10000);
INSERT INTO blocks VALUES ('story','<A href=\"$rootdir/search.pl?topic=$tid\"><IMG\r\n  src=\"$imagedir/topics/$topicimage\" width=$width height=$height\r\n  border=0 alt=\"$alttext\" align=right hspace=20 vspace=10></A>\r\n<B>Posted by $author on $date</B><BR>\r\n<FONT size=2><B>from the $dept dept.</B></FONT><BR>\r\n$introtext\r\n$bodytext',NULL,10000);
INSERT INTO blocks VALUES ('comment','<TR><TD bgcolor=cccccc><A name=\"$$C{cid}\"><B>$subj</B></A> $score<BR>\r\n  by $username on $time\r\n<BR>\r\n  $userinfo $userurl\r\n</TD></TR>\r\n<TR>\r\n  <TD>$comment</TD>\r\n</TR>   ',NULL,10000);
INSERT INTO blocks VALUES ('submit_before','<P>Submit a story why doncha?',NULL,1000);
INSERT INTO blocks VALUES ('submit_after','Thanks for the submission.',NULL,1000);
INSERT INTO blocks VALUES ('newusermsg','The user account \'$name\' on http://slashdot.org has this email\r\nassociated with it.  A web user from $ENV{REMOTE_ADDR} has\r\njust requested that $name\'s password be sent.  It is \'$passwd\'.\r\n\r\n--The Management',NULL,1000);
INSERT INTO blocks VALUES ('admin_titlebar','<TABLE width=\"$width\" cellpadding=2 cellspacing=0 border=0 bgcolor=\"#006699\">\r\n<TR>\r\n <TD><FONT color=FFFFFF size=4><B>$title</B></FONT></TD>\r\n </TR>\r\n</TABLE>\r\n',NULL,10000);
INSERT INTO blocks VALUES ('index','header($pagetitle,$$SECT{section},$$FORM{mode},$$FORM{ssi});\r\nmy $stories=selectStories($SECT,$FORM,$USER);\r\ndisplayStories($USER,$$SECT{mainsize},$FORM,$stories);\r\nprint \"</TD><TD width=210 align=center valign=top>\";\r\ndisplayStandardBlocks($SECT,$FORM,$USER,$stories);\r\nfooter($$FORM{ssi});\r\n',NULL,100000);

#
# Table structure for table 'commentcodes'
#
CREATE TABLE commentcodes (
  code int(1) DEFAULT '0' NOT NULL,
  name char(32),
  PRIMARY KEY (code)
);

#
# Dumping data for table 'commentcodes'
#

INSERT INTO commentcodes VALUES (0,'Comments Enabled');
INSERT INTO commentcodes VALUES (1,'Read-Only');
INSERT INTO commentcodes VALUES (-1,'Comments Disabled');

#
# Table structure for table 'comments'
#
CREATE TABLE comments (
  sid varchar(30) DEFAULT '' NOT NULL,
  cid int(15) DEFAULT '0' NOT NULL,
  pid int(15) DEFAULT '0' NOT NULL,
  date datetime,
  name varchar(50),
  email varchar(50),
  host_name varchar(50),
  url varchar(50),
  rank int(1),
  subject varchar(50) DEFAULT '' NOT NULL,
  comment text NOT NULL,
  pending int(1) DEFAULT '0',
  uid int(1) DEFAULT '-1' NOT NULL,
  points int(1) DEFAULT '0' NOT NULL,
  lastmod int(1) DEFAULT '-1',
  PRIMARY KEY (sid,cid),
  KEY stuff (uid,pid),
  KEY normal (sid,pid,points,uid)
);

#
# Dumping data for table 'comments'
#

INSERT INTO comments VALUES ('band',19,0,'1999-01-13 18:14:33','UNUSED','UNUSED','206.26.120.9','',0,'The Greatest Band of All Time','Of course it\'s The Who.  How could there ever\r<br>be any doubt?',0,1,1,-1);
INSERT INTO comments VALUES ('99/01/13/177245',9,0,'1999-01-13 17:17:15','UNUSED','UNUSED','206.26.120.9','',0,'First Comment','it\'s good to be a deity. ',0,1,1,-1);

#
# Table structure for table 'displaycodes'
#
CREATE TABLE displaycodes (
  code int(1) DEFAULT '0' NOT NULL,
  name char(32),
  PRIMARY KEY (code)
);

#
# Dumping data for table 'displaycodes'
#

INSERT INTO displaycodes VALUES (0,'Always Display');
INSERT INTO displaycodes VALUES (1,'Only Display Within Section');
INSERT INTO displaycodes VALUES (-1,'Never Display');

#
# Table structure for table 'isolatemodes'
#
CREATE TABLE isolatemodes (
  code int(1) DEFAULT '0' NOT NULL,
  name char(32),
  PRIMARY KEY (code)
);

#
# Dumping data for table 'isolatemodes'
#

INSERT INTO isolatemodes VALUES (0,'Part of Site');
INSERT INTO isolatemodes VALUES (1,'Standalone');

#
# Table structure for table 'issuemodes'
#
CREATE TABLE issuemodes (
  code int(1) DEFAULT '0' NOT NULL,
  name char(32),
  PRIMARY KEY (code)
);

#
# Dumping data for table 'issuemodes'
#

INSERT INTO issuemodes VALUES (0,'Neither');
INSERT INTO issuemodes VALUES (1,'Article Based');
INSERT INTO issuemodes VALUES (2,'Issue Based');
INSERT INTO issuemodes VALUES (3,'Both Issue and Article');

#
# Table structure for table 'maillist'
#
CREATE TABLE maillist (
  code int(1) DEFAULT '0' NOT NULL,
  name char(32),
  PRIMARY KEY (code)
);

#
# Dumping data for table 'maillist'
#

INSERT INTO maillist VALUES (0,'Don\'t Email');
INSERT INTO maillist VALUES (1,'Email Headlines Each Night');

#
# Table structure for table 'pollanswers'
#
CREATE TABLE pollanswers (
  qid char(20) DEFAULT '' NOT NULL,
  aid int(11) DEFAULT '0' NOT NULL,
  answer char(255),
  votes int(11),
  PRIMARY KEY (qid,aid)
);

#
# Dumping data for table 'pollanswers'
#

INSERT INTO pollanswers VALUES ('band',1,'The Who',99999);
INSERT INTO pollanswers VALUES ('band',0,'The Stones',1);
INSERT INTO pollanswers VALUES ('band',2,'The Beatles',1);

#
# Table structure for table 'pollquestions'
#
CREATE TABLE pollquestions (
  qid char(20) DEFAULT '' NOT NULL,
  question char(255) DEFAULT '' NOT NULL,
  voters int(11),
  date datetime,
  PRIMARY KEY (qid)
);

#
# Dumping data for table 'pollquestions'
#

INSERT INTO pollquestions VALUES ('band','Greatest Band of All Time',100002,'1999-01-12 20:31:30');

#
# Table structure for table 'pollvoters'
#
CREATE TABLE pollvoters (
  qid char(20) DEFAULT '' NOT NULL,
  id char(30),
  time datetime,
  uid int(1)
);

#
# Dumping data for table 'pollvoters'
#


#
# Table structure for table 'postmodes'
#
CREATE TABLE postmodes (
  code char(10) DEFAULT '' NOT NULL,
  name char(32),
  PRIMARY KEY (code)
);

#
# Dumping data for table 'postmodes'
#

INSERT INTO postmodes VALUES ('plaintext','Plain Old Text');
INSERT INTO postmodes VALUES ('html','HTML Formatted');
INSERT INTO postmodes VALUES ('exttrans','Extrans (html tags to text)');

#
# Table structure for table 'sectionblocks'
#
CREATE TABLE sectionblocks (
  section varchar(30) DEFAULT '' NOT NULL,
  bid varchar(15) DEFAULT '' NOT NULL,
  ordernum int(11),
  title varchar(128),
  PRIMARY KEY (section,bid)
);

#
# Dumping data for table 'sectionblocks'
#

INSERT INTO sectionblocks VALUES ('index','quicklinks',2,'Quick Links');
INSERT INTO sectionblocks VALUES ('index','features',1,'<A href=\"features\"><FONT color=ffffff>Features</FONT></A>');
INSERT INTO sectionblocks VALUES ('index','slashdot',3,'<A href=http://slashdot.org><FONT color=ffffff>Slashdot</FONT></A>');

#
# Table structure for table 'sections'
#
CREATE TABLE sections (
  section char(30) DEFAULT '' NOT NULL,
  artcount int(11),
  title char(64),
  qid char(20) DEFAULT '' NOT NULL,
  isolate int(1),
  issue int(1),
  cdate timestamp(14),
  PRIMARY KEY (section)
);

#
# Dumping data for table 'sections'
#

INSERT INTO sections VALUES ('articles',30,'Articles','',0,0);
INSERT INTO sections VALUES ('features',21,'Features','eyesight',0,1);
INSERT INTO sections VALUES ('',30,'All Sections','',0,0);

#
# Table structure for table 'sessions'
#
CREATE TABLE sessions (
  session char(20) DEFAULT '' NOT NULL,
  aid char(30),
  logintime datetime,
  lasttime datetime,
  lasttitle char(20),
  PRIMARY KEY (session)
);

#
# Dumping data for table 'sessions'
#

INSERT INTO sessions VALUES ('Go0DMljNL7DTE','God','1999-01-13 17:05:36','1999-01-13 18:18:54','Congratulations on I');

#
# Table structure for table 'sortcodes'
#
CREATE TABLE sortcodes (
  code int(1) DEFAULT '0' NOT NULL,
  name char(32),
  PRIMARY KEY (code)
);

#
# Dumping data for table 'sortcodes'
#

INSERT INTO sortcodes VALUES (0,'Oldest First');
INSERT INTO sortcodes VALUES (1,'Newest First');
INSERT INTO sortcodes VALUES (2,'Random');

#
# Table structure for table 'statuscodes'
#
CREATE TABLE statuscodes (
  code int(1) DEFAULT '0' NOT NULL,
  name char(32),
  PRIMARY KEY (code)
);

#
# Dumping data for table 'statuscodes'
#

INSERT INTO statuscodes VALUES (-1,'Pending');
INSERT INTO statuscodes VALUES (1,'Refreshing');
INSERT INTO statuscodes VALUES (0,'Normal');
INSERT INTO statuscodes VALUES (10,'Archive');

#
# Table structure for table 'stories'
#
CREATE TABLE stories (
  sid varchar(20) DEFAULT '' NOT NULL,
  tid varchar(20) DEFAULT '' NOT NULL,
  aid varchar(30) DEFAULT '' NOT NULL,
  commentcount int(1) DEFAULT '0',
  title varchar(100),
  dept varchar(100),
  time datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  introtext text,
  bodytext text,
  writestatus int(1) DEFAULT '0' NOT NULL,
  hits int(1) DEFAULT '0' NOT NULL,
  section varchar(15) DEFAULT '' NOT NULL,
  displaystatus int(1) DEFAULT '0' NOT NULL,
  commentstatus int(1),
  snum mediumint(8) unsigned DEFAULT '0' NOT NULL auto_increment,
  PRIMARY KEY (sid),
  KEY normal (displaystatus,writestatus,section,time),
  KEY snum (snum),
  KEY stories_time_ndx (time)
);

#
# Dumping data for table 'stories'
#

INSERT INTO stories VALUES ('99/01/13/177245','slashdot','God',1,'Congratulations on Installing Slash','betcha-you-think-you\'re-hot-stuff','1999-01-13 17:07:45','You\'ve done it!  If you\'re seeing this on \'index.pl\' then\r\nyou\'re probably basically done.  You can now login to \'admin.pl\'\r\n(the default password is \'God\' password is \'Townshend\').  You\'ll\r\nprobably want to start by creating a new user account, deleting\r\nGod,  posting your own story, and then editing the \'Blocks\'\r\ntable to create customized Header, Footer, Titlebar and Fancybox\r\ncontent.  Then you\'re site won\'t look dumb.','',0,0,'articles',0,0);

#
# Table structure for table 'submissions'
#
CREATE TABLE submissions (
  subid varchar(15) DEFAULT '' NOT NULL,
  email varchar(50),
  name varchar(50),
  time datetime,
  subj varchar(50),
  story text,
  tid varchar(20),
  note varchar(30),
  section varchar(20),
  PRIMARY KEY (subid)
);

#
# Dumping data for table 'submissions'
#

INSERT INTO submissions VALUES ('173721.11399','god@god.net','God','1999-01-13 17:37:21','Hey My Story!','Post it dammit!  I dare ya!  Click that little\r\npreview button there and (Tada!) you\'re in the\r\nstory editor.  Then it\'s just one click away from\r\nfront page news... it\'s almost <I>too</I> easy.','news',NULL,'articles');

#
# Table structure for table 'topics'
#
CREATE TABLE topics (
  tid char(20) DEFAULT '' NOT NULL,
  image char(30),
  alttext char(40),
  width int(11),
  height int(11),
  cdate timestamp(14),
  PRIMARY KEY (tid)
);

#
# Dumping data for table 'topics'
#

INSERT INTO topics VALUES ('news','topicnews.gif','News',34,44);
INSERT INTO topics VALUES ('slashdot','topicslashdot.gif','Slashdot.org',100,34);
INSERT INTO topics VALUES ('','topicslashdot.gif','All Topics',100,34);

#
# Table structure for table 'users'
#
CREATE TABLE users (
  uid int(11) DEFAULT '0' NOT NULL,
  nickname char(50),
  realname char(50),
  realemail char(50),
  fakeemail char(50),
  homepage char(100),
  passwd char(12),
  mode char(10),
  posttype char(10),
  bio char(255),
  sig char(160),
  maillist int(1),
  mailreplies int(1),
  seclev int(1),
  threshold int(1),
  score int(1),
  points int(1),
  commentsort int(1) DEFAULT '0',
  defaultpoints int(1) DEFAULT '1',
  PRIMARY KEY (uid)
);

#
# Dumping data for table 'users'
#

INSERT INTO users VALUES (1,'God',NULL,'malda@slashdot.org',NULL,NULL,'rYOhTt9x',NULL,NULL,NULL,NULL,0,0,0,0,0,0,0,1);
INSERT INTO users VALUES (-1,'Anonymous',NULL,NULL,NULL,NULL,'',NULL,NULL,NULL,NULL,0,0,0,0,0,0,0,1);

#
# Table structure for table 'vars'
#
CREATE TABLE vars (
  name char(32) DEFAULT '' NOT NULL,
  value char(127),
  description char(127),
  PRIMARY KEY (name)
);

#
# Dumping data for table 'vars'
#

INSERT INTO vars VALUES ('rootdir','/~slash','root URL for site');
INSERT INTO vars VALUES ('imagedir','/~slash/images','URL where images are located');
INSERT INTO vars VALUES ('datadir','/home/slash','directory on your server where everything /is/');
INSERT INTO vars VALUES ('writestatus','0','Simple Boolean to determine if homepage needs rewriting');
INSERT INTO vars VALUES ('currentqid','band','The Current Question on the homepage pollbooth');
INSERT INTO vars VALUES ('totalhits','0','Total number of hits the site has had thus far');
INSERT INTO vars VALUES ('basedir','/home/slash/public_html','Web Base Directory');
INSERT INTO vars VALUES ('slogan','I Cloned Slashdot.  Neat.','gotta have a slogan :)');
INSERT INTO vars VALUES ('defaultwritestatus','1','Default write status for newly created articles');
INSERT INTO vars VALUES ('defaultdisplaystatus','0','Default display status...');
INSERT INTO vars VALUES ('sitename','SlashSite','yikes.');
INSERT INTO vars VALUES ('commentsPerPoint','50','For every X comments, valid users get a Moderator Point');
INSERT INTO vars VALUES ('totalComments','2','Total number of comments posted');
INSERT INTO vars VALUES ('maxPoints','100','maximum number of points a user can have');
INSERT INTO vars VALUES ('today','730132','Today converted to days past a long time ago');
INSERT INTO vars VALUES ('commentstatus','0','default comment code');
INSERT INTO vars VALUES ('defaultcommentstatus','0','default code for article comments- normally 0=posting allowed.');

