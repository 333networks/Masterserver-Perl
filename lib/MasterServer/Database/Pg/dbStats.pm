package MasterServer::Database::Pg::dbStats;

use strict;
use warnings;
use Exporter 'import';
our @EXPORT = qw| get_gamenames
                  get_gamestats
                  get_listedstats
                  write_stat 
                  write_direct_beacons
                  write_kfstats |;

################################################################################
## get a list of distinct gamenames currently in the server list
################################################################################
sub get_gamenames {
  my $self = shift;
  return $self->{dbh}->selectall_arrayref(
     "SELECT distinct gamename 
      FROM serverlist");
}

################################################################################
## get statistics (num_direct, num_total) per gamename
################################################################################
sub get_gamestats {
  my ($self, $gn) = @_;
  return $self->db_all(
     "SELECT COUNT(CASE WHEN b333ms THEN 1 END) as num_uplink, count(*) as num_total
      FROM serverlist
      WHERE gamename = ? AND updated > to_timestamp(?)",
      lc $gn, time-7200);
}

################################################################################
## get a list of distinct gamenames currently in the database. it does not 
## matter whether they are recent or old, as long as the game is currently in
## the database.
################################################################################
sub get_listedstats {
  my $self = shift;
  return $self->{dbh}->selectall_arrayref(
     "SELECT gamename 
      FROM games
      WHERE num_uplink > 0
         OR num_total  > 0");
}

################################################################################
# Write the stats to the games table
# A stat can not exist without existing gamename. Was inserted by cipher loader.
################################################################################
sub write_stat {
  my ($self, %o) = @_;
  return $self->{dbh}->do(
     "UPDATE games 
      SET num_uplink = ?,
          num_total  = ?
      WHERE gamename = ?",
      undef, $o{num_uplink}, $o{num_total}, lc $o{gamename});
}

################################################################################
# Determine from the last beacon whether the server is still uplinking
# directly to us, or whether it stopped uplinking and is now artificially
# kept in the database.
################################################################################
sub write_direct_beacons {
  my $self = shift;
  my $u = $self->{dbh}->do(
    "UPDATE serverlist 
     SET b333ms = CAST(0 AS BOOLEAN)
     WHERE beacon < to_timestamp(?) AND b333ms", 
     undef, time-3600);
  $self->log("unset", "Lost $u direct beacons.") if ($u > 0);
}

################################################################################
## Write the KFStats to the database
################################################################################
sub write_kfstats {
  my ($self, $h) = @_;

  # check if entry already exists.
  my $u = $self->{dbh}->selectall_arrayref(
    "SELECT * FROM kfstats WHERE UTkey = ? ", undef, $h->{UTkey});
  
  if ( !defined $u->[0] ) {
    $u = $self->{dbh}->do(
      "INSERT INTO kfstats (UTkey, Username) VALUES (?,?)", 
      undef, $h->{UTkey}, $h->{Username});
    $self->log("kfnew", "New KF Player $h->{Username} added");
  }

  # update existing information
  $self->{dbh}->do("UPDATE kfstats SET 
      Username = ?, 
      CurrentVeterancy = ?, 
      TotalKills = ?, 
      DecaptedKills = ?, 
      TotalMeleeDamage = ?, 
      MeleeKills = ?, 
      PowerWpnKills = ?, 
      BullpupDamage = ?, 
      StalkerKills = ?, 
      TotalWelded = ?, 
      TotalHealed = ?, 
      TotalPlaytime =?, 
      GamesWon = ?, 
      GamesLost = ?
   WHERE UTkey = ?", undef,
      $h->{Username}, 
      $h->{CurrentVeterancy}, 
      $h->{TotalKills},
      $h->{DecaptedKills}, 
      $h->{TotalMeleeDamage}, 
      $h->{MeleeKills}, 
      $h->{PowerWpnKills}, 
      $h->{BullpupDamage}, 
      $h->{StalkerKills}, 
      $h->{TotalWelded}, 
      $h->{TotalHealed}, 
      $h->{TotalPlaytime}, 
      $h->{GamesWon}, 
      $h->{GamesLost}, 
      $h->{UTkey}
  );
}

1;
