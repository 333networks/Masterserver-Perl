package MasterServer::Database::Pg::dbUTServerInfo;

use strict;
use warnings;
use MasterServer::Core::Util 'sqlprint';
use Exporter 'import';

our @EXPORT = qw| get_utserver
                  add_utserver
               update_utserver 
               delete_utplayers
               insert_utplayer |;

################################################################################
## get server details for one or multiple UT servers
## opts: limit, see $order
################################################################################
sub get_utserver {
  my $s = shift;
  my %o = (
    sort => '', 
    @_
  );
  
  my %where = (
    $o{id}                  ? ('server_id = ?'            => $o{id})                  : (),
    $o{minnetver}           ? ('minnetver = ?'            => $o{minnetver})           : (),
    $o{gamever}             ? ('gamever = ?'              => $o{gamever})             : (),
    $o{location}            ? ('location = ?'             => $o{location})            : (),
    $o{listenserver}        ? ('listenserver = ?'         => $o{listenserver})        : (),
    $o{hostport}            ? ('hostport = ?'             => $o{hostport})            : (),
    $o{hostname}            ? ('hostname = ?'             => $o{hostname})            : (),
    $o{adminname}           ? ('adminname = ?'            => $o{adminname})           : (),
    $o{adminemail}          ? ('adminemail = ?'           => $o{adminemail})          : (),
    $o{password}            ? ('password = ?'             => $o{password})            : (),
    $o{gametype}            ? ('gametype = ?'             => $o{gametype})            : (),
    $o{gamestyle}           ? ('gamestyle = ?'            => $o{gamestyle})           : (),
    $o{changelevels}        ? ('changelevels = ?'         => $o{changelevels})        : (),
    $o{maptitle}            ? ('maptitle = ?'             => $o{maptitle})            : (),
    $o{mapname}             ? ('mapname = ?'              => $o{mapname})             : (),
    $o{numplayers}          ? ('numplayers = ?'           => $o{numplayers})          : (),
    $o{maxplayers}          ? ('maxplayers = ?'           => $o{maxplayers})          : (),
    $o{minplayers}          ? ('minplayers = ?'           => $o{minplayers})          : (),
    $o{botskill}            ? ('botskill = ?'             => $o{botskill})            : (),
    $o{balanceteams}        ? ('balanceteams = ?'         => $o{balanceteams})        : (),
    $o{playersbalanceteams} ? ('playersbalanceteams = ?'  => $o{playersbalanceteams}) : (),
    $o{friendlyfire}        ? ('friendlyfire = ?'         => $o{friendlyfire})        : (),
    $o{maxteams}            ? ('maxteams = ?'             => $o{maxteams})            : (),
    $o{timelimit}           ? ('timelimit = ?'            => $o{timelimit})           : (),
    $o{goalteamscore}       ? ('goalteamscore = ?'        => $o{goalteamscore})       : (),
    $o{fraglimit}           ? ('fraglimit = ?'            => $o{fraglimit})           : (),
    $o{mutators}            ? ('hostname ILIKE ?'         => "%$o{mutators}%")        : (),
    $o{updated}             ? ('updated > to_timestamp(?)'=> (time-$o{updated}))      : (),
  );
  
  my @select = ( qw|
    server_id
    minnetver
    gamever
    location
    listenserver
    hostport
    hostname
    adminname
    adminemail
    password
    gametype
    gamestyle
    changelevels
    maptitle
    mapname
    numplayers
    maxplayers
    minplayers
    botskill
    balanceteams
    playersbalanceteams
    friendlyfire
    maxteams
    timelimit
    goalteamscore
    fraglimit
    mutators
    updated
  |);

  my $order = sprintf {
    server_id     => 'server_id %s',
    minnetver     => 'minnetver %s',
    gamever       => 'gamever %s',
    location      => 'location %s',
    listenserver  => 'listenserver %s',
    hostport      => 'hostport %s',
    hostname      => 'hostname %s',
    adminname     => 'adminname %s',
    adminemail    => 'adminemail %s',
    password      => 'password %s',
    gametype      => 'gametype %s',
    gamestyle     => 'gamestyle %s',
    changelevels  => 'changelevels %s',
    maptitle      => 'maptitle %s',
    mapname       => 'mapname %s',
    numplayers    => 'numplayers %s',
    maxplayers    => 'maxplayers %s',
    minplayers    => 'minplayers %s',
    botskill      => 'botskill %s',
    balanceteams  => 'balanceteams %s',
    playersbalanceteams => 'playersbalanceteams %s',
    friendlyfire  => 'friendlyfire %s',
    maxteams      => 'maxteams %s',
    timelimit     => 'timelimit %s',
    goalteamscore => 'goalteamscore %s',
    fraglimit     => 'fraglimit %s',
    mutators      => 'mutators %s',
    updated       => 'updated %s',
  }->{ $o{sort}||'server_id' }, $o{reverse} ? 'DESC' : 'ASC';

  return $s->db_all( q|
    SELECT !s FROM utserver_info
      !W
      ORDER BY !s|
      .($o{limit} ? " LIMIT ?" : ""),
    join(', ', @select), \%where, $order, ($o{limit} ? $o{limit} : ()),
  );
}


