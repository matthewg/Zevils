# Parse::ABNF::Common
#
# Copyright (c) 2001 Matthew Sachs <matthewg@zevils.com>.  All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Parse::ABNF::Common;

=head1 NAME

Parse::ABNF::Common

=head1 SYNOPSIS

Please see the C<Parse::ABNF> documentation for general information about C<Parse::ABNF>
or the comments in C<Parse::ABNF::Common> for information specific to that module.

=cut


$VERSION = '0.01';

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT_OK %EXPORT_TAGS);
use Carp;

@ISA = qw(Exporter);
@EXPORT_OK = qw(OP_TYPE_OPS OP_TYPE_NUMVAL OP_TYPE_CHARVAL OP_MODE_SINGLETON OP_MODE_ALTERNATOR OP_MODE_AGGREGATOR CORE_RULES ABNF_PARSETREE &tabify);
%EXPORT_TAGS = (all => [@EXPORT_OK]);
require Exporter;

# These constants are pretty important.  If you're going to be looking at op tree dumps you probably want to
# keep them handy.
#
#	"Firmly fix these words of mine into your thinking and being, and tie them as a symbol on your
#	 hands and let them be reminders on your forehead.  Teach them to your children, speaking of
#	 them when you sit down, while inside your houses, when you travel about, when you lie down,
#	 and when you get up.  Write them on the doorframes of your houses and on your gates, ..."
#									--Deuteronomy 11:18-20
#

# We used to use constant, but that made Exporter unhappy.
use constant OP_TYPE_OPS => 1;
use constant OP_TYPE_NUMVAL => 2;
use constant OP_TYPE_CHARVAL => 3;

use constant OP_MODE_SINGLETON => 0;
use constant OP_MODE_ALTERNATOR => 1;
use constant OP_MODE_AGGREGATOR => 2;



sub tabify($) {
	no strict 'refs';
	my $what = shift;
	my $tabstr;

	# We use $tablevel in the calling package.  You wanna make something of it, punk?
	# If this were a "public" method I'd do something nicer, but it ain't so I won't.
	my ($callerpkg) = caller;
	my $tablevel = ${"${callerpkg}::tablevel"};

	$tabstr = "\n" . "\t" x ($tablevel+1);
	return "\t"x($tablevel+1) . join($tabstr, split(/\n/, $what)) . "\n" . "\t"x$tablevel;
}


# As defined in RFC 2234 appendix A
use constant CORE_RULES => (
	alpha => { type => OP_TYPE_NUMVAL, mode => OP_MODE_ALTERNATOR, value => [map {chr} (0x41..0x5A, 0x61..0x7A)], core=>1 }, 	# A-Z / a-z
	bit => { type => OP_TYPE_NUMVAL, mode => OP_MODE_ALTERNATOR, value => [qw(0 1)], core=>1 },
	char => { type => OP_TYPE_NUMVAL, mode => OP_MODE_ALTERNATOR, value => [map {chr} (0x01..0x7F)], core=>1 }, 			# any 7-bit US-ASCII character, excluding NUL
	cr => { type => OP_TYPE_NUMVAL, value => [chr(0x0D)], core=>1 }, 								# carriage return
	'real-crlf' => { type => OP_TYPE_OPS, mode => OP_MODE_AGGREGATOR, value => [qw(cr lf)], code => 1},				# Internet standard newline
	crlf => { type => OP_TYPE_OPS, mode => OP_MODE_ALTERNATOR, value => [qw(cr lf real-crlf)], core=>1 }, 				# CR, LF, or CRLF
	ctl => { type => OP_TYPE_NUMVAL, mode => OP_MODE_ALTERNATOR, value => [map {chr} (0x00..0x1F, 0x7F)], core=>1 }, 		# controls
	digit => { type => OP_TYPE_NUMVAL, mode => OP_MODE_ALTERNATOR, value => [map {chr} (0x30..0x39)], core=>1 }, 			# 0-9
	dquote => { type => OP_TYPE_NUMVAL, value => [chr(0x22)], core=>1 }, 								# " (Double Quote)
	hexdig => {
		type => OP_TYPE_OPS,
		mode => OP_MODE_ALTERNATOR,
		value => [
			"digit",
			{
				type => OP_TYPE_CHARVAL,
				mode => OP_MODE_ALTERNATOR,
				value => [qw(A B C D E F)]
			}
		], core=>1
	},
	htab => { type => OP_TYPE_NUMVAL, value => [chr(0x09)], core=>1 }, 								# horizontal tab
	lf => { type => OP_TYPE_NUMVAL, value => [chr(0x0A)], core=>1 }, 								# linefeed
	lwsp => { # linear white space (past newline)
		type => OP_TYPE_OPS,
		mode => OP_MODE_AGGREGATOR,
		minreps => 0,
		maxreps => -1,
		value => [
			{
				type => OP_TYPE_OPS,
				mode => OP_MODE_ALTERNATOR,
				value => [qw(wsp crlf)]
			},
			"wsp"
		], core=>1
	},
	octet => { type => OP_TYPE_NUMVAL, value => [map {chr} (0x00..0xFF)], core=>1 }, 						# 8 bits of data
	sp => { type => OP_TYPE_NUMVAL, value => [chr(0x20)], core=>1 }, 								# space
	vchar => { type => OP_TYPE_NUMVAL, mode => OP_MODE_ALTERNATOR, value => [map {chr} (0x21..0x7E)], core=>1 }, 			# visible (printing) characters
	wsp => { type => OP_TYPE_OPS, mode => OP_MODE_ALTERNATOR, value => [qw(sp htab)], core=>1 } 					# white space
);


