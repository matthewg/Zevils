#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib $Bin;
use WRSVP::Record qw(dbi:mysql:wrsvp root);
use WRSVP::Meal;
use WRSVP::Group;
use WRSVP::Person;

WRSVP::Record::init("dbi:mysql:wrsvp", "root");

foreach my $group (WRSVP::Group->retrieve_all) {
  printf "%s/%s\n", $group->login, $group->password;
  print $group->address;

  foreach my $person (WRSVP::Person->search(group_id => $group->group_id)) {
    my $attending = $person->attending ? "is attending" : "is not attending";
    my $meal = $person->meal ? $person->meal->name : "something?";
    printf "\t%s %s and eating %s\n", $person->name, $attending, $meal;
  }
}
