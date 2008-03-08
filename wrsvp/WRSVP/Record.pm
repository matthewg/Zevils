package WRSVP::Record;

use strict;
use warnings;
use base 'Class::DBI';
use DBI;

my %dbh;
my $current_dbh;

sub init {
  my($dsn, $user, $pass) = @_;
  if($dbh{$dsn}) {
    $current_dbh = $dbh{$dsn};
  } else {
    $current_dbh = $dbh{$dsn} =
      DBI->connect_cached($dsn, $user, $pass,
                          {
                           WRSVP::Record->_default_attributes
                          });
    if(not $current_dbh) {
      die "Couldn't connect to '$dsn': $DBI::errstr\n";
    }
  }
}

sub db_Main { $current_dbh; }

1;
