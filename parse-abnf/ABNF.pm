# Parse::ABNF
#
# Copyright (c) 2001 Matthew Sachs <matthewg@zevils.com>.  All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Parse::ABNF;

=head1 NAME

Parse::ABNF v. 0.01 - Perl module for dealing with Augmented Backus-Naur Form (ABNF)

=head1 SYNOPSIS

    # First, we create a Parse::ABNF object with a couple of rules.
    $word = Parse::ABNF->new("LETTER=CHAR", "WORD=1*LETTER");

    # Now get the 'word' rule in various forms...
    print "A word consists of ", $word->text("WORD"), "\n";
    print "$foo is a word.\n" if $word->matches("WORD", $foo);
    print "word = ", $word->abnf("WORD"), "\n";

    # A more complicated example demonstrating using the matches method for parsing
    $someproto = Parse::ABNF->new(<<END);
commandstring = command *WSP data ; A command, optional whitespace, data
command = "open" / "close" / "get" / "put" ; Valid commands
data = 1*file ; Data is one or more files
file = 1*VCHAR ; A file is a sequence of printable characters
END
    %results = $someproto->matches("commandstring", "open foo", qw(command data));
    $command = $results{command};
    $data = $results{data};

=head1 DESCRIPTION

This modules provides various methods for dealing with Augmented Backus-Naur Form (ABNF).
Amongst other things, It can conver ABNF to either English description of the syntax or
a regular expression.  ABNF is defined in C<RFC 2234>.  It is a grammar, similar in concept
to the regular expressions that Perl is renowned for, which is often used
for specifying format syntaxes in technical specifications.  Many
Internet standards use ABNF to define various protocols.

C<Parse::ABNF> objects will, by default, contain the rules listed in Appendix A of C<RFC 2234>.
These rules define some basic entities like C<ALPHA>, C<BIT>, C<CHAR>, and C<DIGIT>.

Anywhere that the specification calls for CRLF, C<Parse::ABNF> will accept a CR or an LF in
addition to CRLF.

For any of the methods which take a rule name and return some value, the object will croak
with the error C<Unknown ABNF rule: RULENAME> if and only if an unknown rule is specified.

=head1 CONSTRUCTOR

=over 4

=item new ( [RULES] )

Creates a new C<Parse::ABNF> object.  A C<Parse::ABNF> object contains a complete ruleset.  It
has an internally consistant set of rules which all reduce to what in ABNF parlance
are known as "terminal values."  In other words, some rule foo might refer to some
other rule bar, but you can follow all the different rules in a ruleset and eventually
get down to the definitions of the numeric values that each byte has to have.

A rule is a single definition in a ruleset.  "A word consists of one or more letters" is
a rule.  A ruleset is a collection of one or more rules.

If the C<RULES> parameter is present, those rules will be added to the object as if
you had called the C<add> method with that parameter after creating the object.

=back

=head1 METHODS

=over

=item add ( RULES )

Adds a rule or rules to the object.  The rules may be given in any form that RFC 2234
declares as a valid rule declaration.  If something that isn't valid ABNF is given,
the object will croak with an error like C<Invalid ABNF Syntax: Unknown rule 'FOO'>,
so use C<eval { ... }> if you don't want that to be a fatal error.

The termination of each rule with CRLF is optional for this method.

You can modify existing rules by simply adding them with their new values.

=item delete ( RULES )

Removes C<RULES> from the object.  C<RULES> should consist of the names of the rules to remove from the object.
If the removal of any rule listed for deletion would cause the object to no longer contain a viable ruleset
(for instance, if the ruleset contains rules which refer to a rule that you are attempting to remove,) no
rules will be deleted and instead the object will croak with the error C<Could not remove ABNF rules: RULES>.

=item text ( RULE )

Returns a (relatively) plain English description of a rule, e.g. (A word is) "a sequence of one or more letters"

=item regex ( RULE )

Returns a regular expression which can be used to validate data against a rule.

=item abnf (RULE )

Returns a rule in "canonical" ABNF form.

The format this returns ought to be customizable.

=item rules ( [RULE] )

If the optional parameter is not present, a list of the names of all rules.

If the parameter I<is> present, a list consisting of all rules needed to reduce RULE to
terminal values will be returned.

=item matches ( RULE, DATA[, MATCHRULES] )

This method can be used to simply test data against a rule, or it can parse data into its component parts.

