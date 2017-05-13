#!/usr/bin/perl
use strict;
use warnings;
use DBI;

our $dbh = open_database();

sub open_database {
  my $dbh = DBI->connect('dbi:Pg:dbname=database', 'user', 'password')
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
  my %o = @_;

  # Try to get the address out of the database.
  my $exists = $dbh->selectall_arrayref(
    "SELECT * FROM serverlist WHERE ip = ? AND port = ?", 
    undef, $o{ip}, $o{port});
  return if (defined $exists->[0]);
  
  $exists = $dbh->selectall_arrayref(
    "SELECT * FROM pending WHERE ip = ? AND heartbeat = ?", 
    undef, $o{ip}, $o{port});
  return if (defined $exists->[0]);
  
  # generate random "secure" string
  my @c = ('A'..'Z');
  my $s = "";
  $s .= $c[rand @c] for 1..6;
  
  #print "Add $o{ip}\t $o{port}\n";
  $exists = $dbh->do("INSERT INTO pending (ip, heartbeat, secure) VALUES(?, ?, ?)",
     undef, $o{ip}, $o{port}, $s);
}

################################################################################
## Add a remote master server applet 
################################################################################
sub add_master_applet {
  my %o = @_;

  my $u = $dbh->do(
     "SELECT * FROM appletlist 
      WHERE ip = ? 
      AND port = ?
      AND gamename = ?",
      undef, $o{ip}, $o{port}, lc $o{gamename});
  
  # return if found
  return if ($u > 0);

  # insert applet data 
  return $dbh->do("INSERT INTO appletlist (ip, port, gamename) 
                           SELECT ?, ?, ?", undef, 
                           $o{ip}, $o{port}, lc $o{gamename});
}

################################################################################
## update time on master applet
################################################################################
sub update_master_applet {
  my %o = @_;
  return $dbh->do("UPDATE appletlist 
    SET updated = to_timestamp(?) 
    WHERE ip = ?
      AND port = ?
      AND gamename = ?", 
    undef, time, $o{ip}, $o{port}, lc $o{gamename});
}

1;
