
package MasterServer::Database::Pg::dbServerlist;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw| add_to_serverlist |;

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
  $self->log("updated", "$ip:$port timestamp updated") if ($u > 0);
  
  # if found, updated; done
  return 0 if ($u > 0);
  
  # if not found, add it.
     $u = $self->{dbh}->do("INSERT INTO serverlist (ip, port, gamename, country) 
                            SELECT ?, ?, ?, ?",
                            undef, $ip, $port, $gamename, $self->ip2country($ip));

  # notify
  $self->log("added", "$ip:$port added to serverlist") if ($u > 0);
  
  # return added
  return 1 if ($u > 0);

  # or else report error
  $self->log("error", "an error occurred adding server $ip:$port ($gamename) to the serverlist");
  return -1;
}

1;
