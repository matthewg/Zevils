package NNTB::Weblog;

# This package provides common functions to all NNTB weblog modules.
# NNTB modules should be inherit from this.

$VERSION = '0.01';

=head1 NAME

NNTB::Weblog - Base class for NNTB weblog modules

=head1 SYNOPSIS

	package NNTB::Weblog::YourBlog;
	@ISA = qw(NNTB::Weblog);
	use NNTB::Common;

	...

=head1 ABSTRACT

C<NNTB::Weblog> serves as a base class for adding support for a particular
weblog to NNTB.  NNTB, or Network News Transport for 'Blogs, allows one to
access weblogs via NNTP.  Unless otherwise stated, you B<MAY> override all
methods.

=head2 GROUP HIERARCHY

There are a few things that NNTP needs.  The first thing you need to plan
is the layout of your groups.  NNTP groups have a semi-hierchial layout
where the left-most portions are the broadest - the opposite of the way
hostnames are constructed.  Roots are configurable by the user, but you
should provide a default that is the name of your weblog system followed
by the name of the site; for instance, C<slash.slashdot> or C<scoop.kuro5hin>.

Not every level of the hierarchy has to exist.  For instance, having a group
called C<slash.slashdot.text.stories.foo_bar> does not imply having groups
C<slash>, C<slash.slashdot>, C<slash.slashdot.text>, etc.

If your weblog uses HTML as its native format for stories and comments,
you must keep in mind that many news clients may not support HTML; you should
provide two parallel hierarchies, one for text and one for HTML.  This really
takes up very little additional effort, and an HTML to text conversion function
suitable for use in C<NNTB::Weblog> modules is provided by the base C<NNTB::Weblog>
class.  For instance, you could have:

	weblog.site
		.text
			.stories - This would have all front-page stories
				.some_section
				.other_section
					.123 - Comments for story 123
		.html
			.stories - Same as above, but in HTML format
				...etc...

Note that you should ignore the text/html in the newsgroup name when a user
posts an article and instead look at the C<Content-Type> header.

=head2 ARTICLE IDENTIFIERS

NNTP has two distinct systems of article identifiers; you must implement both.
The first system is a globally-unique message ID.  Message IDs are enclosed in
angle brackets and typically have an at sign in them.  Here's an example of a
message ID:

	<1234@5678.text.site.weblog>

In the example above, 1234 might be the comment ID and 5678 might be the story
ID.  If you are following the recommendations and keeping separate groups for
text and HTML articles, articles will need different message IDs for the two
groups, since an article in the text group is not the seame as the article
in the HTML group.  NNTB message IDs B<MUST> end in your L<"root"> (except
for the closing E<gt>.)

The other way of identifying an article is its article number; article numbers
are monotonically increasing integers that are unique only within a particular
group.

=head2 TIMES

You also need to be aware of the time that an article was posted or a group
was created.  For instance, clients will ask for the names of all groups
created since a particular date in order to update their list of valid groups.

=head1 METHODS

=cut

use strict;
use warnings;
use vars qw($VERSION);
use Carp;
use HTML::FormatText;
use HTML::TreeBuilder;

=pod

=head2 CONVENIENCE METHODS

These methods are already implemented.  They are provided as a convenience
to you.

=over 4

=item new PARAMS

This method serves as a constructor for your object.  C<NNTB::Weblog>
provides a useful default constructor that will give you an appropriately-blessed
hashref; it is recommended that you inherit this constructor, e.g.:

	my $type = shift;
	my $self = $type->SUPER::new;

The object returned by C<SUPER::new> may also have some parameters set.  These
parameters are:

=over 4

=item $self-E<gt>{root}

The user-selected root for the NNTP group hierarchy.  If and only if this is not
defined, you B<MUST> provide a default.

=back

You may then proceed to do any weblog-specific initialization.  You will be given
a hash of the settings for this particular instance of your module as parameters
to this method.

Note that this method is only called once, when the program first starts.
For client-specific initialization, see L<"got_client"> below.

=cut

sub new(@) {
	my $class = ref($_[0]) || $_[0] || "NNTB::Weblog";
	croak "Do not instantiate NNTB::Weblog directly; use one of its subclasses." if $class eq "NNTB::Weblog";

	shift;
	my $self = { };
	bless $self, $class;

	my %params = @_;
	($self->{root}) = delete $params{root};

	return $self;
}

=pod

=item log TEXT LOGLEVEL

