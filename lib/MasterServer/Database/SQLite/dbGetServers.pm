package MasterServer::Database::SQLite::dbGetServers;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw| get_server 
                  get_pending |;

################################################################################
## get server details for one or multiple servers
## opts: limit, see $order
################################################################################
sub get_server {
  my $s = shift;
  my %o = (
    sort => '', 
    @_
  );
  
  my %where = (
    $o{next_id}     ? (         'id > ?' => $o{next_id})      : (),
    $o{id}          ? (         'id = ?' => $o{id})           : (),
    $o{ip}          ? (         'ip = ?' => $o{ip})           : (),
    $o{port}        ? (       'port = ?' => $o{port})         : (),
    $o{gamename}    ? (   'gamename = ?' => lc $o{gamename})  : (),
    $o{gamever}     ? (    'gamever = ?' => $o{gamever})      : (),
    $o{hostname}    ? (   'hostname = ?' => $o{hostname})     : (),
    $o{hostport}    ? (   'hostport = ?' => $o{hostport})     : (),
    $o{country}     ? (    'country = ?' => $o{country})      : (),
    $o{b333ms}      ? (     'b333ms = ?' => $o{b333ms})       : (),
    $o{blacklisted} ? ('blacklisted = ?' => $o{blacklisted})  : (),
    $o{added}       ? (  'added < datetime(?, \'unixepoch\')' => (time-$o{added}))   : (),
    $o{beacon}      ? ( 'beacon > datetime(?, \'unixepoch\')' => (time-$o{beacon}))  : (),
    $o{updated}     ? ('updated > datetime(?, \'unixepoch\')' => (time-$o{updated})) : (),
    $o{before}      ? ('updated < datetime(?, \'unixepoch\')' => (time-$o{before}))  : (),
  );
  
  my @select = ( qw|
    id 
    ip 
    port 
    gamename 
    gamever 
    hostname 
    hostport 
    country 
    b333ms 
    blacklisted 
    added 
    beacon 
    updated
  |);

  my $order = sprintf {
      id          => 'id %s',
      ip          => 'ip %s',
      port        => 'port %s',
      gamename    => 'gamename %s',
      gamever     => 'gamever %s',
      hostname    => 'hostname %s',
      hostport    => 'hostport %s',
      country     => 'country %s',
      b333ms      => 'b333ms %s',
      blacklisted => 'blacklisted %s',
      added       => 'added %s',
      beacon      => 'beacon %s',
      updated     => 'updated %s',
  }->{ $o{sort}||'id' }, $o{reverse} ? 'DESC' : 'ASC';

  return $s->db_all( q|
    SELECT !s FROM serverlist
      !W
      ORDER BY !s|
      .($o{limit} ? " LIMIT ?" : ""),
    join(', ', @select), \%where, $order, ($o{limit} ? $o{limit} : ()),
  );
}

################################################################################
## get server details for one or multiple pending servers
## opts: limit, next_id, beaconport, heartbeat, gamename, secure, enctype, added
################################################################################
sub get_pending {
  my $s = shift;
  my %o = (
    sort => '', 
    @_
  );
  
  my %where = (
    $o{next_id}     ? (        'id > ?' => $o{next_id})     : (),
    $o{id}          ? (        'id = ?' => $o{id})          : (),
    $o{ip}          ? (        'ip = ?' => $o{ip})          : (),
    $o{beaconport}  ? ('beaconport = ?' => $o{beaconport})  : (),
    $o{heartbeat}   ? ( 'heartbeat = ?' => $o{heartbeat})   : (),
    $o{gamename}    ? (  'gamename = ?' => lc $o{gamename}) : (),
    $o{secure}      ? (    'secure = ?' => $o{secure})      : (),
    $o{enctype}     ? (   'enctype = ?' => $o{enctype})     : (),
    $o{added} ? ('added < datetime(?, \'unixepoch\')' => (time-$o{added})) : (),
    $o{after} ? ('added > datetime(?, \'unixepoch\')' => (time-$o{after})) : (),
  );
  
  my @select = ( qw| id ip beaconport heartbeat gamename secure enctype added |,);
  my $order = sprintf {
      id          => 'id %s',
      ip          => 'ip %s',
      beaconport  => 'beaconport %s',
      heartbeat   => 'heartbeat %s',
      gamename    => 'gamename %s',
      secure      => 'secure %s',
      enctype     => 'enctype %s',
      added       => 'added %s',
  }->{ $o{sort}||'id' }, $o{reverse} ? 'DESC' : 'ASC';

  return $s->db_all( q|
    SELECT !s FROM pending
      !W
      ORDER BY !s|
      .($o{limit} ? " LIMIT ?" : ""),
    join(', ', @select), \%where, $order, ($o{limit} ? $o{limit} : ()),
  );
}

1;
