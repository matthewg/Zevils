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

Creates a new C<Parse::ABNF> object.  A C<Parse::ABNF> object contains a complete grammar.  It
has an internally consistant set of rules which all reduce to what in ABNF parlance
are known as "terminal values."  In other words, some rule foo might refer to some
other rule bar, but you can follow all the different rules in a grammar and eventually
get down to the definitions of the numeric values that each byte has to have.

A rule is a single definition in a grammar.  "A word consists of one or more letters" is
a rule.

If the C<RULES> parameter is present, those rules will be added to the object as if
you had called the C<add> method after creating the object.

=back

=head1 METHODS

=over

=item add ( RULES )

Adds a rule or rules (the parmeter may either be a scalar or a list) to the object.
The rules may be given in any form that RFC 2234 declares as a valid rule declaration.
fI something that isn't valid ABNF is given, the object will croak with an error like
C<Invalid ABNF Syntax: Unknown rule 'FOO'>, so use C<eval { ... }> if you don't want
that to be a fatal error.

The termination of each rule with CRLF is optional for this method.

You can modify existing rules by simply adding them with their new values.

=item delete ( RULES )

Removes C<RULES> from the object.  C<RULES> may be a scalar or a list, but it should consist
of the names of the rules to remove from the object.  If the removal of any rule listed for deletion would cause
the object to no longer contain a complete grammar, no rules will be deleted and instead the object will croak
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

=item matches ( RULE, DATA )

Returns true if the scalar C<DATA> matches C<RULE>.  Otherwise, returns false.

This is a wrapper around the I<regex> method.

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

sub new($;@) {
	my $class = ref($_[0]) || $_[0] || "Parse::ABNF";
	my $self = {};
	bless $self, $class;
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

sub matches($$$) {
	my($self, $rule, $data) = @_;

	if($data =~ /$self->regex($rule)/) {
		return 1;
	} else {
		return 0;
	}
}

1;
