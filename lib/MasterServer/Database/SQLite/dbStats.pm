package MasterServer::Database::SQLite::dbStats;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw| get_gamelist_stats 
                  write_direct_beacons
                  write_stat 
                  write_kfstats |;

################################################################################
# calculate stats for all individual games
################################################################################
sub get_gamelist_stats {
  my $self = shift;

  return $self->{dbh}->selectall_arrayref(
     "SELECT DISTINCT gamename AS gamename, 
            COUNT(NULLIF(b333ms AND updated > datetime(?, 'unixepoch'), 0)) AS numdirect,
            COUNT(NULLIF(updated > datetime(?, 'unixepoch'), 0)) AS numtotal
     FROM serverlist 
     GROUP BY gamename", undef, time-7200, time-7200);
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
     SET b333ms = 0
     WHERE beacon < datetime(?, 'unixepoch') AND b333ms", 
     undef, time-3600);
     
  # notify
  $self->log("unset", "Lost $u direct beacons.") if ($u > 0);
}

################################################################################
# Write the stats to the games table
# A stat can not exist without existing gamename. Was inserted by cipher loader.
################################################################################
sub write_stat {
  my ($self, %opt) = @_;

  # if it is already in the pending list, update it with a new challenge
  my $u = $self->{dbh}->do(
     "UPDATE games 
      SET num_uplink = ?,
          num_total  = ?
      WHERE gamename = ?",
      undef, $opt{num_uplink}, $opt{num_total}, lc $opt{gamename});
      
  # notify
  $self->log("update", "Updated stats for $opt{gamename}.") if ($u > 0);

}

################################################################################
## Write the KFStats to the database
################################################################################
sub write_kfstats {
  my ($self, $h) = @_;

  # check if entry already excists.
  my $u = $self->{dbh}->selectall_arrayref(
    "SELECT * FROM kfstats WHERE UTkey = ? ", undef, $h->{UTkey});
  
  if ( !defined $u->[0] ) {
    $u = $self->{dbh}->do(
      "INSERT INTO kfstats (UTkey, Username) VALUES (?,?)", 
      undef, $h->{UTkey}, $h->{Username});
                                   
    # notify
    $self->log("kfnew", "New KF Player $h->{Username} added");
  }

  # update existing information
  $u = $self->{dbh}->do("UPDATE kfstats SET 
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
