package WRSVP::Group;

use strict;
use warnings;
use base 'WRSVP::Record';

WRSVP::Group->table('groups');
WRSVP::Group->columns(All => qw/group_id street_name/);
WRSVP::Group->has_many(people => 'WRSVP::Person');

#sub people {
#  my($self) = @_;
#  WRSVP::Person->search(group_id => $self->group_id);
#}

1;