# We use this as a bootstrap for grokking ABNF syntax.
use constant ABNF_PARSETREE => (
	CORE_RULES,
	newline => {
		type => OP_TYPE_OPS,
		mode => OP_MODE_ALTERNATOR,
		value => [qw(CRLF CR LF)]
	},
	rulelist => {
		minreps => 1,
		maxreps => -1,
		type => OP_TYPE_OPS,
		mode => OP_MODE_ALTERNATOR,
		value => [
			"rule"
		]
	},
	rule => { type => OP_TYPE_OPS, mode => OP_MODE_AGGREGATOR, value => [qw(rulename defined-as elements newline)] },
	rulename => {
		type => OP_TYPE_OPS,
		mode => OP_MODE_AGGREGATOR,
		value => ["ALPHA", 
			{
				type => OP_TYPE_OPS,
				mode => OP_MODE_ALTERNATOR,
				minreps => 0,
				maxreps => -1,
				value => ["ALPHA", "DIGIT", {type => OP_TYPE_NUMVAL, value => ["-"]}]
			}
		]
	},
	'defined-as' => {
		type => OP_TYPE_OPS,
		mode => OP_MODE_AGGREGATOR,
		value => ["maybe-some-whitespace", {type => OP_TYPE_NUMVAL, value => ["="]}, {type => OP_TYPE_NUMVAL, minreps => 0, maxreps => 1, value => ["/"]}, "maybe-some-whitespace"]
	},
	elements => { type => OP_TYPE_OPS, mode => OP_MODE_ALTERNATOR, value => [qw(alternation maybe-some-whitespace)] },
	'maybe-some-whitespace' => {
		type => OP_TYPE_OPS,
		mode => OP_MODE_ALTERNATOR,
		minreps => 0,
		maxreps => -1,
		value => [qw(WSP)]
	},
	alternation => {
		type => OP_TYPE_OPS,
		mode => OP_MODE_AGGREGATOR,
		value => ["concatenation",
			{
				type => OP_TYPE_OPS,
				mode => OP_MODE_AGGREGATOR,
				minreps => 0,
				maxreps => -1,
				value => ["maybe-some-whitespace", {type => OP_TYPE_NUMVAL, value => ["/"]}, "maybe-some-whitespace", "concatenation"]
			}
		]
	},
	concatenation => {
		type => OP_TYPE_OPS,
		mode => OP_MODE_AGGREGATOR,
		value => ["repetition",
			{
				type => OP_TYPE_OPS,
				mode => OP_MODE_AGGREGATOR,
				minreps => 0,
				maxreps => -1,
				value => [qw(maybe-some-whitespace repetition)]
			}
		]
	},
	repetition => {
		type => OP_TYPE_OPS,
		mode => OP_MODE_AGGREGATOR,
		value => [
			{
				type => OP_TYPE_OPS,
				minreps => 0,
				maxreps => 1,
				value => [qw(repeat)]
			}, "element"
		]
	},
	repeat => {
		type => OP_TYPE_OPS,
		mode => OP_MODE_ALTERNATOR,
		value => [
			{
				type => OP_TYPE_OPS,
				minreps => 1,
				maxreps => -1,
				value => [qw(DIGIT)]
			},{
				type => OP_TYPE_OPS,
				mode => OP_MODE_AGGREGATOR,
				value => [
					{
						type => OP_TYPE_OPS,
						minreps => 0,
						maxreps => -1,
						value => [qw(DIGIT)]
					},{type => OP_TYPE_NUMVAL, value => ['*']},{
						type => OP_TYPE_OPS,
						minreps => 0,
						maxreps => -1,
						value => [qw(DIGIT)]
					}
				]
			}
		]
	},
	element => {
		type => OP_TYPE_OPS,
		mode => OP_MODE_ALTERNATOR,
		value => [qw(rulename group option char-val num-val prose-val)]
	},
	group => {
		type => OP_TYPE_OPS,
		mode => OP_MODE_AGGREGATOR,
		value => [{type => OP_TYPE_NUMVAL, value => ['(']}, "maybe-some-whitespace", "alternation", "maybe-some-whitespace", {type => OP_TYPE_NUMVAL, value => [')']}]
	},
	option => {
		type => OP_TYPE_OPS,
		mode => OP_MODE_AGGREGATOR,
		value => [{type => OP_TYPE_NUMVAL, value => ['[']}, "maybe-some-whitespace", "alternation", "maybe-some-whitespace", {type => OP_TYPE_NUMVAL, value => [']']}]
	},
	'char-val' => {
		type => OP_TYPE_OPS,
		mode => OP_MODE_AGGREGATOR,
		value => ["DQUOTE", {type => OP_TYPE_NUMVAL, minreps => 0, maxreps => -1, value => [map {chr} (0x20,0x21,0x23..0x7E)]}, "DQUOTE"]
	},
	'num-val' => {
		type => OP_TYPE_OPS,
		mode => OP_MODE_AGGREGATOR,
		value => [{type => OP_TYPE_NUMVAL, value => ["%"]}, {type => OP_TYPE_OPS, mode => OP_MODE_ALTERNATOR, value => [qw(bin-val dec-val hex-val)]}]
	},
	'bin-val' => {
		type => OP_TYPE_OPS,
		mode => OP_MODE_AGGREGATOR,
		value => [
			{type => OP_TYPE_NUMVAL, value => ["b"]},
			{type => OP_TYPE_OPS, minreps => 1, maxreps => -1, value => [qw(BIT)]},
			{type => OP_TYPE_OPS, mode => OP_MODE_ALTERNATOR, minreps => 0, maxreps => 1, value => [
				{
					type => OP_TYPE_OPS,
					mode => OP_MODE_AGGREGATOR,
					minreps => 1,
					maxreps => -1,
					value => [{type => OP_TYPE_NUMVAL, value => ['.']}, {
						type => OP_TYPE_OPS,
						minreps => 1,
						maxreps => -1,
						value => [qw(BIT)]
					}]
				},{
					type => OP_TYPE_OPS,
					mode => OP_MODE_AGGREGATOR,
					value => [{type => OP_TYPE_NUMVAL, value => ["-"]}, {
						type => OP_TYPE_OPS,
						minreps => 1,
						maxreps => -1,
						value => [qw(BIT)]
					}]
				}
			]}
		]
	},
	'dec-val' => {
		type => OP_TYPE_OPS,
		mode => OP_MODE_AGGREGATOR,
		value => [
			{type => OP_TYPE_NUMVAL, value => ["d"]},
			{type => OP_TYPE_OPS, minreps => 1, maxreps => -1, value => [qw(DIGIT)]},
			{type => OP_TYPE_OPS, mode => OP_MODE_ALTERNATOR, minreps => 0, maxreps => 1, value => [
				{
					type => OP_TYPE_OPS,
					mode => OP_MODE_AGGREGATOR,
					minreps => 1,
					maxreps => -1,
					value => [{type => OP_TYPE_NUMVAL, value => ['.']}, {
						type => OP_TYPE_OPS,
						minreps => 1,
						maxreps => -1,
						value => [qw(DIGIT)]
					}]
				},{
					type => OP_TYPE_OPS,
					mode => OP_MODE_AGGREGATOR,
					value => [{type => OP_TYPE_NUMVAL, value => ["-"]}, {
						type => OP_TYPE_OPS,
						minreps => 1,
						maxreps => -1,
						value => [qw(DIGIT)]
					}]
				}
			]}
		]
	},
	'hex-val' => {
		type => OP_TYPE_OPS,
		mode => OP_MODE_AGGREGATOR,
		value => [
			{type => OP_TYPE_NUMVAL, value => ["x"]},
			{type => OP_TYPE_OPS, minreps => 1, maxreps => -1, value => [qw(HEXDIG)]},
			{type => OP_TYPE_OPS, mode => OP_MODE_ALTERNATOR, minreps => 0, maxreps => 1, value => [
				{
					type => OP_TYPE_OPS,
					mode => OP_MODE_AGGREGATOR,
					minreps => 1,
					maxreps => -1,
					value => [{type => OP_TYPE_NUMVAL, value => ['.']}, {
						type => OP_TYPE_OPS,
						minreps => 1,
						maxreps => -1,
						value => [qw(HEXDIG)]
					}]
				},{
					type => OP_TYPE_OPS,
					mode => OP_MODE_AGGREGATOR,
					value => [{type => OP_TYPE_NUMVAL, value => ["-"]}, {
						type => OP_TYPE_OPS,
						minreps => 1,
						maxreps => -1,
						value => [qw(HEXDIG)]
					}]
				}
			]}
		]
	},
	'prose-val' => {
		type => OP_TYPE_OPS,
		mode => OP_MODE_AGGREGATOR,
		value => [{type => OP_TYPE_NUMVAL, value => ["<"]}, {type => OP_TYPE_NUMVAL, mode => OP_MODE_ALTERNATOR, minreps => 0, maxreps => -1, value => [map {chr} (0x20..0x3D, 0x3F..0x7E)]}, {type => OP_TYPE_NUMVAL, value => [">"]}]
	}
);

1;
