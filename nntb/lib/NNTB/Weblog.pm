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

=head1 METHODS

=over 4

=cut

use strict;
use warnings;
use vars qw($VERSION);
use Carp;

=pod

=item new PARAMS

This method serves as a constructor for your object.  C<NNTB::Weblog>
provides a useful default constructor that will give you an appropriately-blessed
hashref; it is recommended that you inherit this constructor, e.g.:

	my $type = shift;
	my $self = $type-E<gt>SUPER::new;

You may then proceed to do any weblog-specific initialization.  You will be given
a hash of the settings for this particular instance of your module as parameters
to this method.

Note that this method is only called once, when the program first starts.
For client-specific initialization, see L<"got_client"> below.

=cut

sub new($) {
	my $class = ref($_[0]) || $_[0] || "NNTB::Weblog";
	croak "Do not instantiate NNTB::Weblog directly; use one of its subclasses." if $class eq "NNTB::Weblog";

	shift;
	my $self = { };
	bless $self, $class;

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

=item groupname GROUP

This method transforms a string into something suitable for use as an NNTP group name.

You C<MUST NOT> override this method.

=cut

sub groupname($$) {
	my($self, $group) = @_;
	$group =~ tr/ .*?\\/_____/;
	$group =~ s/^!/_/;
	return $group;
}

=pod

=item fail REASON

Call this method and return to indicate failure.  C<REASON> should be an NNTP result code.  Example:

	$self-E<gt>{auth_ok} or return $self-E<gt>fail("480 Authorization Required");

See RFC 977 for details on NNTP result codes.  You B<MUST NOT> override this method.

=cut

sub fail($$) {
	my($self, $reason) = @_;

	$self->{errstr} = $reason;
	return undef;
}

=pod

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

This method should return a hash whose keys are the message IDs for the
given group and whose values are the corresponding article numbers.  If C<TIME>
is specified, only articules posted since that time (in UNIX epoch format) should
be returned.  Return undef if the group does not exist.

=cut

sub articles($$;$) { return undef; }

=pod

=item article TYPE MSGID

This method should return the indicated article.  C<TYPE> will
be one of "article", "head", or "body", indicating which portion of 
the article to return.  Return undef if the article does not exist.

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

=cut

sub post($$$) { return 0; }

=pod

=item isgroup GROUP

This method checks to see if the indicated group exists.

=cut

sub isgroup($$) { return 0; }

=pod

=item groupstats GROUP

This method should return a list consisting of the first and last article numbers,
followed by the number of articles, in the indicated group.  Return undef if the
group does not exist.

=cut

sub groupstats($$) { return undef; }

=pod

=item id2num GROUP MSGID

=item num2id GROUP MSGNUM

These methods should convert back and forth between a message ID and a message
number in the given group.  If the group or message indicated does not exist,
return undef.

=cut

sub id2num($$$) { return undef; }
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

=head1 LEGAL

Copyright (c) 2002 Matthew Sachs.  All rights reserved.
This program is released under the GNU General Public License, version 2.0.

=cut

1;
