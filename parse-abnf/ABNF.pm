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

If C<DATA> I<does> match C<RULE> and the optional parameter C<MATCHRULES> is not present, a true value is returned.

C<MATCHRULES>, if present, should be a list of rule names whose values you are interested in.  For instance, if
you have a rule C<preference = name *WSP "=" *WSP value>, calling this method with C<RULE> set to C<"preference"> and
C<MATCHRULES> set to C<("name", "value")> will cause the return value to be, if C<DATA> matches the C<preference>
rule, a hashref whose keys are C<("name", "value")> and whose values are whichever bits of C<DATA> matched those rules.
So, assuming that the C<name> and C<value> rules were set appropriately, if C<DATA> was C<"logfile = /var/log/foo.log">,
the return value would be C<< {name => ["logfile"], value => ["/var/log/foo.log"]} >>.

However, it can get more complicated than that.  Consider the following ruleset:

    paragraph = HTAB 1*sentence (CR / LF / CRLF)
    sentence = word *(" " / word) ("." / "?" / "!") 0*2" "
    word = 1*VCHAR

If the C<matches> method were called on an object with that ruleset with C<RULE> set to C<"paragraph">,
C<DATA> set to C<"\tHello, world!  Wanna augment my BNF?\n">, and C<MATCHRULES> set to C<("sentence", "word")>,
the return value would be:

    { sentence =>
        [
            [
                { word => ["Hello,"] },
                " ",
                { word => ["world"] },
                "!  "
            ],
            [
                { word => ["Wanna"] },
                " ",
                { word => ["augment"] },
                " ",
                { word => ["my"] },
                " ",
                { word => ["BNF"] },
                "?"
            ]
        ]
    }

Had C<"paragraph"> also been in C<MATCHRULES>, the only difference would be that the above would be
the in a listref along with a tab and a newline.  If this doesn't make sense to you, should should
try experimenting.

That's the "structured parse form".  There's another form that you might find more useful -
see C<explode_matches> below.

A C<MATCHRULES> of "*" will match all (non-core) rules.

Note that this method must match beginning at the first character of the data, but it is considered
acceptable to have extra data left over at the end.  I'm not sure if that's The Right Thing or not...

=item explode_matches

This can either take the same arguments as C<matches>, or it can take the return value from
a call to C<matches> where C<MATCHRULES> was given.  It returns the same information as
the parse tree returned by C<matches> when you give it C<MATCHRULES> but in a different form.
The return value is a hashref whose keys are all rules in C<MATCHRULES> which were matched by
the data and whose values are listrefs containing the data matched by the rules.  For instance,
if the final example given for a return value for C<matches> was exploded, it would become:

    {
        sentence => ["Hello, world!  Wanna augment my BNF?"],
        word => [
            "Hello,",
            "world",
            "Wanna",
            "augment",
            "my",
            "BNF"
        ]
    }

Alright, I know it's all very confusing.  If you figure out a better way to explain it or a simpler
way of doing it in the first place, let me know.

=back

=head1 SEE ALSO

RFC 2234

=head1 AUTHOR

Matthew Sachs <matthewg@zevils.com>

=cut


$VERSION = '0.01';

use strict;
use warnings;
use vars qw($VERSION $ABNF $AUTOLOAD @ISA $tablevel);
use Symbol;
use Lingua::EN::Inflect qw(PL);
use Carp;
use Parse::ABNF::Common qw(:all);
use Parse::ABNF::OpTree;
use Parse::ABNF::ParseTree;

# Some methods are defined in these modules.
@ISA = qw(Parse::ABNF::OpTree Parse::ABNF::ParseTree);

$tablevel = -1;

