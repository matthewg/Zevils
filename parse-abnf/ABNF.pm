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
	print "A word is ", $word->text("WORD"), "\n";
	print "$foo is a word.\n" if $foo =~ /$word->regex("WORD")/;
	print "word = ", $word->abnf("WORD"), "\n";


=head1 DESCRIPTION

This modules provides various methods for dealing with Augmented Backus-Naur Form (ABNF).
Amongst other things, It can conver ABNF to either English description of the syntax or
a regular expression.  ABNF is defined in RFC 2234.  It is a grammar, similar in concept
to the regular expressions that Perl is renowned for, which is often used
for specifying format syntaxes in technical specifications.  Many
Internet standards use ABNF to define various protocols.

Text::ABNF objects will, by default, contain the rules listed in Appendix A of RFC 2234.
These rules define some basic entities like ALPHA, BIT, CHAR, and DIGIT.

=head1 METHODS

=item new

Creates a new Text::ABNF object.  A Text::ABNF object contains a complete grammar.  It
has an internally consistant set of rules which all reduce to what in ABNF parlance
are known as "terminal values."  In other words, some rule foo might refer to some
other rule bar, but you can follow all the different rules in a grammar and eventually
get down to the definitions of the numeric values that each byte has to have.

A rule is a single definition in a grammar.  "A word consists of one or more letters" is
a rule.


=cut


$VERSION = '0.01';

use strict;
use warnings;
use vars qw($VERSION);

sub new {
	my $class = shift;
	unshift

