package WRSVP::Person;

use strict;
use warnings;
use base 'WRSVP::Record';

WRSVP::Person->table('people');
my $group_col = Class::DBI::Column->new(group_id => {
                                                     accessor => 'group',
                                                    });
WRSVP::Person->columns(All => qw/person_id name attending meal/, $group_col);
WRSVP::Person->has_a(meal => 'WRSVP::Meal');
WRSVP::Person->has_a(group_id => 'WRSVP::Group');

1;
