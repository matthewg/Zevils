# Parse::ABNF::ParseTree
#
# Copyright (c) 2001 Matthew Sachs <matthewg@zevils.com>.  All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Parse::ABNF::ParseTree;

=head1 NAME

Parse::ABNF::ParseTree

=head1 SYNOPSIS

Please see the C<Parse::ABNF> documentation for general information on C<Parse::ABNF>
or the comments in the C<Parse::ABNF::ParseTree> module for information specific to
that module.

=cut


$VERSION = '0.01';

use strict;
no strict qw(subs); #Problem with importing constants;
use warnings;
use vars qw($VERSION $tablevel);
use Symbol;
use Lingua::EN::Inflect qw(PL);
use Carp;
use Parse::ABNF::Common qw(:all);

$tablevel = -1;

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
# What's with the matches being this (not-so-)thin wrapper for this _matches thing?
# Well, _matches is recursive, right?  The child-matches needs to be able to
# modify the parent-matches $data.  So we do this by declaring it dynamically scoped.
# (Unfortunately, this appears to necessitate the use of no strict 'vars'.)  Tenga cuidado.
#
# But if we did that in the same scope as our matching routine, then when we recursed
# we'd do that declaration again and hide the $data that we're interested in.
# 
# Hence the wrapper.
#
# matches does other stuff too...