################################################################################
## Update serverinfo for an existing address to the utserver list.
## opts: all server info data fields.
################################################################################
sub update_utserver {
  my $self = shift;
  my $id   = shift;
  my %s = (
   # defaults
   updated    => time,
   @_);

  # try updating it in serverlist
  my %H = (
    $s{minnetver}           ? (            'minnetver = ?' =>      $s{minnetver} )                    : (),
    $s{gamever}             ? (              'gamever = ?' => int( $s{gamever}) )                     : (),
    $s{location}            ? (             'location = ?' =>      $s{location} )                     : (),
    $s{listenserver}        ? (         'listenserver = ?' =>    ( $s{listenserver} ? 1 : 0) )        : (),
    $s{hostport}            ? (             'hostport = ?' =>      $s{hostport})                      : (),
    $s{hostname}            ? (             'hostname = ?' =>      $s{hostname})                      : (),
    $s{AdminName}           ? (            'adminname = ?' =>      $s{AdminName})                     : (),
    $s{AdminEMail}          ? (           'adminemail = ?' =>      $s{AdminEMail})                    : (),
    $s{password}            ? (             'password = ?' =>    ( $s{password} ? 1 : 0) )            : (),
    $s{gametype}            ? (             'gametype = ?' =>      $s{gametype})                      : (),
    $s{gamestyle}           ? (            'gamestyle = ?' =>      $s{gamestyle})                     : (),
    $s{changelevels}        ? (         'changelevels = ?' =>    ( $s{changelevels} ? 1 : 0) )        : (),
    $s{maptitle}            ? (             'maptitle = ?' =>      $s{maptitle})                      : (),
    $s{mapname}             ? (              'mapname = ?' =>      $s{mapname})                       : (),
    $s{numplayers}          ? (           'numplayers = ?' =>      $s{numplayers})                    : ('numplayers = ?' => 0),
    $s{maxplayers}          ? (           'maxplayers = ?' =>      $s{maxplayers})                    : ('maxplayers = ?' => 0),
    $s{minplayers}          ? (           'minplayers = ?' =>      $s{minplayers})                    : ('minplayers = ?' => 0),
    $s{botskill}            ? (             'botskill = ?' =>      $s{botskill})                      : (),
    $s{balanceteams}        ? (         'balanceteams = ?' =>    ( $s{balanceteams} ? 1 : 0) )        : (),
    $s{playersbalanceteams} ? (  'playersbalanceteams = ?' =>    ( $s{playersbalanceteams} ? 1 : 0) ) : (),
    $s{friendlyfire}        ? (         'friendlyfire = ?' =>      $s{friendlyfire})                  : (),
    $s{maxteams}            ? (             'maxteams = ?' =>      $s{maxteams})                      : (),
    $s{timelimit}           ? (            'timelimit = ?' =>      $s{timelimit})                     : (),
    $s{goalteamscore}       ? (        'goalteamscore = ?' => int( $s{goalteamscore}) )               : (),
    $s{fraglimit}           ? (            'fraglimit = ?' => int( $s{fraglimit}) )                   : (),
    $s{mutators}            ? (             'mutators = ?' =>      $s{mutators})                      : ('mutators = ?' => "None"),
    $s{updated}             ? ('updated = to_timestamp(?)' =>      $s{updated})                       : (),
  );
  
  my($q, @p) = sqlprint("UPDATE utserver_info !H WHERE server_id = ?", \%H, $id);
  return $self->{dbh}->do($q, undef, @p);
}


################################################################################
## Add a new utserver and trigger the update routine above.
## opts: id, server info data
################################################################################
sub add_utserver {
  my ($self, $ip, $port) = @_;

  # create new entry
  return $self->{dbh}->do(
    "INSERT INTO utserver_info (server_id)
     SELECT (SELECT id FROM serverlist WHERE ip = ? AND port = ?)", 
     undef, $ip, $port);
}


################################################################################
## Delete all players from a certain server ID
## opts: server id
################################################################################
sub delete_utplayers {
  my ($self, $sid) = @_;
  
  # delete players for server_id
  return $self->{dbh}->do(
    "DELETE FROM utplayer_info WHERE server_id = ?",
    undef, $sid);
}

################################################################################
## Insert player info for a single player in server sid
## opts: server id, player info
################################################################################
sub insert_utplayer {
  my $self = shift;
  my $sid  = shift;
  my %s = (
   updated  => time,
   @_);

  # apparently useless chunk of code
  # FIXME move to site part
  my %H = (
    $s{server_id} ? ( 'server_id = ?' =>      $s{server_id})  : (),
    $s{player}    ? (    'player = ?' =>      $s{player})     : (),
    $s{team}      ? (      'team = ?' => int( $s{team}))      : (),
    $s{frags}     ? (     'frags = ?' => int( $s{frags}))     : (),
    $s{mesh}      ? (      'mesh = ?' =>      $s{mesh})       : (),
    $s{skin}      ? (      'skin = ?' =>      $s{skin})       : (),
    $s{face}      ? (      'face = ?' =>      $s{face})       : (),
    $s{ping}      ? (      'ping = ?' => int( $s{ping}))      : (),
    $s{ngsecret}  ? (  'ngsecret = ?' =>      $s{ngsecret})   : (),
    $s{updated}   ? ('updated = to_timestamp(?)' => $s{updated}) : (),
  );
  
  # insert
  return $self->{dbh}->do(
    "INSERT INTO utplayer_info (server_id, player, team, frags, mesh, skin, face, ping, ngsecret) 
     VALUES (?,?,?,?,?,?,?,?,?)", 
     undef, $sid, $s{player}, $s{team}, $s{frags}, $s{mesh}, $s{skin}, $s{face}, $s{ping}, $s{ngsecret});
}

1;