If C<DATA> doesn't match C<RULE>, returns undef.

If C<DATA> I<does> match C<RULE> and the optional parameter C<MATCHRULES> is not present, C<DATA> is returned.

C<MATCHRULES>, if present, should be a list of rule names whose values you are interested in.  For instance, if
you have a rule C<preference = name *WSP "=" *WSP value>, calling this method with C<RULE> set to C<"preference"> and
C<MATCHRULES> set to C<("name", "value")> will cause the return value to be, if C<DATA> matches the C<preference>
rule, a hash whose keys are C<("name", "value")> and whose values are whichever bits of C<DATA> matched those rules.
So, assuming that the C<name> and C<value> rules were set appropriately, if C<DATA> was C<"logfile = /var/log/foo.log">,
the return value would be C<< (name => "logfile", value => "/var/log/foo.log") >>.

However, it can get more complicated than that.  Consider the following ruleset:

    paragraph = HTAB 1*sentence (CR / LF / CRLF)
    sentence = word *(" " / word) ("." / "?" / "!") 0*2" "
    word = 1*VCHAR

If the C<matches> method were called on an object with that ruleset with C<RULE> set to C<"paragraph">,
C<DATA> set to C<"\tHello, world!  Wanna augment my BNF?\n">, and C<MATCHRULES> set to C<("sentence", "word")>,
the return value would be:

    ( sentence =>
        [
            [
                { word => "Hello," },
                " ",
                { word => "world" },
                "!  "
            ],
            [
                { word => "Wanna" },
                " ",
                { word => "augment" },
                " ",
                { word => "my" },
                " ",
                { word => "BNF" },
                "?"
            ]
        ]
    )

=back

=head1 SEE ALSO

RFC 2234

=head1 AUTHOR

Matthew Sachs <matthewg@zevils.com>

=cut


$VERSION = '0.01';

use strict;
use warnings;
use vars qw($VERSION $ABNF);
use Lingua::EN::Inflect qw(PL);
use Carp;

# Well, if you're reading the source code, you probably want to know something about the internals of this beast.
# First, a warning to the educated: I have no formal knowledge of parsing, so my terminology probably differs from yours.
# What we do is we parse the ABNF that the user gives us and turn it into an "op tree".  This op tree is a sequence
# of operands: "ops", "char-val", or "num-val".  Each operand has a value, mode (OP_MODE_ALTERNATOR or OP_MODE_AGGREGATOR - 
# see below) as well as an optional token name, minimum repeat count, and maximum repeat count.  Char-val and num-val are
# terminal operands and are the leafiest parts of the tree.  The value of char-val is a string which is matched case-
# insensitively.  The value of a num-val is a string which is matched as an exact byte-sequence.
#
# Operands can have a number of traits.
#
# The first two traits, minreps and maxreps, work as a pair.  They are used to specify repeat counts - that is, how many
# times an operand may be matched.  If they are not specified, an operand must be matched once and only once.  If one
# is present, however, the other must also be present.  A maxreps of -1 is used to signify no upper bound on the number of
# repetitions.
#
# Each operand can be an alternator, an aggregator, or a singleton.  An alternator will match any of its values once
# and only once (per repeat - if maxreps is greater than 1, it may match a different operand on the next repetition.)
# An aggregator must match all of its values in the order that they are present.  A singleton only has one value.
# The singleton mode is the default.
#
# An op is a collection of operands.  It is used as a connector to form complicated constructs.
# You also need ops to form larger rules from collections of smaller ones. Ops have lists of tokens as their values.
# These lists can contain a mixture of strings which are the names of other tokens and literal operands given as anonymous hashes.
#
# That will all make a lot more sense once you look at the parse tree for CORE_RULES given below... go do that and
# then come back here.
#
#
# Okay, so how do we generate these parse trees?  Well, we have to parse the ABNF given to us in the add method.
# In order to do this, I've hard-coded in a parse tree for ABNF that I made by hand based on section 4 of the RFC.
# Pretty neat, no?  Think about it - this lets us just use this one parsing engine for generating parse trees from
# the user's ABNF and for parsing against the user's ABNF.  We take the hand-written parse tree and just bless it
# into a Parse::ABNF object.
#
# Once you have the parse tree, the rest is pretty self-explanatory.  I mean it's not easy, but there's no special
# trick.  You just go through the parse tree...