# =============================================================================================================================
#
# Well, if you're reading the source code, you probably want to know something about the internals of this beast.
# First, a warning to the educated: I have no formal knowledge of parsing, so my terminology probably differs from yours.
# What we do is we parse the ABNF that the user gives us and turn it into an "op tree".  This op tree is a sequence
# of operands: ops, numeric values, or character values (this is the op's "type".)  Note that the terms "numeric" and "character" values are deceiving.
# They are both byte sequence which must be matched.  The only difference is that character values are matched as case-insensitive
# strings while numeric values are matched exactly.  Each operand has a value and mode as well as an optional minimum repeat count
# and maximum repeat count.  Char-val and num-val are terminal operands - the "leaves" of the tree (except that our data structure is not a tree, of course.)
#
# Oh, the let's back up a bit.  An op tree is a hashref whose keys are the names of operands and whose values are those operands.
#
# Operands can have a number of traits.
#
# You've already been introduced to the type trait.
#
# The first two traits, minreps and maxreps, work as a pair.  They are used to specify repeat counts - that is, how many
# times an operand may be matched.  If they are not specified, an operand must be matched once and only once.  If one
# is present, however, the other must also be present.  A maxreps of -1 is used to signify no upper bound on the number of
# repetitions.
#
# Each operand can be an alternator, an aggregator, or a singleton.  This is known as the op's mode.
# An alternator will match any of its values once and only once (per repeat - if maxreps is greater than 1, it may match a
# different operand on the next repetition.)  An aggregator must match all of its values in the order that they are present.
# A singleton only has one value.  The singleton mode is the default.  Singletons are really only there for completeness -
# they are arbitrarily treated as one of the other types internally.  Some day we might use the knowledge that an op is a
# singleton for optimization purposes, however.
#
# Operands of the "op" type are collections of other operands.  They are used as connectors to form complicated constructs.
# You also need ops to form larger rules from collections of smaller ones. Ops have lists of tokens as their values.
# These lists can contain a mixture of strings which are the names of other tokens and literal operands given as anonymous hashes.
#
# That will all make a lot more sense once you look at the parse tree for CORE_RULES given below, or if you're feeling
# ambitious the parse tree for ABNF itself given even further below... go do that and then come back here.
#
#
# Okay, so how do we generate these parse trees?  Well, we have to parse the ABNF given to us in the add method.
# In order to do this, I've hard-coded in a parse tree for ABNF that I made by hand based on section 4 of the RFC.
# Pretty neat, no?  Think about it - this lets us just use this one parsing engine for generating parse trees from
# the user's ABNF and for parsing against the user's ABNF.  We take the hand-written parse tree and just bless it
# into a Parse::ABNF object.
#
#	"Now no shrub of the field had yet grown on the earth, and no plant of the field had yet sprouted,
#	 for the Lord God had not caused it to rain on the earth, and there was no man to cultivate the
#	 ground.  ... The Lord God formed the man from the soil of the ground and breathed into his
#	 nostrils the breath of life, and the man became a living being."  --Genesis 2:5-7
#
#
# Once you have the parse tree, the rest is pretty self-explanatory.  I mean it's not easy, but there's no special
# trick.  You just go through the parse tree...  Alright, so there are special tricks, but you'll have to look at
# the matches method if you want to know about them.
#
#
# Note that some methods, constants, etc. are defined in the other Parse::ABNF:: modules.
#
# =============================================================================================================================


sub new($;@) {
	my $class = ref($_[0]) || $_[0] || "Parse::ABNF";
	shift;
	my $self = { CORE_RULES };
	bless $self, $class;
	$self->{DEBUG} = 0;
	$self->add(@_) if @_ > 0;
	return $self;
}

sub delete($@) {
	my($self, @rules) = @_;
	my $rule;

	delete $self->{$rule};
}

sub text($$) {
	my($self, $rule) = @_;

	croak "ABNF unimplemented method: text";
	#PL("foo", 2);
}

sub regex($$) {
	my($self, $rule) = @_;

	croak "ABNF unimplemented method: regex";

}

sub abnf($$) {
	my($self, $rule) = @_;

	croak "ABNF unimplemented method: abnf";
}

sub rules($;$) {
	my($self, $rule) = @_;

	croak "ABNF unimplemented method: rules" if $rule;
	return keys %$self;
}

sub BEGIN {
	$ABNF = {ABNF_PARSETREE};
	bless $ABNF, "Parse::ABNF";
}

sub DEBUG {
	my $self = shift;
	$self->{DEBUG} = shift;
}

1;
