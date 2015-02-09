
package MasterServer::Database::Pg::dbBeacon;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw| add_beacon get_pending_beacon remove_pending set_direct_beacon |;

## Update beacon in serverlist or pending list. Add if beacon does not exist in
## either list. Return 0,1,2 if success in adding or -1 on error
sub add_beacon {
  my ($self, $ip, $beaconport, $heartbeat, $gamename, $secure) = @_;

  # if address is in list, update the timestamp
  my $u = $self->{dbh}->do(
     "UPDATE serverlist 
      SET beacon   = NOW(),
          updated  = NOW(),
          gamename = ?,
          b333ms   = TRUE
      WHERE ip = ? 
      AND port = ?",
      undef, lc $gamename, $ip, $heartbeat);
  
  # notify
  $self->log("updated", "beacon heartbeat for $ip:$heartbeat") if ($u > 0);
  
  # if serverlist was updated return 0
  return 0 if ($u > 0);

  # if it is already in the pending list, update it with a new challenge
     $u = $self->{dbh}->do(
     "UPDATE pending 
      SET added       = NOW(),
          beaconport  = ?,
          gamename    = ?,
          secure      = ?
      WHERE ip = ? 
      AND heartbeat = ?",
      undef, $beaconport, lc $gamename, $secure, $ip, $heartbeat);  
                            
  # notify
  $self->log("updated", "beacon heartbeat $ip:$beaconport pending $gamename:$heartbeat") if ($u > 0);
  
  # beacon was already in pending list and was updated
  return 1 if ($u > 0);
  
  # if not found, add it
     $u = $self->{dbh}->do(
     "INSERT INTO pending (ip, beaconport, heartbeat, gamename, secure) 
      SELECT ?, ?, ?, ?, ?",
      undef, $ip, $beaconport, $heartbeat, lc $gamename, $secure);
                      
   # notify 
   $self->log("added", "beacon heartbeat $ip:$beaconport pending $gamename:$heartbeat") if ($u > 0);
   
   # it was added to pending
   return 2 if ($u > 0);
   
  # or else report error
  $self->log("error", "an error occurred adding beacon $ip:$beaconport with $gamename:$heartbeat to the pending list");
  return -1;
}


##   Get pending server by ip, beacon port.
sub get_pending_beacon {
  my ($self, $ip, $port) = @_;
  
  # if address is in list, update the timestamp
  return $self->{dbh}->selectall_arrayref(
            "SELECT * FROM pending
             WHERE ip = ? 
             AND beaconport = ?",
            undef, $ip, $port)->[0];
}


##  server checks out, remove entry from the pending list.
sub remove_pending {
  my ($self, $id) = @_;
  
  # if address is in list, update the timestamp
  my $u = $self->{dbh}->do("DELETE FROM pending WHERE id = ?", undef, $id);
  
  # notify 
  $self->log("deleted", "removed pending id $id from the list of pending servers") if ($u > 0);
  
  # it was added to pending
  return 2 if ($u > 0);
  
  # or else report error
  $self->log("error", "an error occurred deleting server $id from the pending list");
  return -1;
}


## mark server as "direct beacon to this masterserver"
sub set_direct_beacon {
  my ($self, $ip, $port) = @_;
  
  # update or add server to serverlist
  my $u = $self->{dbh}->do("UPDATE serverlist 
                            SET b333ms   = TRUE
                            WHERE ip = ? 
                            AND port = ?",
                            undef, $ip, $port);

  # notify
  $self->log("updated", "$ip:$port is a direct beacon.") if ($u > 0);
  
  # if found, updated; done
  return 0 if ($u > 0);
  
  # or else report error
  $self->log("error", "an error occurred setting server $ip:$port as direct beacon");
  return -1;
}



1;
