# Parse::ABNF::OpTree
#
# Copyright (c) 2001 Matthew Sachs <matthewg@zevils.com>.  All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Parse::ABNF::OpTree;

=head1 NAME

Parse::ABNF::OpTree

=head1 SYNOPSIS

Please see the C<Parse::ABNF> documentation for general information about C<Parse::ABNF>
or the comments in the C<Parse::ABNF::OpTree> module for information specific to that
module.

=cut



$VERSION = '0.01';

use strict;
use warnings;
use vars qw($VERSION $tablevel);
use Symbol;
use Carp;
use Parse::ABNF::Common qw(:all);

$tablevel = -1;


############################################################
# Helper methods for add
# This is where a parse is turned into an op tree.

# Returns the number of vaules in an op
sub values($$) {
	my ($self, $op) = @_;

	return scalar(@{$op->{value}}) if $op->{value};
	return 0;
}

# Promote an op into an OP_TYPE_OPS, encapsulating existing values a sub-ops.
# This can even be used on ops that are alread OP_TYPE_OPS in cases like foo *bar.
#
# If called with parentreps, {min,max}reps will be kept by the parent instead of given to the child.
sub promote_op($$;$) {
	my ($self, $op, $parentreps) = @_;
	my $newval;

	if($self->values($op)) {
		$newval = {
			mode => $op->{mode},
			type => $op->{type},
			value => $op->{value}
		};
		$newval->{group} = delete $op->{group} if $op->{group};

		if(!$parentreps) {
			$newval->{minreps} = $op->{minreps} if exists($op->{minreps});
			$newval->{maxreps} = $op->{maxreps} if exists($op->{maxreps});

			delete $op->{minreps};
			delete $op->{maxreps};
		}
	}

	$op->{mode} = OP_MODE_AGGREGATOR;
	$op->{type} = OP_TYPE_OPS;
	$op->{value} = [];
	push @{$op->{value}}, $newval if $newval;
}

# Insert a value into an op.
sub insert_value($$$$) {
	my ($self, $op, $type, $value) = @_;
	my ($minreps, $maxreps, $ourrep);

	if($self->{nextrep}) {
		$self->{nextrep} =~ /(\d*)\*?(\d*)/;
		$minreps = $1 || 0;
		$maxreps = $2 || -1;
	}

	# We set nextalt when we encounter a /
	# At this point, it means that the previous token should be alternated with the current token.
	#
	if($self->{nextalt}) {
		delete $self->{nextalt};
		if($self->values($op) > 1 and $op->{mode} != OP_MODE_ALTERNATOR) {
			$self->promote_op($op);
			my $newval = {
				mode => OP_MODE_ALTERNATOR,
				type => $type,
				value => [pop @{$op->{value}}]
			};
			push @{$op->{value}}, $newval;
			return $self->insert_value($newval, $type, $value);
		} else {
			$op->{mode} = OP_MODE_ALTERNATOR;
		}
	}
	$op->{mode} ||= OP_MODE_AGGREGATOR;

	if($self->{nextrep}) {
		$ourrep = 1;
		delete $self->{nextrep};
		if($self->values($op) or $op->{group}) {
			$self->promote_op($op, 1) unless $op->{type} and $op->{type} == OP_TYPE_OPS;
			my $newval = {
				mode => OP_MODE_AGGREGATOR,
				type => $type,
				minreps => $minreps,
				maxreps => $maxreps
			};
			push @{$op->{value}}, $newval;
			return $self->insert_value($newval, $type, $value);
		} else {
			$op->{minreps} = $minreps;
			$op->{maxreps} = $maxreps;
		}
	}

	# "foo" bar, or something of the sorts - promote rule to an op and encapsulate the existing and new rules.
	# Or if rule is already an op, just encapsulate the new value.
	if(exists($op->{type}) and $op->{type} != $type) { 
		my $newval = {
			mode => $op->{mode},
			type => $type,
		};
		$self->promote_op($op) if $op->{type} != OP_TYPE_OPS;
		push @{$op->{value}}, $newval;
		return $self->insert_value($newval, $type, $value);
	}
	$op->{type} = $type;

	if($type == OP_TYPE_NUMVAL) {
		$value =~ /^\s*([bdx])([0-9A-Fa-f]+)([-.]?)([0-9A-Fa-f]*)\s*$/;
		my $numtype = $1;
		my $left = $2;
		my $conjunction = $3;
		my $right = $4;
		if($numtype eq "x") {
			$left = hex $left;
			$right = hex $right if $right;
		} elsif($numtype eq "b") {
			$left = oct "0b$left";
			$right = oct "0b$right" if $right;
		}
		if($conjunction) {
			if($self->values($op) and $op->{mode} != OP_MODE_ALTERNATOR) {
				my $newval = {
					mode => OP_MODE_ALTERNATOR,
					type => $type
				};
				if($ourrep) {
					$newval->{minreps} = delete $op->{minreps};
					$newval->{maxreps} = delete $op->{maxreps};
				}
				$self->promote_op($op);
				push @{$op->{value}}, $newval;
				$op = $newval;
			} else {
				$op->{mode} = OP_MODE_ALTERNATOR;
			}
				
			if($conjunction eq "-") {
				push @{$op->{value}}, map {chr} ($left..$right);
			} elsif($conjunction eq ".") {
				push @{$op->{value}}, chr($left), chr($right);
			}
		} else {
			push @{$op->{value}}, chr($left);
		}
	} else {
		push @{$op->{value}}, $value;
	}
}

