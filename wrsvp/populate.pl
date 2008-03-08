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

my $sachs = WRSVP::Group->insert({login => "foo",
                                  password => "",
                                  address => <<EOF});
The Sachs Family
123 Fake St.
Testville, AK 12345
EOF

my $gifford = WRSVP::Group->insert({login => "bar",
                                    password => "",
                                    address => <<EOF});
The Gifford Family
456 Nonexistant Ln.
Test City, TN 67890
EOF


WRSVP::Person->insert({name => "Ma Sachs",
                       attending => 0,
                       group => $sachs
                       });
WRSVP::Person->insert({name => "Ma Gifford",
                       attending => 0,
                       group => $gifford
                       });
