#!/usr/bin/perl

use strict;
use warnings;
use lib qw(.);
use AI::ExpertSystem::Simple;
use CGI qw/:standard/;
use CGI::Carp qw(fatalsToBrowser);

my $ai = AI::ExpertSystem::Simple->new();
$ai->load("udrp.xml") or die "Couldn't load UDRP data: $@\n";

my @udrpdb = ();
my @answers = ();
my @old_answers = ();
my $completed = 0;

print header, start_html('UDRP Wizard'), h1('UDRP Wizard');

if(param() and defined(param('answers'))) {
	@answers = split(/,/, param('answers'));
} else {
	print "<h2><a href=\"index.html\">About UDRP Wizard</a></h2>\n";
}

while(1) {
	print "<p>\n";
	foreach ($ai->log()) {
		if(/^Read in /) {}
		elsif(/^There are /) {}
		elsif(/^The goal /) {}
		elsif(/^Setting /) {}
		elsif(/^Rule '(.*)' (is now inactive|has completed)/) {
			my($rule, $state) = ($1, $2);

			if($state eq "has completed") {
				if($rule =~ /^udrp-db:(.*)/) {
					push @udrpdb, $1;
				} else {
					print "<em>We now know that $rule.</em><br />\n";
				}
			} elsif($rule !~ /^udrp-db:/) {
				print "<em>It is no longer possible that $rule.</em><br />\n";
			}
		} elsif(/^Rule /) {}
		else { print "<em>$_</em><br />\n"; }
	}
	print "</p>\n";

	my $state = $ai->process();
	if($state eq "question") {
		print "<hr />\n";
		my($question, @q_answers) = $ai->get_question();
		if(@answers) {
			print "<p>\n";
			my $answer = shift @answers;
			#print "<a href=\"".$ENV{SCRIPT_URI}."?answers=" . join(",", @old_answers) .
			#	"\">$question?</a> <u>$q_answers[$answer]</u>\n";
			print "$question? <u>$q_answers[$answer]</u>\n";
			$ai->answer($q_answers[$answer]);
			push @old_answers, $answer;
			print "</p>\n";
		} else {
			print "<a name=\"curr\" />\n";
			print "<p>\n";
			print "<b>$question?</b><br />\n";
			for(my $i = 0; $i < @q_answers; $i++) {
				print "<a href=\"".$ENV{SCRIPT_URI}."?answers=" . join(",", @old_answers, $i) .
					"#curr\">" . $q_answers[$i] . "</a><br />\n";
			}
			print "</p>\n";
			last;
		}
	} elsif($state eq "continue") {
		# no-op
	} elsif($state eq "finished") {
		print "<hr />\n";
		print "<a name=\"curr\" /><p>Result: <b>", $ai->get_answer(), ".</b></p>\n";
		$completed = 1;
		last;
	} elsif($state eq "failed") {
		print "<hr />\n";
		print "<a name=\"curr\" /><p>Result: <b>The domain cannot be transferred.</b></p>\n";
		$completed = 1;
		last;
	}
}


if($completed) {

	# Because of the inflexibility of AI::ExpertSystem::Simple (no boolean logic predicates),
	# we don't normally ever explicitly set rules to no.
	my $badfaith = $ai->{_knowledge}->{'bad-faith'};
	push @udrpdb, "NoBadFaith=True" if !defined($badfaith->{_value}) or $badfaith->{_value} eq "no";
	my $nolegit = $ai->{_knowledge}->{'no-legitimate-interest'};
	my $infringes = $ai->{_knowledge}->{'infringes-mark'};

	print "<p>";
	foreach (["the Respondent acted in bad faith in registering the domain", $badfaith], ["the Respondent has no legitimate interest in the domain", $nolegit], ["the domain infringes on the Complainant's mark", $infringes]) {
		print "It <b>";
		if(defined($_->[1]->{_value}) and $_->[1]->{_value} eq "yes") {
			print "CAN";
		} else {
			print "CAN NOT";
		}
		print "</b> be shown that ", $_->[0], ".<br />\n";
	}
	print "</p>\n";

	print "<p>For cases similar to yours, see <a href=\"http://udrp.lii.info/udrp-cgi/query.cgi?" .
		join("&", @udrpdb), "\">this link to the UDRP-DB</a>.\n</p>";

	#print "<p>", join("<br />\n", map { "$_: " . $ai->{_knowledge}->{$_}->{_value} } grep { $_ =~ /^legitimate-/ } sort keys %{$ai->{_knowledge}}) . "</p>\n";

	#use Data::Dumper;
	#print "<p><pre>", Data::Dumper::Dumper($ai->{_rules}->{'the Respondent is not making fair use of the domain'}), "</pre></p>\n";
}
