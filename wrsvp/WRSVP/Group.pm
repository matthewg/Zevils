package WRSVP::Group;

use strict;
use warnings;
use base 'WRSVP::Record';

WRSVP::Group->table('groups');
WRSVP::Group->columns(All => qw/group_id login password address/);
WRSVP::Group->has_many(people => 'WRSVP::Person');

1;
