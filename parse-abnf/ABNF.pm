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
use vars qw($VERSION $ABNF $tablevel);
use Symbol;
use Lingua::EN::Inflect qw(PL);
use Carp;

$tablevel = -1;

# Well, if you're reading the source code, you probably want to know something about the internals of this beast.
# First, a warning to the educated: I have no formal knowledge of parsing, so my terminology probably differs from yours.
# What we do is we parse the ABNF that the user gives us and turn it into an "op tree".  This op tree is a sequence
# of operands: ops, numeric values, or character values.  Note that the terms "numeric" and "character" values are deceiving.
# They are both byte sequence which must be matched.  The only difference is that character values are matched as case-insensitive
# strings while numeric values are matched exactly.  Each operand has a value and mode as well as an optional minimum repeat count
# and maximum repeat count.  Char-val and num-val are terminal operands and are the leafiest parts of the tree.
# The value of char-val is a string which is matched case-insensitively.  The value of a num-val is a string which is matched as
# an exact byte-sequence.
#
# Oh, the let's back up a bit.  An op tree is a hashref whose keys are the names of operands and whose values are those operands.
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

use constant OP_TYPE_OPS => 1;
use constant OP_TYPE_NUMVAL => 2;
use constant OP_TYPE_CHARVAL => 3;

use constant OP_MODE_SINGLETON => 0;
use constant OP_MODE_ALTERNATOR => 1;
use constant OP_MODE_AGGREGATOR => 2;

use constant CORE_RULES => ( #As defined in RFC 2234 appendix A
	alpha => { type => OP_TYPE_NUMVAL, mode => OP_MODE_ALTERNATOR, value => [map {chr} (0x41..0x5A, 0x61..0x7A)], core=>1 }, 	# A-Z / a-z
	bit => { type => OP_TYPE_NUMVAL, mode => OP_MODE_ALTERNATOR, value => [qw(0 1)], core=>1 },
	char => { type => OP_TYPE_NUMVAL, mode => OP_MODE_ALTERNATOR, value => [map {chr} (0x01..0x7F)], core=>1 }, 			# any 7-bit US-ASCII character, excluding NUL
	cr => { type => OP_TYPE_NUMVAL, value => [chr(0x0D)], core=>1 }, 								# carriage return
	crlf => { type => OP_TYPE_OPS, mode => OP_MODE_AGGREGATOR, value => [qw(CR LF)], core=>1 }, 					# Internet standard newline
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
	vchat => { type => OP_TYPE_NUMVAL, mode => OP_MODE_ALTERNATOR, value => [map {chr} (0x21..0x7E)], core=>1 }, 			# visible (printing) characters
	wsp => { type => OP_TYPE_OPS, mode => OP_MODE_ALTERNATOR, value => [qw(sp htab)], core=>1 } 					# white space
);



sub new($;@) {
	my $class = ref($_[0]) || $_[0] || "Parse::ABNF";
	shift;
	my $self = { CORE_RULES };
	bless $self, $class;
	$self->add(@_) if @_ > 0;
	return $self;
}

sub printparse($$) {
	my ($self, $parse) = @_;
	my $inrule;

	$tablevel = 0;
	if(not ref($parse)) {
		print "$parse\n";
		return;
	}
	$parse = $parse->[0] if ref($parse) eq "ARRAY";
	print ${*$parse}, ":\n";
	print $self->_printparse(@{*$parse}), "\n";
}

sub _printparse {
	my $self = shift;
	my @syms = @_;
	my $sym;
	my $retval = "";

	$tablevel++;
	foreach $sym(@syms) {
		if(ref($sym) eq "GLOB") {
			my $name = ${*$sym} || "";
			my @values = @{*$sym};

			$retval .= "\t"x$tablevel. "$name = \n". $self->_printparse(@values);
		} elsif(ref($sym) eq "ARRAY") {
			$retval .= $self->_printparse(@$sym);
		} else {
			$retval .= "\t"x$tablevel. "$sym,\n";
		}
	}
	$tablevel--;
	#warn "Returning $retval\n";
	return $retval;
}

