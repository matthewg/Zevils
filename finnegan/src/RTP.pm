package RTP;

use strict;
use warnings;
use Time::HiRes qw(time);
use Carp qw(confess);

use constant SECS_BETWEEN_1900_1970 => 2208988800; # From rat's rtp_dump.c - for converting to NTP time

=pod

First word:
	version:2 == 2
	padding:1 == 0
	extension:1 == 0
	CSRC_count:4 == 0
	marker:1 == 0
	payload:7 == 0 (PCMU 8KHz 1-channel)
seqno:16 # Start at somewhere random
timestamp:32
SSRC:32 # Random
payload

NTP time:
	low-order 16 bits of time()-SECS_BETWEEN_1900_1970
	high-order 16 bits of fraction-of-seconds

RTCP???

=cut

my $header = pack("n", 32768); # First bit is 1 (version 2), everything else is 0.

# Create a new RTP object
sub new($) {
	my $class = ref($_[0]) || $_[0] || "RTP";
	shift;

	my $self = {
		ssrc => pack("N", int(rand(0xFFFFFFFF))), # Random 32-bit int, pre-packed since it's static
		seqno => int(rand(0x10000)), # Random 16-bit int, not pre-packed since we need to increment it
		timestamp_time => time() - SECS_BETWEEN_1900_1970,
	};
	bless $self, $class;

	return $self;
}

# Returns an RTP timestamp, given an RTP object, from which we get the (fractional) time.
# RTP timestamps are 32-bit unsigned ints.  The high-order 16 bits are the low-order 16 bits
# of the time, in seconds, from UTC Jan 1st 1900.  The low-order 16 bits are the high-order
# 16 bits of the fractional part of the time.
sub make_timestamp($) {
	my $self = shift;
	my $int = int($self->{timestamp_time});
	my $frac = $self->{timestamp_time} - $int;
	return pack("N", (($int & 0x0000FFFF) << 16) | ($frac & 0xFFFF0000));
}

# Creates an RTP packet from an RTP object.
# If payload is the empty string, will just increment the timestamp and return the empty string - "silence suppression"
# length should be the length, in (fractional) seconds, of this payload.
# Returns a packet, ready for you to send right out the socket
sub make_packet($$$) {
	my($self, $length, $payload) = @_;
	confess "send_packet isn't a static method" unless ref($self);

	my $packet = "";
	$packet = $header . pack("nN", $self->{seqno}++) . $self->make_timestamp() . $self->{ssrc} . $payload if $payload;
	$self->{timestamp_time} += $length;
	return $packet;
}

1;