This method logs some event.  The log text will be prepended with a timestamp and
the name of your module.

C<LOGLEVEL> is one of the following constants from C<NNTB::Common>:

=over 4

=item LOG_ERROR

=item LOG_WARNING

=item LOG_INFO

=item LOG_NOTICE

=item LOG_DEBUG

=back

C<TEXT> may be an array (not an array-ref.)

You B<MUST NOT> override this method.

=cut

sub log(@) {
	my $package = ref($_[0]) || $_[0];
	shift;
	::_log("$package: ", @_);
}

=pod

=item client_ip

This method returns the IP address of the currently-connected client.

=cut

sub client_ip($) {
	#return $::client_ip;
}

=pod

=item groupname GROUP

This method transforms a string into something suitable for use as an NNTP group name.

You C<MUST NOT> override this method.

=cut

sub groupname($$) {
	my($self, $group) = @_;
	$group =~ tr! .*?\\/,!_______!;
	$group =~ s/^!/_/;
	return $group;
}

=pod

=item fail REASON

Call this method and return to indicate failure.  C<REASON> should be an NNTP result code.  Example:

	$self->{auth_ok} or return $self->fail("500 Something Broke);

See RFC 977 for details on NNTP result codes.  You B<MUST NOT> override this method.

You can also use the following failure constants, provided by C<NNTB::Common>:

=over 4

=item ERR_NOARTICLE

430 No Such Article

=item ERR_MUSTAUTH

480 Authorization Required

=back

=cut

sub fail($$) {
	my($self, $reason) = @_;

	$self->{errstr} = $reason;
	return undef;
}

=pod

=item html2txt HTML

This method converts HTML to plain text.  It handles links in a style similar
to that of Debian Weekly News.

=cut

sub html2txt($$) {
	my($self, $html) = @_;

	my $tree = HTML::TreeBuilder->new->parse($html);
	my $linkcount = 0;
	my @footlinks;

	# Change this:
	#	Some text, including <a href="url">a link</a>.
	# To this:
	#	Some text, including [0]{a link}.
	#
	#	[0] url

	foreach my $node (@{$tree->extract_links("a")}) {
		my($link, $elem) = @$node;

		$link = "[$linkcount] $link";
		my($text) = $elem->content_refs_list();
		$$text = "[$linkcount]{$$text}";
		$linkcount++;

		while($elem and $elem->tag ne "p") { $elem = $elem->parent; }
		if(!$elem or !$elem->parent) { # No enclosing <p> - put it at the end
			push @footlinks, $link;
			next;
		}

		# $elem is now the paragraph that had the link.
		# If it is the first link of the paragraph, insert a new para next to it.
		# Append the link to $elem's sibling.

		$elem->postinsert(['p']) unless $elem->{__WEBLOG_putpara};
		$elem->{__WEBLOG_putpara} = 1;

		# Find the paragraph we want to put our link into.
		my @elem_siblings = $elem->parent->content_list;
		while(@elem_siblings and $elem_siblings[0] != $elem) {
			shift @elem_siblings;
		}

		if(!@elem_siblings) { # Couldn't find it
			push @footlinks, $link;
			next;
		}

		$elem_siblings[0]->push_content([$link], ['br']);
	}

	# Sometimes, for whatever reason, we can't add a link where we want to.
	# We stick these guys at the end.
	$tree->push_content(
		['p', 
			map {[$_, 'br']} @footlinks
		]
	);

	return HTML::FormatText->new(leftmargin => 0, rightmargin => 75)->format($tree);
}

=pod

=back

=head2 COMMUNICATION METHODS

These methods are how NNTB communicates with your module.  Only stubs
for these methods are provided; if you wish to have the functionality of
these methods, you'll need to implement them yourself.

=over 4

=item root

This method must return the group root for this particular instantion of your
module.  The group root is the prefix for all of your NNTP group names.
Your group root B<SHOULD> consist of the name of the weblog your module is for
and an identifier for the particular site using your module.  Example:

	return $self-E<gt>groupname("someweblog.$self->{site_name}");

You B<MUST> override this method.

=cut

sub root($) { return ""; }

=pod

=item groups [TIME]

This method should return a hash whose keys are the available groups and whose
values are descriptions of those groups.  If C<TIME> is specified, only groups
created since that time (in UNIX epoch format) should be returned.

=cut

sub groups($;$) { return () ; }

=pod

=item articles GROUP [TIME]

This method should return a hash whose keys are the article numbers for the
given group and whose values are the corresponding message IDs.  If C<TIME>
is specified, only articules posted since that time (in UNIX epoch format) should
be returned.  The validity of the group name will be verified before this method
is called.

=cut

sub articles($$;$) { return undef; }

=pod

=item article TYPE MSGID [HEADERS]

This method should return the indicated article.  C<TYPE> will
be one of "article", "head", or "body", indicating which portion of 
the article to return.  If C<TYPE> is "head", C<HEADERS> may be a list of
which headers to return; return only those headers if C<HEADERS> is present,
otherwise return all headers.  The headers should be returned as a a hash
whose keys are the names of the headers in lower-case and whose values are
their values.

The return value of this method is a list whose first element is 1 (indicating
success), whose second element is the body of the message, and whose third
element is a the headers hash - the body or head may be omitted if either of
those portions aren't called for.

The values in C<HEADERS> will be, and the keys in the return hashref B<MUST> be, in
B<all lower-case>.  You may wish to have custom headers for certain data specific
to your weblog, for instance a header pointing to the URL to access the article
via the web interface, or a header indicating the moderation score.  These headers
B<MUST> be prefixed with C<x-weblog>, e.g. "x-slash-dept" or "x-scoop-votes-for".
Case of headers will be normalized as follows before displaying to the user:
The first character of the header name, and the first character after any dash,
will be upper-cased.

Return C<$self-E<gt>fail(ERR_NOARTICLE)> if the article does not exist.  See L<"post"> below for some important
NNTP headers.

=cut

sub article($$$) { return undef; }

=pod

=item auth USERNAME PASSWORD

This method is called when a user attempts to authenticate.
You should return 1 if the authentication succeeds or 0 if
the authentication fails.

=cut

sub auth($$$) { return 0; }

=pod

=item post HEAD BODY

This method is called when a user attempts to post an article to one of your
groups.  Return 1 to indicate success and 0 to indicate failure.

C<HEAD> will be a hashref whose keys are the names of the headers (in lower-case)
and whose values are their values.
Invalid groupnames, and groups that the user is not allowed to post to, will have
already been removed from the C<Newsgroups> header.

Also, the user will be prevented from posting to multiple groups at once
(cross-posting) and the References header will be checked for validity.
It will also be reduced to a single message ID.

Some of the more important headers:

=over 4

=item subject

=item references

Space-separated list of the message IDs this is in reply to; nonexistant for a
top-level post.  For this method, only a single message ID will be given to you.

=item newsgroups

Comma-separated list of the newsgroups this message was posted to.  For this method,
only a single newsgroup will be allowed.

=item content-type

If this matches C<\btext/html\b>, the comment is in HTML; otherwise it is in plain
text.

=back

=cut

sub post($$$) { return 0; }

=pod

=item is_group GROUP

This method checks to see if the indicated group exists.  Return 0 or 1.

=item can_post GROUP

This method checks to see if the indicated group can be posted to.  Return 0 or 1.
The validity of the group name will already have been checked before this method is called.

=cut

sub is_group($$) { return 0; }
sub can_post($$) { return 0; }

=pod

=item groupstats GROUP

This method should return a list consisting of the first and last article numbers,
followed by the number of articles, in the indicated group.  The validity of the
group name will be verified before this method is called.

=cut

sub groupstats($$) { return undef; }

=pod

=item num2id GROUP MSGNUM

This method should convert a message number in a particular group to a message ID.
If the message indicated does not exist, return undef.
The validity of the group name will be verified before this method is called.

Your message IDs B<MUST> all end in the the value of L<"root"> (except for the
closing E<gt>.)

=cut

sub num2id($$$) { return undef; }

=pod

=item got_client

This method is called when a client connects to the NNTP server.

=cut

sub got_client($) { return 1; }

=pod

=back

=head1 HISTORY

=over 4

=item *

0.01, 2002-03-10

=over 4

=item *

Initial release.

=back

=back

=head1 SUPPORT

See http://www.zevils.com/programs/nntb/ for support.

=head1 AUTHOR

Matthew Sachs E<lt>matthewg@zevils.comE<gt>.

=head1 SEE ALSO

RFCs 850, 977 and 2980

=head1 LEGAL

Copyright (c) 2002 Matthew Sachs.  All rights reserved.
This program is released under the GNU General Public License, version 2.0.

=cut

1;