use constant OP_MODE_SINGLETON => 0;
use constant OP_MODE_ALTERNATOR => 1;
use constant OP_MODE_AGGREGATOR => 2;

use constant CORE_RULES => ( #As defined in RFC 2234 appendix A
	{
		tokname => "ALPHA",
		type => "num-val",
		mode => OP_MODE_ALTERNATOR,
		value => [map {chr} (0x41..0x5A, 0x61..0x7A)] # A-Z / a-z
	},{
		tokname => "BIT",
		type => "num-val",
		mode => OP_MODE_ALTERNATOR,
		value => [qw(chr(0) chr(1))]
	},{
		tokname => "CHAR",
		type => "num-val",
		mode => OP_MODE_ALTERNATOR,
		value => [map {chr} (0x01..0x7F)] # any 7-bit US-ASCII character, excluding NUL
	},{
		tokname => "CR",
		type => "num-val",
		value => [chr(0x0D)] # carriage return
	},{
		tokname => "CRLF",
		type => "ops",
		mode => OP_MODE_AGGREGATOR,
		value => [qw(CR LF)] # Internet standard newline
	},{
		tokname => "CTL",
		type => "num-val",
		mode => OP_MODE_ALTERNATOR,
		value => [map {chr} (0x00..0x1F, 0x7F)] # controls
	},{
		tokname => "DIGIT",
		type => "num-val",
		mode => OP_MODE_ALTERNATOR,
		value => [map {chr} (0x30..0x39)] # 0-9
	},{
		tokname => "DQUOTE",
		type => "num-val",
		value => [chr(0x22)] # " (Double Quote)
	},{
		tokname => "HEXDIG",
		type => "ops",
		mode => OP_MODE_ALTERNATOR,
		value => [
			"DIGIT",
			{
				type => "char-val",
				mode => OP_MODE_ALTERNATOR,
				value => [qw(A B C D E F)]
			}
		]
	},{
		tokname => "HTAB",
		type => "num-val",
		value => [chr(0x09)] # horizontal tab
	},{
		tokname => "LF",
		type => "num-val",
		value => [chr(\x0A)] # linefeed
	},{
		tokname => "LWSP",
		type => "ops",
		mode => OP_MODE_AGGREGATOR,
		minreps => 0,
		maxreps => -1,
		value => [
			{
				type => "ops",
				mode => OP_MODE_ALTERNATOR,
				value => [qw(WSP CRLF)]
			},
			"WSP"
		] # linear white space (past newline)
	},{
		tokname => "OCTET",
		type => "num-val",
		value => [map {chr} (0x00..0xFF)] # 8 bits of data
	},{
		tokname => "SP",
		type => "num-val",
		value => [chr(0x20)] # space
	},{
		tokname => "VCHAR",
		type => "num-val",
		mode => OP_MODE_ALTERNATOR,
		value => [map {chr} (0x21..0x7E)] # visible (printing) characters
	},{
		tokname => "WSP",
		type => "ops",
		mode => OP_MODE_ALTERNATOR,
		value => [qw(SP HTAB)] # white space
	}
);



sub new($;@) {
	my $class = ref($_[0]) || $_[0] || "Parse::ABNF";
	my $self = {};
	bless $self, $class;
	$self->add(CORE_RULES);
	$self->add(@{$_[1]}) if @_ > 1;
}

sub add($@) {
	my ($self, @rules) = @_;
	my $rule;

	
		
}

sub delete($@) {
	my($self, @rules) = @_;
	my $rule;

}

sub text($$) {
	my($self, $rule) = @_;

	#PL("foo", 2);
}

sub regex($$) {
	my($self, $rule) = @_;

}

sub abnf($$) {
	my($self, $rule) = @_;

}

sub rules($;$) {
	my($self, $rule) = @_;

}

sub matches($$$;@) {
	my($self, $rule, $data, @matchrules) = @_;

}


# Remember to handle "REGEX_RULE continues if next line starts with whitespace" !!
sub _parse_rules($$) {
	my($self, $rules) = @_;
}

