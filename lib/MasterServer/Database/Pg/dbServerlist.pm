
package MasterServer::Database::Pg::dbServerlist;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw| add_to_serverlist 
                  update_serverlist
                  get_next_server |;

## beacon was verified or otherwise accepted and will noe now be added to the 
## serverlist.
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
##
##   Subroutine update_serverlist
##
## Same as add_to_serverlist (above), but does not add the server to serverlist
## if it does not exist in serverlist.
##
## Args: ip, port %info
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
  $self->log("update", "server $ip:$port was updated: $s->{hostname}") if ($u > 0);
  
  # return 0 if updated
  return 0 if ($u > 0);
   
  # or else report error
  $self->log("error", "an error occurred updating server $ip:$port in the serverlist");
  return -1;
}

################################################################################
##
##   Subroutine get_next_server
##
##  Get a server address of the next server in line to be 
##  queried for game info. Query must be older than 30 seconds (in case it just
##  got added) and not older than 3 hours.
##
##  Args: $id --> id of a server address entry
##  Returns: hash {id, ip, port} of the NEXT entry in line.
################################################################################
sub get_next_server {
  my ($self, $id) = @_;
  
  return $self->{dbh}->selectall_arrayref(
     "SELECT id, ip, port FROM serverlist
      WHERE added < (NOW() - INTERVAL '15 SECONDS')
      AND updated > (NOW() - INTERVAL '3 HOUR')
      AND id > ?
      AND NOT blacklisted
      ORDER BY id ASC LIMIT 1", undef, $id)->[0];
}

1;
