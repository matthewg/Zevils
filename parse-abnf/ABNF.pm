# Parse::ABNF
#
# Copyright (c) 2001 Matthew Sachs <matthewg@zevils.com>.  All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Parse::ABNF;

=head1 NAME

Parse::ABNF v. 0.01 - Perl module for dealing with Augmented Backus-Naur Form (ABNF)

=head1 SYNOPSIS

    # First, we create a Parse::ABNF object.
    $word = Parse::ABNF->new;

    # Then we add some rules.
    $word->add("LETTER=CHAR");
    $word->add("WORD=1*LETTER"); # A word is one or more letters

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

For any of the methods which take a rule name and return some value, the object will croak
with the error C<Unknown ABNF rule: RULENAME>.

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
you had called the C<add> method after creating the object.

=back

=head1 METHODS

=over

=item add ( RULES )

Adds a rule or rules (the parameter may either be a scalar or a list) to the object.
The rules may be given in any form that RFC 2234 declares as a valid rule declaration.
fI something that isn't valid ABNF is given, the object will croak with an error like
C<Invalid ABNF Syntax: Unknown rule 'FOO'>, so use C<eval { ... }> if you don't want
that to be a fatal error.

The termination of each rule with CRLF is optional for this method.

You can modify existing rules by simply adding them with their new values.

=item delete ( RULES )

Removes C<RULES> from the object.  C<RULES> may be a scalar or a list, but it should consist
of the names of the rules to remove from the object.  If the removal of any rule listed for deletion would cause
the object to no longer contain a viable ruleset (for instance, if the ruleset contains rules which refer to a rule
that you are attempting to remove,) no rules will be deleted and instead the object will croak
with the error C<Could not remove ABNF rules: RULES>.

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
use vars qw($VERSION);
use Lingua::EN::Inflect qw(PL);
use Carp;

use constant CORE_RULES => <<END; #As defined in RFC 2234 appendix A
ALPHA          =  %x41-5A / %x61-7A   ; A-Z / a-z
BIT            =  "0" / "1"
CHAR           =  %x01-7F             ; any 7-bit US-ASCII character, excluding NUL
CR             =  %x0D                ; carriage return
CRLF           =  CR LF               ; Internet standard newline
CTL            =  %x00-1F / %x7F      ; controls
DIGIT          =  %x30-39             ; 0-9
DQUOTE         =  %x22                ; " (Double Quote)
HEXDIG         =  DIGIT / "A" / "B" / "C" / "D" / "E" / "F"
HTAB           =  %x09                ; horizontal tab
LF             =  %x0A                ; linefeed
LWSP           =  *(WSP / CRLF WSP)   ; linear white space (past newline)
OCTET          =  %x00-FF             ; 8 bits of data
SP             =  %x20                ; space
VCHAR          =  %x21-7E             ; visible (printing) characters
WSP            =  SP / HTAB           ; white space
END



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
	my $rule;

}

sub matches($$$;@) {
	my($self, $rule, $data, @matchrules) = @_;

}


use constant REGEX_WHITESPACE => '[ \t]*'
sub _parse_rules($$) {
	my($self, $rules) = @_;

	while($rules =~ m/
		^\( # Rules or comments
			\( # A rule
				[a-zA-Z][-a-zA-Z0-9]*		# A rule name
				\( # Defined as...
					[ \t]*| # Whitespace or
			\(;\([ \t][\x21-\x7E]*\)
	/x
}

1;
