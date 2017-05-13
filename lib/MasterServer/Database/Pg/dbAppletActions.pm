package MasterServer::Database::Pg::dbAppletActions;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw|  add_master_applet 
                update_master_applet 
                 reset_master_applets 
             get_masterserver_applets 
          remove_unresponsive_applets |;

################################################################################
## Add a remote master server applet 
################################################################################
sub add_master_applet {
  my $self = shift;
  my %o = @_;

  my $u = $self->{dbh}->do(
     "SELECT * FROM appletlist 
      WHERE ip = ? 
      AND port = ?
      AND gamename = ?",
      undef, $o{ip}, $o{port}, lc $o{gamename});
  
  # return if found
  return if ($u > 0);

  # insert applet data 
  return $self->{dbh}->do("INSERT INTO appletlist (ip, port, gamename) 
                           SELECT ?, ?, ?", undef, 
                           $o{ip}, $o{port}, lc $o{gamename});
}

################################################################################
## reset added/updated time after restart
################################################################################
sub reset_master_applets {
  my $self = shift;
  return $self->{dbh}->do("UPDATE appletlist 
    SET   added = to_timestamp(?),
        updated = to_timestamp(?)",
    undef, time, time);
}

################################################################################
## update time on master applet
################################################################################
sub update_master_applet {
  my ($self, %o) = @_;

  return $self->{dbh}->do("UPDATE appletlist 
    SET updated = to_timestamp(?) 
    WHERE ip = ?
      AND port = ?
      AND gamename = ?", 
    undef, time, $o{ip}, $o{port}, lc $o{gamename});
}

################################################################################
## get a list of master server applets that were online in the past week
##
################################################################################
sub get_masterserver_applets {
  my $self = shift;

  return $self->db_all(
     "SELECT * 
      FROM appletlist
      WHERE updated > to_timestamp(?)",
      time-604800);
}

################################################################################
## Clear out applet entries that have been unresponsive or without servers for 
## more than a week. Servers with multiple entries only have the entry of this
## specific gamename removed.
################################################################################
sub remove_unresponsive_applets {
  my $self = shift;

  # remove entries
  my $u = $self->{dbh}->do(
     "DELETE FROM appletlist 
      WHERE updated < to_timestamp(?)", undef, time-604800);
  
  # notify 
  $self->log("delete", "Removed $u entries from applet list.") if ($u > 0);
}

1;
