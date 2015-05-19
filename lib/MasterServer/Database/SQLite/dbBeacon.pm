
package MasterServer::Database::SQLite::dbBeacon;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw| add_beacon
                  add_pending
                  remove_pending 
                  get_pending_beacon 
                  get_pending_info
                  get_next_pending |;

################################################################################
## Update beacon in serverlist or pending list. Add if beacon does not exist in
## either list. Return 0,1,2 if success in adding or -1 on error.
################################################################################
sub add_beacon {
  my ($self, $ip, $beaconport, $heartbeat, $gamename, $secure) = @_;

  # if address is in list, update the timestamp
  my $u = $self->{dbh}->do(
     "UPDATE serverlist 
      SET beacon   = CURRENT_TIMESTAMP,
          updated  = CURRENT_TIMESTAMP,
          gamename = ?,
          b333ms   = 1
      WHERE ip = ? 
      AND port = ?",
      undef, lc $gamename, $ip, $heartbeat);
  
  # notify
  $self->log("update", "beacon heartbeat for $ip:$heartbeat") if ($u > 0);
  
  # if serverlist was updated return 0
  return 0 if ($u > 0);

  # if it is already in the pending list, update it with a new challenge
  $u = $self->{dbh}->do(
     "UPDATE pending 
      SET added       = CURRENT_TIMESTAMP,
          beaconport  = ?,
          gamename    = ?,
          secure      = ?
      WHERE ip = ? 
      AND heartbeat = ?",
      undef, $beaconport, lc $gamename, $secure, $ip, $heartbeat);  
                            
  # notify
  $self->log("update", "beacon heartbeat $ip:$beaconport pending $gamename:$heartbeat") if ($u > 0);
  
  # beacon was already in pending list and was updated
  return 1 if ($u > 0);
  
  # if not found, add it
  $u = $self->{dbh}->do(
     "INSERT INTO pending (
          ip, 
          beaconport, 
          heartbeat, 
          gamename, 
          secure) 
      SELECT ?, ?, ?, ?, ?",
      undef, $ip, $beaconport, $heartbeat, lc $gamename, $secure);
                      
   # notify 
   $self->log("add", "beacon heartbeat $ip:$beaconport pending $gamename:$heartbeat") if ($u > 0);
   
   # it was added to pending
   return 2 if ($u > 0);
   
  # or else report error
  $self->log("error", "an error occurred adding beacon $ip:$beaconport with $gamename:$heartbeat to the pending list");
  return -1;
}

################################################################################
## Add an address to the database that was obtained via a method other than 
## an udp beacon. Return 0,1,2 if success in adding or -1 on error.
################################################################################
sub add_pending {
  my ($self, $ip, $port, $gamename, $secure) = @_;

  # if address is in list, update the timestamp
  my $u = $self->{dbh}->do(
     "UPDATE serverlist 
      SET updated = CURRENT_TIMESTAMP
      WHERE ip = ? 
      AND port = ?",
      undef, $ip, $port);

  # notify
  $self->log("update", "updated serverlist with $ip:$port") if ($u > 0);
  
  # if updated, return 0
  return 0 if ($u > 0);

  # if it is already in the pending list, update it with a new challenge
  $u = $self->{dbh}->do(
     "UPDATE pending 
      SET added  = CURRENT_TIMESTAMP,
          secure = ?
      WHERE ip = ? 
      AND heartbeat = ?",
      undef, $secure, $ip, $port);
      
  # notify
  $self->log("update", "updated pending with $ip:$port") if ($u > 0);
  
  # return 1 if updated
  return 1 if ($u > 0);
  
  # if not found, add it
  $u = $self->{dbh}->do(
     "INSERT INTO pending (
          ip, 
          heartbeat, 
          gamename, 
          secure) 
      SELECT ?, ?, ?, ?",
      undef, $ip, $port, $gamename, $secure);
      
   # notify
   $self->log("add", "$ip:$port added pending $gamename") if ($u > 0);
   
   # return 2 if added new
   return 2 if ($u > 0);
   
  # else
  return -1;
}

################################################################################
## Remove an entry from the pending list. Returns 0 if removed or -1 in case
## of error(s).
################################################################################
sub remove_pending {
  my ($self, $id) = @_;
  
  # if address is in list, update the timestamp
  my $u = $self->{dbh}->do(
     "DELETE FROM pending 
      WHERE id = ?", 
      undef, $id);
  
  # notify 
  $self->log("delete", "removed pending id $id from pending") if ($u > 0);
  
  # it was removed from pending
  return 2 if ($u > 0);
  
  # or else report error
  $self->log("error", "error deleting server $id from pending");
  return -1;
}

################################################################################
## Get pending server by ip, beacon port. Returns * or undef
################################################################################
sub get_pending_beacon {
  my ($self, $ip, $port) = @_;
  
  # if address is in list, update the timestamp
  return $self->{dbh}->selectall_arrayref(
     "SELECT * FROM pending
      WHERE ip = ?
      AND beaconport = ?",
      undef, $ip, $port)->[0];
}

################################################################################
## Get pending server by ip, heartbeat port. Returns * or undef
################################################################################
sub get_pending_info {
  my ($self, $ip, $port) = @_;
  
  # if address is in list, update the timestamp
  return $self->{dbh}->selectall_arrayref(
     "SELECT * FROM pending
      WHERE ip = ? 
      AND heartbeat = ?",
      undef, $ip, $port)->[0];
}

################################################################################
## Get server info from any entry with an id higher than the provided one. The
## server is added to pending at least 15 seconds ago. Returns info or undef.
################################################################################
sub get_next_pending {
  my ($self, $id) = @_;
  
  # get 1 pending id that is older than 15s
  return $self->{dbh}->selectall_arrayref(
     "SELECT id, ip, heartbeat, secure FROM pending
      WHERE added < datetime(CURRENT_TIMESTAMP, '-15 seconds')
      AND id > ?
      ORDER BY id ASC LIMIT 1", 
      undef, $id)->[0];
}


1;
