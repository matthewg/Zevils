This version of Slash uses ; instead of & as a seperator for CGI variables in
URLs.  & violates the RFCs, since http://slashdot/foo.pl?bar=baz&buzz=biz,
according to the standard, is asking for the entity (things like &amp; and
&quot;) &buzz, which doesn't exist.  ; avoids the problem and works just fine.

I've also added the stories_time_ndx key to slash.sql.

The other difference between this Slash and 0.3-3 is that newsd is included.

To add newsd support to a slash-site that already has the database structures
in place, run tables/nntp.sh.  If you wish to use newsd on a new slash-site,
use slash+nntp.sql instead of slash.sql.

Once you have database support for newsd, you'll need to have the HTML::Parser
and HTML::Tree Perl modules from CPAN.  Then just run newsd.  If you already
have a news server on your system, you'll need to run newsd on an alternate
port - do this with the -p option.  To post as a non-AC with newsd, either use
standard NNTP authentication or add Username: and Password: headers to your
posts.

	--Matthew Sachs <matthewg@zevils.com>
