#!/usr/bin/perl
#

use strict;

require "$ENV{LJHOME}/cgi-bin/ljlib.pl";

use MIME::Lite ();
use Text::Wrap ();
use Time::HiRes ('gettimeofday', 'tv_interval');
use HTML::TreeBuilder;
use HTML::FormatText;

package LJ;

# determine how we're going to send mail
$LJ::OPTMOD_NETSMTP = eval "use Net::SMTP (); 1;";

if ($LJ::SMTP_SERVER) {
    die "Net::SMTP not installed\n" unless $LJ::OPTMOD_NETSMTP;
    MIME::Lite->send('smtp', $LJ::SMTP_SERVER, Timeout => 10);
} else {
    MIME::Lite->send('sendmail', $LJ::SENDMAIL);
}

# <LJFUNC>
# name: LJ::send_mail
# des: Sends email.  Character set will only be used if message is not ascii.
# args: opt
# des-opt: Hashref of arguments.  <b>Required:</b> to, from, subject, body.
#          <b>Optional:</b> toname, fromname, cc, bcc, charset, wrap
# </LJFUNC>
sub send_mail
{
    my $opt = shift;

    my $msg = $opt;

    # did they pass a MIME::Lite object already?
    unless (ref $msg eq 'MIME::Lite') {

        my $clean_name = sub {
            my $name = shift;
            return "" unless $name;
            $name =~ s/[\n\t\(\)]//g;
            return $name ? " ($name)" : "";
        };

        my $body = $opt->{'wrap'} ? Text::Wrap::wrap('','',$opt->{'body'}) : $opt->{'body'};
        $msg = new MIME::Lite ('From' => "$opt->{'from'}" . $clean_name->($opt->{'fromname'}),
                                  'To' => "$opt->{'to'}" . $clean_name->($opt->{'toname'}),
                                  'Cc' => $opt->{'cc'},
                                  'Bcc' => $opt->{'bcc'},
                                  'Subject' => $opt->{'subject'},
                                  'Data' => $body);

        if ($opt->{'charset'} && ! (LJ::is_ascii($opt->{'body'}) && LJ::is_ascii($opt->{'subject'}))) {
            $msg->attr("content-type.charset" => $opt->{'charset'});
        }

        if ($opt->{'headers'}) {
            $msg->add(%{$opt->{'headers'}});
        }
    }

    # if send operation fails, buffer and send later
    my $buffer = sub {
        my $starttime = [gettimeofday()];
        my $tries = 0;

        # aim to try 10 times, but that's redundant if there are fewer clusters
        my $maxtries = @LJ::CLUSTERS;
        $maxtries = 10 if $maxtries > 10;

        # select a random cluster master to insert to
        my $cid;
        while (! $cid && $tries < $maxtries) {
            my $idx = int(rand() * @LJ::CLUSTERS);
            $cid = $LJ::CLUSTERS[$idx];
            $tries++;
        }
        return undef unless $cid;

        # try sending later
        my $rval = LJ::cmd_buffer_add($cid, 0, 'send_mail', Storable::freeze($msg));

        my $notes = sprintf( "Queued mail send to %s %s: %s",
                             $msg->get('to'),
                             $rval ? "succeeded" : "failed",
                             $msg->get('subject') );
        LJ::blocking_report( $LJ::SMTP_SERVER || $LJ::SENDMAIL, 'send_mail',
                             tv_interval($starttime), $notes );

        $rval; # return
    };

    my $starttime = [gettimeofday()];
    my $rv = eval { $msg->send && 1; };
    my $notes = sprintf( "Direct mail send to %s %s: %s",
                         $msg->get('to'),
                         $rv ? "succeeded" : "failed",
                         $msg->get('subject') );
    LJ::blocking_report( $LJ::SMTP_SERVER || $LJ::SENDMAIL, 'send_mail',
                         tv_interval($starttime), $notes );
    return 1 if $rv;
    return 0 if $@ =~ /no data in this part/;  # encoding conversion error higher
    return $buffer->($msg);

}


# <LJFUNC>
# name: LJ::html2txt
# des: Converts HTML to text, displaying link URLs in per-paragraph footnote
#      style.
# args: html
# des-html: The HTML to convert.
# </LJFUNC>
sub html2txt($) {
	my($html) = @_;

	my $tree = HTML::TreeBuilder->new_from_content($html);
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

		#print "Okay, got link\n";

		while($elem and $elem->tag ne "p") { $elem = $elem->parent; }
		if(!$elem or !$elem->parent) { # No enclosing <p> - put it at the end
			#print "No enclosing p - adding to footlinks\n";
			push @footlinks, $link;
			next;
		}

		# $elem is now the paragraph that had the link.
		# If it is the first link of the paragraph, insert a new para next to it.
		# Append the link to $elem's sibling.

		#print "Alright, found paragraph\n";

		$elem->postinsert(HTML::Element->new_from_lol(['p', ['blockquote']])) unless $elem->{__WEBLOG_putpara};
		$elem->{__WEBLOG_putpara} = 1;

		# Find the paragraph we want to put our link into.
		my @elem_siblings = $elem->parent->content_list;
		while(@elem_siblings and $elem_siblings[0] != $elem) {
			shift @elem_siblings;
		}

		#print "Find para redux\n";

		if(!@elem_siblings) { # Couldn't find it
			push @footlinks, $link;
			#print "Added to footlinks\n";
			next;
		}

		shift @elem_siblings;
		$elem = $elem_siblings[0]->find_by_tag_name("blockquote");

		#print "push_content($link)\n";
		$elem->push_content($link, ['br']);
	}

	# Sometimes, for whatever reason, we can't add a link where we want to.
	# We stick these guys at the end.
	if(@footlinks) {
		my $body = $tree->find_by_tag_name("body");
		$body->push_content(['br']);
		$body->push_content(
			['p', ['blockquote', 
				map {("$_", ['br']);} @footlinks
			]]
		);
	}

	return HTML::FormatText->new(leftmargin => 0, rightmargin => 76)->format($tree);
}

1;