sub add_ruleparse($$$;$\@) {
	my ($self, $rule, $intoks, $parent, @saverules) = @_; # Do not use this method while intoksicated! ;)
	my @intoks = ref($intoks) eq "GLOB" ? @{*$intoks} : @$intoks;
	my $rulename = "";
	my ($intok, $type, $value);

	$rulename = ${*$intoks} if ref($intoks) eq "GLOB";
	#print tabify("$rulename\n") if $rulename;
	if($rulename eq "char-val") { #strip surrounding ""
		$intok =~ s/^\s*// if $intok;
		$intok =~ s/\s*$// if $intok;
		chop $intoks[0];
		substr($intoks[0], 0, 1, "");
	} elsif($rulename eq "prose-val") {
		croak "ABNF error: prose-vals (rule elements enclosed in <angle brackets>) are not supported: $intoks[0]";
	}

	foreach $intok(@intoks) {
		if(ref($intok) eq "GLOB") {
			#print tabify("Got GLOB.\n");
			$tablevel++;
			$self->add_ruleparse($rule, $intok, $rulename, @saverules);
			$tablevel--;
		} elsif(ref($intok) eq "ARRAY") {
			#print tabify("Got ARRAY.\n");
			$self->add_ruleparse($rule, $intok, $rulename, @saverules);
		} else {
			#print STDERR tabify("Got $parent/$rulename/$intok(".scalar(@saverules).").\n");
			if($rulename eq "group" or $rulename eq "option") {
				if($intok =~ /[\(\[]/) { # group/option start
					push @saverules, $rule;
					if($self->{nextalt}) {
						if($rule->{mode} and $rule->{mode} != OP_MODE_ALTERNATOR) { # foo / (bar baz)
							$type = $rule->{type};
							$self->promote_op($rule) unless $rule->{group};
							$value = pop @{$rule->{value}};
							my $newval = {
								mode => OP_MODE_ALTERNATOR
							};
							delete $self->{nextalt};
							$self->insert_value($newval, $type, $value);
							push @{$rule->{value}}, $newval;
							$rule = $newval;
						}
					} else {
						$self->promote_op($rule);
					}

					push @{$rule->{value}}, {};
					$rule = $rule->{value}->[-1];
					$rule->{group} = 1;

					if($self->{nextrep}) {
						croak "ABNF error: Repetition specified on option!" if $rulename eq "option"; # Just in case the user does something stupid like 1*[foo]

						$self->{nextrep} =~ /(\d*)\*?(\d*)/;
						$rule->{minreps} = $1 || 0;
						$rule->{maxreps} = $2 || -1;

						delete $self->{nextrep};
					} elsif($rulename eq "option") {
						$rule->{minreps} = 0;
						$rule->{maxreps} = 1;
					}
				} else { # group/option end
					$rule = pop @saverules;
				}
			} elsif($rulename eq "rulename" or $rulename =~ /(char|bin|dec|hex)-val/) {
				if($rulename eq "rulename") {
					$type = OP_TYPE_OPS;
				} elsif($rulename =~ /char-val/) {
					$type = OP_TYPE_CHARVAL;
				} else {
					$type = OP_TYPE_NUMVAL;
				}

				# Consider (*foo bar).  We need to make sure bar doesn't get foo's reps.
				# We do this by forcing foo into its own op.  scalar(@saverules) means we're
				# inside a group or option.
				#if(scalar(@saverules) and $self->{nextrep}) {
				#	$self->promote_op($rule);
				#	push @{$rule->{value}}, {};
				#	$self->insert_value($rule->{value}->[-1], $type, $intok);
				#} else {
					$self->insert_value($rule, $type, $intok);
				#}
			} elsif($rulename eq "repeat") {
				$intok =~ s/\s//g;
				$self->{nextrep} = $intok;
			} elsif($rulename eq "num-val") {
				#ignore the % (in something like %xFF)
			} elsif($intok =~ m!^\s*/\s*$! and $parent eq "alternation") {
				$self->{nextalt} = 1; # Next thingy should be alternated w/ previous thingy
			} else {
				# Ignore extraneous whitespace.  Otherwise, generate a cryptic error message.
				croak "ABNF unknown token in rule parse of $rulename: $intok" if $intok =~ /\S/;
			}
		}
	}
}


sub add($@) {
	my ($self, @rules) = @_;
	my $rule;


	# strip comments, whitespace / newline between rules
	$rule = join("\n", @rules);
	$rule =~ s/\r//g;

	# We want to strip comments.
	# However, we can't just take out everything after a ;
	# What about the rule semicolon = ";" ?
	# So we have to compensate for ; appearing within ""...
	@rules = split(/\n/, $rule);
	foreach $rule(@rules) {
		my $pos;
		$rule =~ s/^([^"]*?);.*/$1/;
		while($rule =~ /"[^"]*?"?/g) { $pos = pos($rule); } #WHY do I need to explicitly save/restore pos?
		pos($rule) = $pos;
		$rule =~ s/\G([^;]*);.*/$1/; # strip comments
	}
	$rule = join("\n", @rules);

	$rule =~ s/[\r\n]{1,2}[ \t]+/ /g; # join continued lines
	while($rule =~ /[\r\n]{2,}/) { $rule =~ s/[\r\n]{2,}/\n/; } # remove extraneous newlines
	$rule =~ s/[\r\n](?![^\r\n])//g; # remove trailing newlines
	$rule =~ s/^[\r\n]+//; # remove leading newlines
	$rule =~ s/[ \t]$//g; # remove trailing whitespace from lines
	$rule .= "\n"; # but we need a terminal newline

	my $parse = $Parse::ABNF::ABNF->matches("rulelist", $rule, qw(rule rulename defined-as elements element repeat group option alternation char-val num-val bin-val dec-val hex-val prose-val));
	my $inrule;

	foreach $inrule(@$parse) {
		my $rulename = ${*$inrule}[0]; #rulename is now the glob for rulename
		$rulename = ${*$rulename}[0]; #This gets the actual rule name.
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

1;
