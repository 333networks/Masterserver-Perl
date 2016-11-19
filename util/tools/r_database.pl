#!/usr/bin/perl
use strict;
use warnings;
use DBI;

our $dbh = open_database();

sub open_database {
  my $dbh = DBI->connect('dbi:Pg:dbname=masterserver', 'user', 'password')
    or die "Cannot connect: $DBI::errstr\n";
  
  # don't forget at end!
  #$dbh->disconnect;
}

################################################################################
## Subroutine dbAddServer
## Add a server to the database (address + port only)
## If the address already exists in the database, it will be ignored.
################################################################################
sub db_add_server {
  my %o = (@_);

  # Try to get the address out of the database.
  my $exists = $dbh->selectall_arrayref(
    "SELECT * FROM serverlist WHERE ip = ? AND port = ?", 
    undef, $o{ip}, $o{port});
  return if (defined $exists->[0]);
  
  $exists = $dbh->selectall_arrayref(
    "SELECT * FROM pending WHERE ip = ? AND heartbeat = ?", 
    undef, $o{ip}, $o{port});
  return if (defined $exists->[0]);
  
  #print "Add $o{ip}\t $o{port}\n";
  $exists = $dbh->do("INSERT INTO pending (ip, heartbeat) VALUES(?, ?)",
     undef, $o{ip}, $o{port});
}

1;