sub add_ruleparse($$$;$) {
	my ($self, $rule, $intoks, $parent) = @_; # Do not use this method while intoksicated! ;)
	my @intoks = ref($intoks) eq "GLOB" ? @{*$intoks} : @$intoks;
	my $rulename = "";
	my $intok;
	my @saverules;

	$rulename = ${*$intoks} if ref($intoks) eq "GLOB";
	#print tabify("$rulename\n") if $rulename;
	if($rulename eq "char-val") { #strip surrounding ""
		chop $intoks[0];
		substr($intoks[0], 0, 1, "");
	} elsif($rulename eq "prose-val") {
		croak "ABNF error: prose-vals (rule elements enclosed in <angle brackets>) are not supported: $intoks[0]";
	}

	foreach $intok(@intoks) {
		#print tabify("Got $intok.\n");
		if(ref($intok) eq "GLOB") {
			#print tabify("Got GLOB.\n");
			$tablevel++;
			$self->add_ruleparse($rule, $intok, $rulename);
			$tablevel--;
		} elsif(ref($intok) eq "ARRAY") {
			#print tabify("Got ARRAY.\n");
			$self->add_ruleparse($rule, $intok, $rulename);
		} else {
			if($rulename eq "rulename" or $rulename eq "group" or $rulename eq "option" or $rulename =~ /(char|bin|dec|hex)-val/) {
				my ($type, $minreps, $maxreps, $rulebak);

				if($rulename eq "char-val") {
					$type = OP_TYPE_CHARVAL;
				} elsif($rulename =~ /val$/) {
					$type = OP_TYPE_NUMVAL;
				} else {
					$type = OP_TYPE_OPS;
				}

				if($self->{nextalt}) {
					if(scalar(@{$rule->{value}}) > 1 and $rule->{mode} != OP_MODE_ALTERNATOR) { #Something like foo bar / baz
						my $newval = {
							mode => OP_MODE_ALTERNATOR,
							type => $rule->{type},
							value => [pop @{$rule->{value}}]
						};
						push @{$rule->{value}}, $newval;
						$rulebak = $rule;
						$rule = $newval;
					} else {
						$rule->{mode} = OP_MODE_ALTERNATOR;
					}
					delete $self->{nextalt};
				}
				$rule->{mode} ||= OP_MODE_AGGREGATOR;

				if($self->{nextrep}) {
					$self->{nextrep} =~ /(\d*)\*?(\d*)/;
					$minreps = $1 || 0;
					$maxreps = $2 || -1;
				}

				if($rulename eq "option") {
					if($intok eq "[") {
						delete $self->{nextrep};
						push @saverules, $rule;
						$rule = {};
						$rule->{minreps} = 0;
						$rule->{maxreps} = 1;
						push @{$saverules[-1]->{value}}, $rule;
					} else {
						$rule = pop @saverules;
					}
				} elsif($rulename eq "group") {
					if($intok eq "(") {
						push @saverules, $rule;
						$rule = {};
						if($self->{nextrep}) {
							$rule->{minreps} = $minreps;
							$rule->{maxreps} = $maxreps;
							delete $self->{nextrep};
						}
						push @{$saverules[-1]->{value}}, $rule;
					} else {
						$rule = pop @saverules;
					}
				} elsif($rulename =~ /-val$/ or $rulename eq "rulename") {
					my $tmprule = $rule;

					#"foo" 1*2"bar"
					if($self->{nextrep}) {
						delete $self->{nextrep};
						$tmprule = {};
						$tmprule->{type} = $type;
						$tmprule->{minreps} = $minreps;
						$tmprule->{maxreps} = $maxreps;
						$tmprule->{mode} = $rule->{mode};
						$rule->{type} ||= OP_TYPE_OPS;
						if($rule->{type} != OP_TYPE_OPS) {
							$rule->{value} = [
								{
									type => $rule->{type},
									mode => $rule->{mode},
									value => $rule->{value}
								},
								$tmprule
							];
							
							$rule->{type} = OP_TYPE_OPS;
						} elsif($rule->{value} and scalar(@{$rule->{value}})) {
							push @{$rule->{value}}, $tmprule;
						} else {
							$tmprule = $rule;
							$rule->{minreps} = $minreps;
							$rule->{maxreps} = $maxreps;
						}
					}

					if(exists($tmprule->{type}) and $tmprule->{type} != $type) { 
						my $newval = {
							mode => $tmprule->{mode},
							type => $type,
						};
						if($tmprule->{type} != OP_TYPE_OPS) {
							$tmprule->{value} = [
								{
									type => $tmprule->{type},
									mode => $tmprule->{mode},
									value => $tmprule->{value}
								},
								$newval
							];
							$tmprule->{type} = OP_TYPE_OPS;
						} else {
							push @{$tmprule->{value}}, $newval;
						}
						$tmprule = $newval;
					}
					$tmprule->{type} = $type;

					if($rulename eq "bin-val" or $rulename eq "dec-val" or $rulename eq "hex-val") {
						$intok =~ /^[bdx]([0-9A-Fa-f]+)([-.]?)([0-9A-Fa-f]*)$/;
						my $left = $1;
						my $conjunction = $2;
						my $right = $3;
						if($rulename eq "hex-val") {
							$left = hex $left;
							$right = hex $right if $right;
						} elsif($rulename eq "bin-val") {
							$left = oct "0b$left";
							$right = oct "0b$right" if $right;
						}

						if($conjunction) {
							$tmprule->{mode} = OP_MODE_ALTERNATOR; #Is this always correct?  I think concatenated foo-vals always get their own op, no?

							if($conjunction eq "-") {
								push @{$tmprule->{value}}, map {chr} ($left..$right);
							} elsif($conjunction eq ".") {
								push @{$tmprule->{value}}, chr($left), chr($right);
							}
						} else {
							push @{$tmprule->{value}}, chr($left);
						}
					} elsif($rulename eq "char-val" or $rulename eq "rulename") {
						push @{$tmprule->{value}}, $intok;
					}
				}
				$rule = $rulebak if $rulebak;
			} elsif($rulename eq "repeat") {
				$self->{nextrep} = $intok;
			} elsif($rulename eq "num-val") {
				#ignore the %
			} elsif($intok =~ m!^\s*/\s*$! and $parent eq "alternation") {
				$self->{nextalt} = 1; # Next thingy should be alternated w/ previous thingy
			} else {
				print tabify(Data::Dumper->Dump([$intok], [$rulename])) if $intok =~ /\S/;
			}
		}
	}
}


