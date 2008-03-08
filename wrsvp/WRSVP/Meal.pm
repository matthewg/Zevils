package WRSVP::Meal;

use strict;
use warnings;
use base 'WRSVP::Record';

WRSVP::Meal->table('meals');
WRSVP::Meal->columns(All => qw/meal_id name/);

1;