# We use this as a bootstrap for grokking ABNF syntax.
use constant ABNF_PARSETREE => (
	CORE_RULES,
	{
		tokname => "rulelist",
		minreps => 1,
		maxreps => -1,
		type => "ops",
		mode => OP_MODE_ALTERNATOR,
		value => [
			"rule", 
			{
				type => "ops",
				mode => OP_MODE_AGGREGATOR,
				value => [
					{
						type => "ops",
						minreps => 0,
						maxreps => -1,
						value => [qw(c-wsp)]
					}, "c-nl"
				]
			}
		]
	},{
		tokname => "rule",
		type => "ops",
		mode => OP_MODE_AGGREGATOR,
		value => [qw(rulename defined-as elements c-nl)]
	},{
		tokname => "rulename",
		type => "ops",
		mode => OP_MODE_AGGREGATOR,
		value => ["ALPHA", 
			{
				type => "ops",
				mode => OP_MODE_ALTERNATOR,
				minreps => 0,
				maxreps => -1,
				value => ["ALPHA", "DIGIT", {type => "num-val", value => ["-"]}]
			}
		]
	},{
		tokname => "defined-as",
		type => "ops",
		mode => OP_MODE_AGGREGATOR,
		value => ["maybe-some-c-wsp", {type => "num-val", value => ["="]}, {type => "num-val", minreps => 0, maxreps => 1, value => ["/"]}, "maybe-some-c-wsp"]
	},{
		tokname => "elements",
		type => "ops",
		mode => OP_MODE_ALTERNATOR,
		value => [qw(alternation maybe-some-c-wsp)]
	},{
		tokname => "c-wsp",
		type => "ops",
		mode => OP_MODE_ALTERNATOR,
		value => ["WSP", {type => "ops", mode => OP_MODE_ALTERNATOR, value => [qw(c-nl WSP)]}]
	},{
		tokname => "maybe-some-c-wsp",
		type => "ops",
		mode => OP_MODE_ALTERNATOR,
		minreps => 0,
		maxreps => -1,
		value => [qw(c-wsp)]
	},{
		tokname => "c-nl",
		type => "ops",
		mode => OP_MODE_ALTERNATOR,
		value => [qw(comment CRLF)]
	},{
		tokname => "comment",
		type => "ops",
		mode => OP_MODE_AGGREGATOR,
		value => [
			{type => "num-val", value => [";"]},
			{
				type => "ops",
				mode => OP_MODE_ALTERNATOR,
				minreps => 0,
				maxreps => -1,
				value => [qw(WSP VCHAR)]
			},"CRLF"
		]
	},{
		tokname => "alternation",
		type => "ops",
		mode => OP_MODE_AGGREGATOR,
		value => ["concatenation",
			{
				type => "ops",
				mode => OP_MODE_AGGREGATOR,
				minreps => 0,
				maxreps => -1,
				value => ["maybe-some-c-wsp", {type => "num-val", value => ["/"]}, "maybe-some-c-wsp", "concatenation"]
			}
		]
	},{
		tokname => "concatenation",
		type => "ops",
		mode => OP_MODE_AGGREGATOR,
		value => ["repetition",
			{
				type => "ops",
				mode => OP_MODE_AGGREGATOR,
				minreps => 0,
				maxreps => -1,
				value => [qw(maybe-some-c-wsp repetition)]
			}
		]
	},{
		tokname => "repetition",
		type => "ops",
		mode => OP_MODE_AGGREGATOR,
		value => [
			{
				type => "ops",
				minreps => 0,
				maxreps => 1,
				value => [qw(repeat)]
			}, "element"
		]
	},{
		tokname => "repeat",
		type => "ops",
		mode => OP_MODE_ALTERNATOR,
		value => [
			{
				type => "ops",
				minreps => 1,
				maxreps => -1,
				value => [qw(DIGIT)]
			},{
				type => "ops",
				mode => OP_MODE_AGGREGATOR,
				value => [
					{
						type => "ops",
						minreps => 0,
						maxreps => -1,
						value => [qw(DIGIT)]
					},{type => "num-val", value => ['*']},{
						type => "ops",
						minreps => 0,
						maxreps => -1,
						value => [qw(DIGIT)]
					}
				]
			}
		]
	},{
		tokname => "element",
		type => "ops",
		mode => OP_MODE_ALTERNATOR,
		value => [qw(rulename group option char-val num-val prose-val)]
	},{
		tokname => "group",
		type => "ops",
		mode => OP_MODE_AGGREGATOR,
		value => [{type => "num-val", value => ['(']}, "maybe-some-c-wsp", "alternation", "maybe-some-c-wsp", {type => "num-val", value => [')']}]
	},{
		tokname => "option",
		type => "ops",
		mode => OP_MODE_AGGREGATOR,
		value => [{type => "terminal", value => ['[']}, "maybe-some-c-wsp", "alternation", "maybe-some-c-wsp", {type => "num-val", value => [']']}]
	},{
		tokname => "char-val",
		type => "ops",
		mode => OP_MODE_AGGREGATOR,
		value => ["DQUOTE", {type => "num-val", minreps => 0, maxreps => -1, value => [map {chr} (0x20,0x21,0x23..0x7E)]}, "DQUOTE"]
	},{
		tokname => "num-val",
		type => "ops",
		mode => OP_MODE_AGGREGATOR,
		value => [{type => "num-val", value => ["%"]}, {type => "ops", mode => OP_MODE_ALTERNATOR, value => [qw(bin-val dec-val hex-val)]}]
	},{
		tokname => "bin-val",
		type => "ops",
		mode => OP_MODE_AGGREGATOR,
		value => [
			{type => "num-val", value => ["b"]},
			{type => "ops", minreps => 1, maxreps => -1, value => [qw(BIT)]},
			{type => "ops", mode => OP_MODE_ALTERNATOR, minreps => 0, maxreps => 1, value => [
				{
					type => "ops",
					mode => OP_MODE_AGGREGATOR,
					minreps => 1,
					maxreps => -1,
					value => [{type => "num-val", value => ['.']}, {
						type => "ops",
						minreps => 1,
						maxreps => -1,
						value => [qw(BIT)]
					}]
				},{
					type => "ops",
					mode => OP_MODE_AGGREGATOR,
					value => [{type => "num-val", value => ["-"]}, {
						type => "ops",
						minreps => 1,
						maxreps => -1,
						value => [qw(BIT)]
					}]
				}
			]}
		]
	},{
		tokname => "dec-val",
		type => "ops",
		mode => OP_MODE_AGGREGATOR,
		value => [
			{type => "num-val", value => ["d"]},
			{type => "ops", minreps => 1, maxreps => -1, value => [qw(DIGIT)]},
			{type => "ops", mode => OP_MODE_ALTERNATOR, minreps => 0, maxreps => 1, value => [
				{
					type => "ops",
					mode => OP_MODE_AGGREGATOR,
					minreps => 1,
					maxreps => -1,
					value => [{type => "num-val", value => ['.']}, {
						type => "ops",
						minreps => 1,
						maxreps => -1,
						value => [qw(DIGIT)]
					}]
				},{
					type => "ops",
					mode => OP_MODE_AGGREGATOR,
					value => [{type => "num-val", value => ["-"]}, {
						type => "ops",
						minreps => 1,
						maxreps => -1,
						value => [qw(DIGIT)]
					}]
				}
			]}
		]
	},{
		tokname => "hex-val",
		type => "ops",
		mode => OP_MODE_AGGREGATOR,
		value => [
			{type => "num-val", value => ["x"]},
			{type => "ops", minreps => 1, maxreps => -1, value => [qw(HEXDIG)]},
			{type => "ops", mode => OP_MODE_ALTERNATOR, minreps => 0, maxreps => 1, value => [
				{
					type => "ops",
					mode => OP_MODE_AGGREGATOR,
					minreps => 1,
					maxreps => -1,
					value => [{type => "num-val", value => ['.']}, {
						type => "ops",
						minreps => 1,
						maxreps => -1,
						value => [qw(HEXDIG)]
					}]
				},{
					type => "ops",
					mode => OP_MODE_AGGREGATOR,
					value => [{type => "num-val", value => ["-"]}, {
						type => "ops",
						minreps => 1,
						maxreps => -1,
						value => [qw(HEXDIG)]
					}]
				}
			]}
		]
	},{
		tokname => "prose-val",
		type => "ops",
		mode => OP_MODE_AGGREGATOR,
		value => [{type => "num-val", value => ["<"]}, {type => "num-val", mode => OP_MODE_ALTERNATOR, minreps => 0, maxreps => -1, value => [map {chr} (0x20..0x3D, 0x3F..0x7E)]}, {type => "num-val", value => [">"]}]
	}
);

sub BEGIN {
	$ABNF = { ABNF_PARSETREE };
	bless $ABNF, "Parse::ABNF";
}

1;