sub add($@) {
	my ($self, @rules) = @_;
	my $rule;


	# strip comments, whitespace / newline between rules
	$rule = join("\n", @rules);
	$rule =~ s/;[ \t\x21-\x7E]*$//mg; # strip comments
	$rule =~ s/[\r\n]{1,2}[ \t]+/ /g; # join continued lines
	while($rule =~ /[\r\n]{2,}/) { $rule =~ s/[\r\n]{2,}/\n/; } # remove extraneous newlines
	$rule =~ s/[\r\n](?![^\r\n])//g; # remove trailing newlines
	$rule =~ s/^[\r\n]+//; # remove leading newlines
	$rule =~ s/[ \t]$//g; # remove trailing whitespace from lines
	$rule .= "\n"; # but we need a terminal newline

	my $parse = $ABNF->matches("rulelist", $rule, qw(rule rulename defined-as elements element repeat group option alternation char-val num-val bin-val dec-val hex-val prose-val));
	#$self->printparse($parse);
	my $inrule;

	foreach $inrule(@$parse) {
		my $rulename = ${*$inrule}[0]; #rulename is now the glob for rulename
		$rulename = ${*$rulename}[0]; #This gets the actul rule name.
		$self->{$rulename} ||= {};
		my $rule = $self->{$rulename};
		my $defined = ${*$inrule}[1];
		$defined = join("", @{*$defined});
		$defined =~ tr/ //d; #Either = or =/
		$self->{nextalt} = 1 if $defined eq "=/";
		my $elements = ${*$inrule}[2];
		$tablevel = 0;
		$self->add_ruleparse($rule, $elements, "alternation");
	}
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

sub op_is_fork($$) { #Is there more than one way to match this op?
	my($self, $op) = @_;

	$op = $self->{$op} unless ref($op);
	my $minreps = $op->{minreps} || 1;
	my $maxreps = $op->{maxreps} || 1;

	return 1 if $minreps != $maxreps;
	return 1 if $op->{mode} and $op->{mode} == OP_MODE_ALTERNATOR and scalar(@{$op->{value}}) > 1;
	return 0;
}

# Woah, what's going on here?
# What's with the matches being this thin wrapper for this _matches thing?
# Well, _matches is recursive, right?  The child-matches needs to be able to
# modify the parent-matches $data.  So we do this by declaring it dynamically scoped.
#
# But if we did that in the same scope as our matching routine, then when we recursed
# we'd do that declaration again and hide the $data that we're interested in.
# 
# Hence the wrapper.
#
# If that makes sense to you then I congratulate you on your understanding of perl's scoping rules.

sub matches($$$;@) {
	my($self, $rule, $tmpdata, @matchrules) = @_;
	my $nomatchself = 1;
	my $ret;
	our $data;
	$data = $tmpdata;
	$tablevel = -1;

	if($matchrules[0] eq "*") {
		@matchrules = grep { not exists $self->{$_}->{core} } keys %$self;
	}

	if(@matchrules) { # $rule needs to be in @matchrules, so we use this hack to compensate
		my $tmprule;
		foreach $tmprule(@matchrules) {
			if($tmprule eq $rule) {
				$nomatchself = 0;
				last;
			}
		}
	}
	push @matchrules, $rule;
	undef $ret;
	$ret = $self->_matches($rule, $rule, undef, undef, 0, @matchrules);
	if($ret and @matchrules and $nomatchself) {
		$ret = [@{*$ret}];
	}
	return $ret;
}

sub tabify($) {
	no strict qw(vars);
	my $what = shift;
	my $tabstr;

	$tabstr = "\n" . "\t" x ($tablevel+1);
	return "\t"x($tablevel+1) . join($tabstr, split(/\n/, $what)) . "\n" . "\t"x$tablevel;
}

sub obj($) {
	my $obj = shift;

	if(ref($obj)) {
		if(ref($obj) eq "GLOB") {
			return "\n".tabify(Data::Dumper->Dump([\@{*$obj}], ["*".${*$obj}]));
		} else {
			return "\n".tabify(Data::Dumper::Dumper($obj));
		}
	} else {
		return $obj;
	}
}

sub multival($$) {
	my($self, $tok) = @_;
	$tok = $self->{$tok} unless ref($tok);

	return 0 unless $tok and $tok->{value};
	return 1 if scalar(@{$tok->{value}}) > 1;
	return 0;
}

sub _matches($$$;$$$@) {
	my($self, $rule, $tokname, $inplay, $outplay, $doplay, @matchrules) = @_;
	no strict qw(vars); # We need this because $data comes from matches which the compiler doesn't know yet.
	
	my $foodata = $data;
	chomp $foodata;

	my $litrule = 0;
	if(!ref($rule)) {
		$litrule = $rule;

	}
	$tablevel++;
	#warn "\t"x$tablevel . "_matches($litrule) called with doplay=$doplay".($inplay?(", inplay=".Data::Dumper->new([$inplay])->Terse(1)->Indent(0)->Dump):"").", data='$foodata'\n";

	# We convert @matchrules into a hash for our own convenience
	my ($matchrule, %matchrules);
	foreach $matchrule(@matchrules) {
		$matchrules{$matchrule} = 1;
	}

	$tokname = "" unless exists $matchrules{$tokname};

	unless(ref($rule)) { # $rule may be a hashref to an op
		$rule = $self->{lc($rule)} or croak "Unknown ABNF rule: $litrule";
	}

	my ($rep, $maxreps, $minreps, $mode, @matchvalues, $matchvalue, $didmatch, $retval, $prevdata, $repplay, $playback, @my_playback, @opmatches);
	$rule->{type} ||= 0;
	if($rule->{type} == OP_TYPE_OPS and $tokname eq $litrule) {
		$retval = gensym;
	} elsif($rule->{type} == OP_TYPE_OPS) {
		$retval = [];
	} else {
		$retval = "";
	}

	# What, I go to the trouble of writing a parser for you and now you want me to comment it?
	# Especially the really complex critical methods?  Fine, I guess you don't care if your little
	# old coder who was writing ABNF parsers for you when you were a baby curls up and dies from
	# stress.  All you think about is yourself.  But that's okay, nobody cares about little old me,
	# I mean you're a big-shot programmer who is obviously very busy since he doesn't have time to
	# call his little old module writer, or god forbid write a letter...
	#
	# Bloody ingrate.
	#
	# @data is an array because it lets us backtrack.  That is, if we have nested groups of alternatives
	# and an inner alternative doesn't match, we can bounce back to one of the other outer alternatives.
	# In other words, if you have (foo ((bar / baz) buzz) / quux), we match foo and then we'll try to match bar.
	# Bar doesn't match so we try baz.  That matches so it's on to buzz.  But buzz doesn't match, so we want to
	# backtrack to the state of $data right after we matched foo before we try quux.
	#
	# Each operand has @matchvalues.  We go through those in a loop, the terminating condidition of which varies
	# depending on if the current op is an aggregator or an alternator.  The current @matchvalues is $matchvalue.
	#
	#
	# Oh, and this prevdata thing?  When we have an aggregator, we need to keep chopping away at data after
	# a match.  But maybe halfway through the aggregator, a match will fail which causes the whole aggregator
	# to fail.  And maybe we have another branch of an alternator that we can fall back on.  So data needs
	# to be restored to the state it was in before we started down the failed aggregator.

	$maxreps = exists($rule->{maxreps}) ? $rule->{maxreps} : 1;
	$minreps = exists($rule->{minreps}) ? $rule->{minreps} : 1;
	@matchvalues = @{$rule->{value}};
	$mode = exists($rule->{mode}) ? $rule->{mode} : OP_MODE_ALTERNATOR; #singleton is effectively the same as either one

	@my_playback = ();
	@opmatches = ();
	REP: for($rep = 0; $rep < $minreps or ($maxreps == -1 or $rep < $maxreps); $rep++) {
		$repplay = shift @$inplay if $inplay and not $doplay;
		undef $didmatch;
		$prevdata = $data;
		my $currval = 0;
		MATCHVALUE: foreach $matchvalue(@matchvalues) {
			#This is where playback gets done.
			#Skip to the next matchvalue until the currep is the same one as last time.
			#BUT!  If this is the last branchpoint that matched, this is the time to try something different.
			#
			next MATCHVALUE if defined($repplay) and $currval <= $repplay;

			if($rule->{type} != OP_TYPE_OPS) {
				if($rule->{type} == OP_TYPE_NUMVAL) {
					$didmatch = substr($data, 0, length($matchvalue)) eq $matchvalue;
				} elsif($rule->{type} == OP_TYPE_CHARVAL) {
					$didmatch = substr(lc($data), 0, length($matchvalue)) eq lc($matchvalue);
				} else {
					croak "Invalid ABNF operand type: ".$rule->{type};
				}
				if($didmatch) {
					$retval .= $matchvalue;
					$data = substr($data, length($matchvalue)); # Exorcise the bit that we matched from the start of $data
				} else {
					undef $didmatch;
				}

			} else {
				my $nexttok;

				if(ref($matchvalue)) {
					$nexttok = $tokname;
				} else {
					if(exists($matchrules{$matchvalue})) {
						$nexttok = $matchvalue;
					} else {
						$nexttok = $tokname;
					}
				}
				$playback = shift @$inplay if $doplay and $self->op_is_fork($matchvalue) and @$inplay;

				my $next_inplay = undef;
				my $next_outplay = undef;
				my $next_doplay = 0;

				if(scalar(@matchvalues) == 1) {
					$next_outplay = $outplay;
				} else {
					$next_outplay = \@my_playback;
				}

				if(not $self->multival($matchvalue)) {
					$next_inplay = $inplay;
					$next_doplay = $doplay;
				} else {
					$next_inplay = $playback if $playback and $doplay and $self->op_is_fork($matchvalue) and not @$inplay;
				}

				$didmatch = $self->_matches($matchvalue, $nexttok, $next_inplay, $next_outplay, $next_doplay, @matchrules);
				if(defined($didmatch) and exists($matchrules{$tokname})) {
					if($litrule eq $tokname) {
						${*$retval} = $tokname;

						# Here we take pains to collapse multiple anonymous scalar matches.
						# For instance, if we have a rule that matches *CHAR, we want to return the match as a single scalar and not as an array of separate one-character matches.
						# Unless, of course, CHAR is in @matchrules.

						if((not ref($didmatch) or (ref($didmatch) eq "ARRAY" and not grep { ref($_) } @$didmatch)) and not grep { ref($_) } @{*$retval}) { #retval and didmatch are all simple values
							${*$retval}[0] = "" unless defined ${*$retval}[0]; #Make sure the array exists before writing to [-1]
							if(ref($didmatch) eq "ARRAY") {
								${*$retval}[-1] .= join("", @$didmatch);
							} else {
								${*$retval}[-1] .= $didmatch;
							}
						} else {
							push @{*$retval}, $didmatch; #(ref($didmatch) eq "ARRAY") ? @$didmatch : $didmatch;
						}
					} else {
						if(ref($didmatch) eq "ARRAY" and not grep { ref($_) } @$didmatch and not grep { ref($_) } @$retval) {
							$retval->[0] = "" unless defined $retval->[0]; #Make sure the array exists before writing to [-1]
							$retval->[-1] .= join("", @$didmatch);
						} else {
							push @$retval, $didmatch; #(ref($didmatch) eq "ARRAY") ? @$didmatch : $didmatch;
						}
					}
				} elsif(defined($didmatch)) {
					$retval = $didmatch;
				}
			}

			# We have a couple of terminal conditions for matching this op...
			last MATCHVALUE if $mode == OP_MODE_ALTERNATOR and defined $didmatch;
			last REP if $mode == OP_MODE_AGGREGATOR and not defined $didmatch;
		} continue {
			$currval++;
		}

		if(not defined $didmatch) {
			if($rep >= $minreps) {
				$didmatch = 1;
				last REP;
			} else {
				undef $didmatch;
				last REP;
			}
		} else {
			push @opmatches, $currval;
		}
	}

	if(not defined $didmatch) {
		if($rep >= $minreps) {
			$didmatch = 1;
		}
	}

	#warn "\t"x$tablevel . "_matches($litrule) returning " . (defined($didmatch) ? " with the following retval:".obj($retval) : "undef") ."\n";
	$tablevel--;

	if(not defined $didmatch) {
		$data = $prevdata;
		if(@my_playback and grep { scalar @$_ } @my_playback ) {
			#warn "\t"x($tablevel+1) . "_matches($litrule) doing playback\n";
			return $self->_matches($litrule || $rule, $tokname, \@my_playback, $outplay, 1, @matchrules);
		} else {
			return undef;
		}
	}

	#if($litrule eq $tokname) {
	#	$retval->{$tokname} = join("", @{$retval->{$tokname}}) if ref($retval->{$tokname}) eq "ARRAY" and not grep { ref($_) } @{$retval->{$tokname}};
	#}

	push @$outplay, \@opmatches if $self->op_is_fork($rule);
	return @matchrules ? $retval : 1;
}


# We use this as a bootstrap for grokking ABNF syntax.
use constant ABNF_PARSETREE => {
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
};

sub BEGIN {
	$ABNF = ABNF_PARSETREE;
	bless $ABNF, "Parse::ABNF";
}

1;
