
package MasterServer::Database::mysql::dbServerlist;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw| add_to_serverlist 
                  update_serverlist
                  syncer_add
                  get_next_server |;

################################################################################
## beacon was verified or otherwise accepted and will now be added to the 
## serverlist.
################################################################################
sub add_to_serverlist {
  my ($self, $ip, $port, $gamename) = @_;
  
  # update or add server to serverlist
  my $u = $self->{dbh}->do("UPDATE serverlist 
                            SET updated  = NOW()
                            WHERE ip = ? 
                            AND port = ?",
                            undef, $ip, $port);

  # notify
  $self->log("update", "$ip:$port timestamp updated") if ($u > 0);
  
  # if found, updated; done
  return 0 if ($u > 0);
  
  # if not found, add it.
     $u = $self->{dbh}->do("INSERT INTO serverlist (ip, port, gamename, country) 
                            SELECT ?, ?, ?, ?",
                            undef, $ip, $port, $gamename, $self->ip2country($ip));

  # notify
  $self->log("add", "$ip:$port added to serverlist") if ($u > 0);
  
  # return added
  return 1 if ($u > 0);

  # or else report error
  $self->log("error", "an error occurred adding server $ip:$port ($gamename) to the serverlist");
  return -1;
}

################################################################################
## same as add_to_serverlist above, but does not add the server to serverlist
## if it does not exist in serverlist. it must be added by another function
## first.
################################################################################
sub update_serverlist {
  my ($self, $ip, $port, $s) = @_;
  
  # update server info
  my $u = $self->{dbh}->do(
           'UPDATE serverlist 
            SET updated  = NOW(),
              gamename = ?,
              gamever  = ?,
              hostname = ?,
              hostport = ?
            WHERE ip = ?
            AND port = ?', undef, 
          $s->{gamename}, $s->{gamever}, $s->{hostname}, $s->{hostport}, 
          $ip, $port);

  # notify
  $self->log("update", "server $ip:$port info updated") if ($u > 0);
  
  # return 0 if updated
  return 0 if ($u > 0);
   
  # or else report error
  $self->log("error", "an error occurred updating server $ip:$port in the serverlist");
  return -1;
}


################################################################################
## add new addresses to the pending list, but do not update timestamps. masters
## that sync with each other would otherwise update the timestamp for a server
## which is no longer online.
################################################################################
sub syncer_add {
  my ($self, $ip, $port, $gamename, $secure) = @_;

  # if address is in list, update the timestamp
  my $u = $self->{dbh}->do(
     "SELECT * FROM serverlist 
      WHERE ip = ? 
      AND port = ?",
      undef, $ip, $port);
 
  # notify
  $self->log("read","syncer found entry for $ip:$port") if ($u > 0);
  
  # if found, return 0
  return 0 if ($u > 0);

  # if it is already in the pending list, update it with a new challenge
  $u = $self->{dbh}->do(
     "UPDATE pending 
      SET secure = ?
      WHERE ip = ? 
      AND heartbeat = ?",
      undef, $secure, $ip, $port);  

  # notify
  $self->log("update","$ip:$port was updated by syncer",
          $self->{log_settings}->{db_updated}) if ($u > 0);
  
  # return 1 if found
  return 1 if ($u > 0);
  
  # if not found, add it
  $u = $self->{dbh}->do(
     "INSERT INTO pending (ip, heartbeat, gamename, secure) 
      SELECT ?, ?, ?, ?",
      undef, $ip, $port, $gamename, $secure);
                            
   # notify
   $self->log("add","beacon: $ip:$port was added for $gamename after sync") if ($u > 0);
   
   # return 2 if added new
   return 2 if ($u > 0);
   
  # or else report error
  $self->log("error", "an error occurred adding $ip:$port after sync");
  return -1;
}

################################################################################
## get a server address of the next server in line to be queried for game info. 
## query must be older than 30 seconds (in case it just got added) and not 
## older than 3 hours. FIXME: now older servers are ignored!
################################################################################
sub get_next_server {
  my ($self, $id) = @_;
  
  return $self->{dbh}->selectall_arrayref(
     "SELECT id, ip, port FROM serverlist
      WHERE added < NOW() - INTERVAL 15 SECOND
      AND updated > NOW() - INTERVAL 10800 SECOND
      AND id > ?
      AND NOT blacklisted
      ORDER BY id ASC LIMIT 1", undef, $id)->[0];
      
}

1;
