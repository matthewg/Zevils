# Text::ABNF
#
# Copyright (c) 2001 Matthew Sachs <matthewg@zevils.com>.  All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Text::ABNF;

=head1 NAME

Text::ABNF v. 0.01 - Perl module for dealing with Augmented Backus-Naur Form (ABNF)

=head1 SYNOPSIS

    # First, we create a Text::ABNF object.
    $word = Text::ABNF->new;

    # Then we add some rules.
    $word->add("LETTER", "CHAR");
    $word->add("WORD", "1*LETTER"); # A word is one or more letters

    # Now get the 'word' rule in various forms...
    print "A word consists of ", $word->text("WORD"), "\n";
    print "$foo is a word.\n" if $word->matches("WORD", $foo);
    print "word = ", $word->abnf("WORD"), "\n";

=head1 DESCRIPTION

This modules provides various methods for dealing with Augmented Backus-Naur Form (ABNF).
Amongst other things, It can conver ABNF to either English description of the syntax or
a regular expression.  ABNF is defined in C<RFC 2234>.  It is a grammar, similar in concept
to the regular expressions that Perl is renowned for, which is often used
for specifying format syntaxes in technical specifications.  Many
Internet standards use ABNF to define various protocols.

C<Text::ABNF> objects will, by default, contain the rules listed in Appendix A of C<RFC 2234>.
These rules define some basic entities like C<ALPHA>, C<BIT>, C<CHAR>, and C<DIGIT>.

For any of the methods which take a rule name and return some value, the object will croak
with the error C<Unknown ABNF rule: RULENAME>.

=head1 CONSTRUCTOR

=over 4

=item new

Creates a new C<Text::ABNF> object.  A C<Text::ABNF> object contains a complete grammar.  It
has an internally consistant set of rules which all reduce to what in ABNF parlance
are known as "terminal values."  In other words, some rule foo might refer to some
other rule bar, but you can follow all the different rules in a grammar and eventually
get down to the definitions of the numeric values that each byte has to have.

A rule is a single definition in a grammar.  "A word consists of one or more letters" is
a rule.

=back

=head1 METHODS

=over

=item add ( NAME => ELEMENTS )

This method should be called with a single parameter, a hash whose keys are the names
of rules to add and whose values are the elements which the rules are made up of.

Adds a rule called C<NAME> to the object.  C<ELEMENTS> is the definition of the rule in
ABNF form.  If something that isn't valid ABNF is given in the C<ELEMENTS> parameter,
the object will croak with an error like C<Invalid ABNF Syntax: Unknown rule 'FOO'>,
so use C<eval { ... }> if you don't want that to be a fatal error.

=item delete ( RULES )

Removes C<RULES> from the object.  C<RULES> may be a scalar or a list.  If the removal of
C<RULES> would cause the object to no longer contain a complete grammar, C<RULES> will not
be deleted and instead the object will croak with the error
C<Could not remove ABNF rules: RULES>.

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

=item matches ( RULE, DATA )

Returns true if the scalar C<DATA> matches C<RULE>.  Otherwise, returns false.

This is a wrapper around the I<regex> method.

=back

=head1 BUGS

The I<text> method doesn't try to be at all intelligent about pluralizing things, so if
you have a rule named C<fish>, and another rule C<school> which consists of one or more
C<fish>, C<text("school")> will return C<consists of one or more fishs>.

=head1 SEE ALSO

RFC 2234

=head1 AUTHOR

Matthew Sachs <matthewg@zevils.com>

=cut


$VERSION = '0.01';

use strict;
use warnings;
use vars qw($VERSION);

sub new {
	my $class = ref($_[0]) || $_[0] || "Text::ABNF";
	@_ == 1 or croak "usage: new $class";
	my $self = {};
	bless $self, $class;
}

1;
