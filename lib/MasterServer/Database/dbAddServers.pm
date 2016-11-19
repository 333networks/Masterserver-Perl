
package MasterServer::Database::dbAddServers;

use strict;
use warnings;
use MasterServer::Core::Util 'sqlprint';
use Exporter 'import';

our @EXPORT = qw| add_server_new
                  add_server_list
               update_server_list 
                       syncer_add |;

################################################################################
## Update an existing address or add a new address to the pending list.
## opts: direct beacon, set update, game
################################################################################
sub add_server_new {
  my $self = shift;
  my %o = (
   updated  => time,
   @_);

  # try updating it in serverlist
  my %H = (
    $o{direct}   ? (  'b333ms = CAST(? AS BOOLEAN)' => $o{direct})      : (),
    $o{updated}  ? ( 'updated = to_timestamp(?)'    => $o{updated})     : (),
    $o{beacon}   ? (  'beacon = to_timestamp(?)'    => $o{beacon})      : (),
    $o{gamename} ? ('gamename = ?'                  => lc $o{gamename}) : (),
  );

  my($q, @p) = sqlprint("UPDATE serverlist !H 
    WHERE ip = ? AND port = ?", \%H, $o{ip}, $o{heartbeat});

  my $n = $self->{dbh}->do($q, undef, @p);
  
  # if serverlist was updated
  return 0 if ($n > 0);
  
  
  # try updating it in pending
  %H = (
    $o{added}      ? (     'added = ?' => $o{added})       : (),
    $o{secure}     ? (    'secure = ?' => $o{secure})      : (),
    $o{gamename}   ? (  'gamename = ?' => lc $o{gamename}) : (),
    $o{beaconport} ? ('beaconport = ?' => $o{beaconport})  : (),
  );

  ($q, @p) = sqlprint("UPDATE pending !H 
    WHERE ip = ? AND heartbeat = ?", \%H, $o{ip}, $o{heartbeat});

  # exec query
  $n = $self->{dbh}->do($q, undef, @p);

  # if beacon was updated
  return 1 if ($n > 0);
  
  # if not found at all, add to pending
  $n = $self->{dbh}->do(
     "INSERT INTO pending (
          ip, 
          beaconport, 
          heartbeat, 
          gamename, 
          secure) 
      SELECT ?, ?, ?, ?, ?",
      undef, $o{ip}, $o{beaconport}, $o{heartbeat}, lc $o{gamename}, $o{secure});
      
   # it was added to pending
   return 2 if ($n > 0);
}

################################################################################
## Update the server info in the serverlist
################################################################################
sub update_server_list {
  my $self = shift;
  my %o = (
    updated  => time,
    @_);

  # try updating it in serverlist
  my %H = (
    $o{gamename} ? ('gamename = ?' => lc $o{gamename}) : (),
    $o{gamever}  ? ( 'gamever = ?' => $o{gamever})     : (),
    $o{hostname} ? ('hostname = ?' => $o{hostname})    : (),
    $o{hostport} ? ('hostport = ?' => $o{hostport})    : (),
    $o{updated}  ? ( 'updated = to_timestamp(?)' => $o{updated})     : (),
  );

  my($q, @p) = sqlprint("UPDATE serverlist !H 
    WHERE ip = ? AND port = ?", \%H, $o{ip}, $o{port});

  return $self->{dbh}->do($q, undef, @p);
}

################################################################################
## beacon was verified or otherwise accepted and will now be added to the 
## serverlist.
################################################################################
sub add_server_list {
  my $self = shift;
  my %o = @_;

  # insert basic data
  return $self->{dbh}->do("INSERT INTO serverlist (ip, port, gamename, country) 
                           SELECT ?, ?, ?, ?", undef, 
                           $o{ip}, $o{port}, lc $o{gamename}, $self->ip2country($o{ip}));
}

################################################################################
## add new addresses to the pending list, but do not update timestamps. masters
## that sync with each other would otherwise update the timestamp for a server
## which is no longer online.
################################################################################
sub syncer_add {
  my ($self, $ip, $port, $gamename, $secure) = @_;

  # if address is in the list AND up to date, 
  # acknowledge its existance but don't do anything with it
  my $u = $self->{dbh}->do(
     "SELECT * FROM serverlist 
      WHERE ip = ? 
      AND port = ?
      AND updated > to_timestamp(?)",
      undef, $ip, $port, time-7200);

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
  $self->log("update","$ip:$port was updated by syncer") if ($u > 0);
  
  # return 1 if found
  return 1 if ($u > 0);
  
  # if not found or out of date, add it to pending to be checked again
  $u = $self->{dbh}->do(
     "INSERT INTO pending (ip, heartbeat, gamename, secure) 
      SELECT ?, ?, ?, ?",
      undef, $ip, $port, lc $gamename, $secure);
                            
   # notify
   $self->log("add","beacon: $ip:$port was added for $gamename after sync") if ($u > 0);
   
   # return 2 if added new
   return 2 if ($u > 0);
   
  # or else report error
  $self->log("error", "an error occurred adding $ip:$port after sync");
  return -1;
}

1;