sub matches($$$;@) {
	my($self, $rule, $tmpdata, @matchrules) = @_;
	my $nomatchself = 1;
	my $ret;
	our $data;
	$data = $tmpdata;
	$tablevel = -1;

	if(@matchrules and $matchrules[0] eq "*") {
		@matchrules = grep { $_ ne "DEBUG" and not exists $self->{$_}->{core} } keys %$self;
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
	if($ret and @matchrules and $nomatchself and ref($ret)) {
		$ret = [@{*$ret}];
	}
	return $ret;
}

sub obj($) {
	my $obj = shift;
	no warnings; #Turn off spurious uninitialized variable warns.

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


sub matchednothing($) {
	my $didmatch = shift;

	return 1 if not $didmatch; # scalars
	return 1 if ref($didmatch) eq "ARRAY" and not @$didmatch; # lists
	return 1 if ref($didmatch) eq "GLOB" and not ${*$didmatch}; # globs
	return 0;
}

# This is the parsing engine.  It is not, perhaps, always the most elegant or beautiful code...
#
# 	"Through me is the way into the woeful city; through me is the
#	way into eternal woe; through me is the way among the lost
#	people. Justice moved my lofty maker: the divine Power, the
#	supreme Wisdom and the primal Love made me. Before me were no
#	things created, unless eternal, and I eternal last. Leave every
#	hope, ye who enter!"
#
#	These words of color obscure I saw written at the top of a gate;
#	whereat I, "Master, their meaning is dire to me."
#
#	And he to me, like one who knew, "Here it behoves to leave every
#	fear; it behoves that all cowardice should here be dead. We have
#	come to the place where I have told thee that thou shalt see the
#	woeful people, who have lost the good of the understanding."
#		--Dante at the gate of Hell.  Dante's Inferno, Canto III, Norton translation
#
sub _matches($$$;$$$@) {
	my($self, $rule, $tokname, $inplay, $outplay, $doplay, @matchrules) = @_;
	no strict qw(vars); # We need this because $data comes from matches which the compiler doesn't know yet.

	# *consults the Hip Owls book*  *steps up to podium clears throat*  "Ah, yes, now today we will be considering
	# the parsing engine of the Parse::ABNF module, the annotated source of which is in Appendix Q of your textbooks.
	# The engine can generally be classified as a Nondeterministic Finite Automaton, or NFA, at least according to the
	# practical definition given in Friedl - ah, or the 'Hip Owls book' as I've heard many of you refer to it - page 102;
	# namely, that the engine 'considers each subexpression or component in turn, and whenever it needs to decide between
	# two equally viable options, it selects one and remembers the other to return to later if need be.'  Moreover, it is
	# a greedy matcher.
	#
	# "The method in which this engine performs backtracking - that is, the returning to of a point where a decision beetween
	# two equally viable options was made in the event of the decision causing a failure later on in the matching - is
	# somewhat peculiar.  It is actually rather inefficient, and the only excuse for it is sheer laziness on the part of
	# Mr. Sachs - ah, that's the gentleman responsible for this particular parser.  Whenever an operand matches, the
	# engine checks if the operand could have matched in more than one way.  It does this by checking to see if the
	# minimum and maximum repetition counts differ or if the operand is of the alternator type.  If the operand was
	# a 'fork in the road' so to speak, the fashion in which the operand was matched is pushed onto a stack located
	# in the scope of the operand's parent.  Ah, there's a stack that's passed around by reference as a parameter to
	# the _matches method whenever it recurses.  Not a global stack, of course, but one local to the parent
	# invocation of the method.
	#
	# "When the method is about to fail, it checks to see if there are values on this stack.  If there are, the operand
	# matches all its values again.  However, when it reaches the final operand at which a decision was made in the prior
	# time around, it refuses to match the same way.  It skips directly to the next value that it could have matched,
	# which will either in the event of an alternator operand possibly cause a different value to match, or it will
	# match on a prior repetition.  Or, of course, it will still fail and then it might have to even further back.
	#
	# "By starting over from the beginning of the current branch - not, thankfully, the beginning of the entire match -
	# some much-needed simplicity is achieved at the cost of a small performance hit compared to rewinding only as far
	# as is absolutely necessary.  Ironically, the nature of the code required for this was still quite complex and
	# was the source of many bugs in early versions of the code.  These were of course eradicated in the Great Purge
	# of 2017..."

	my $foodata = $data;
	chomp $foodata;

	# Are we inside a literal rule (one that has a name) or one of its descendants (values an an OP_TYPE_OP operand) ?
	my $litrule = 0;
	if(!ref($rule)) {
		$litrule = $rule;

	}
	$tablevel++;

	# We convert @matchrules into a hash for our own convenience
	my ($matchrule, %matchrules);
	foreach $matchrule(@matchrules) {
		$matchrules{$matchrule} = 1;
	}

	# If tokname is set, it is the rule which is part of matchrules that we are inside.
	$tokname = "" unless exists $matchrules{$tokname};

	unless(ref($rule)) { # $rule may be a hashref to an op
		$rule = $self->{lc($rule)} or croak "Unknown ABNF rule: $litrule";
	}

	if($self->{DEBUG}) {
		if(not $rule->{core} or $self->{DEBUG} > 9) {
			print STDERR "\t"x$tablevel . "_matches($litrule) called with doplay=$doplay ";
			if($self->{DEBUG} == 2) {
				print STDERR "data=".substr($data, 0, index($data, "\n")), " ";
			} elsif($self->{DEBUG} > 2) {
				print STDERR "data=$data ";
			}
			print STDERR "inplay=", Data::Dumper->new([$inplay])->Terse(1)->Indent(0)->Dump, " " if $inplay;
			print STDERR "\n";
		}
	}


	my ($rep, $maxreps, $minreps, $mode, @matchvalues, $matchvalue, $didmatch, $retval, $prevdata, $repplay, $playback, @my_playback, @opmatches, $matchednothing);
	$rule->{type} ||= 0;
	if($rule->{type} == OP_TYPE_OPS and $tokname eq $litrule) {
		$retval = gensym;
	} elsif($rule->{type} == OP_TYPE_OPS) {
		$retval = [];
	} else {
		$retval = "";
	}

	# prevdata?  When we have an aggregator, we need to keep chopping away at data after
	# a match.  But maybe halfway through the aggregator, a match will fail which causes the whole aggregator
	# to fail.  And maybe we have another branch of an alternator that we can fall back on.  So data needs
	# to be restored to the state it was in before we started down the failed aggregator.

	# Ah, I should also explain playback.  

	$maxreps = exists($rule->{maxreps}) ? $rule->{maxreps} : 1;
	$minreps = exists($rule->{minreps}) ? $rule->{minreps} : 1;
	@matchvalues = @{$rule->{value}} if $rule->{value};
	$mode = exists($rule->{mode}) ? $rule->{mode} : OP_MODE_ALTERNATOR; #singleton is effectively the same as either one

	@my_playback = ();
	@opmatches = ();
	REP: for($rep = 0; $rep < $minreps or ($maxreps == -1 or $rep < $maxreps); $rep++) {
		$repplay = shift @$inplay if $inplay and not $doplay;
		undef $didmatch;
		$prevdata = $data;
		my $currval = 0;
		MATCHVALUE: foreach $matchvalue(@matchvalues) {

			$matchednothing = 0;

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
					confess "Invalid ABNF operand type: ".$rule->{type};
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

					# Here we take pains to collapse multiple anonymous scalar matches.
					# For instance, if we have a rule that matches *CHAR, we want to return the match as a single scalar and not as an array of separate one-character matches.
					# Unless, of course, CHAR is in @matchrules.

					if($litrule eq $tokname) {
						${*$retval} = $tokname;

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
						if((not ref($didmatch) or (ref($didmatch) eq "ARRAY" and not grep { ref($_) } @$didmatch)) and not grep { ref($_) } @$retval) {
							$retval->[0] = "" unless defined $retval->[0]; #Make sure the array exists before writing to [-1]
							if(ref($didmatch) eq "ARRAY") {
								$retval->[-1] .= join("", @$didmatch);
							} else {
								$retval->[-1] .= $didmatch;
							}
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

			# Fake failure if we match nothing - this stops infinite loops in cases like foo = *bar where bar can match "".
			if(matchednothing($didmatch)) {
				$matchednothing = 1;
				next MATCHVALUE;
			}

		} continue {
			$currval++;
		}

		print STDERR tabify("WOOT") if $matchednothing and $self->{DEBUG};

		if(not defined $didmatch or $matchednothing) {
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

	if($self->{DEBUG}) {
		if(not $rule->{core} or $self->{DEBUG} > 9) {
			print STDERR "\t"x$tablevel . "_matches($litrule) returning " . (defined($didmatch) ? " with the following retval:".obj($retval) : "undef") ."\n";
		}
	}
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

	push @$outplay, \@opmatches if $self->op_is_fork($rule);
	return @matchrules ? $retval : 1;
}

1;
