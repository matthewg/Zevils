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

my $asparagus = WRSVP::Meal->insert({name => "Asparagus"});
my $cabbage = WRSVP::Meal->insert({name => "Cabbage"});

my $sachs = WRSVP::Group->insert({street_name => "Horatio"});
my $gifford = WRSVP::Group->insert({street_name => "Sotogrande"});
my $giff2 = WRSVP::Group->insert({street_name => "Sotogrande"});

WRSVP::Person->insert({name => "Ma Sachs",
                       attending => 0,
                       group => $sachs
                       });
WRSVP::Person->insert({name => "Pa Sachs",
                       attending => 0,
                       group => $sachs
                       });
WRSVP::Person->insert({name => "Ma Gifford",
                       attending => 0,
                       group => $gifford
                       });
WRSVP::Person->insert({name => "Pa Gifford",
                       attending => 0,
                       group => $gifford
                       });
WRSVP::Person->insert({name => "Isaac Gifford",
                       attending => 0,
                       group => $giff2
                       });
