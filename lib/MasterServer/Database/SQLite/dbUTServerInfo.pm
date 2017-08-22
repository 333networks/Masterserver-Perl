package MasterServer::Database::SQLite::dbUTServerInfo;

use strict;
use warnings;
use MasterServer::Core::Util 'sqlprint';
use Exporter 'import';

our @EXPORT = qw| add_utserver
               update_utserver 
               delete_utplayers
               insert_utplayer |;

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
    $s{updated}             ? ('updated = datetime(?, \'unixepoch\')' =>      $s{updated})            : (),
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
    $s{updated}   ? ('updated = datetime(?, \'unixepoch\')' => $s{updated}) : (),
  );
  
  # insert
  return $self->{dbh}->do(
    "INSERT INTO utplayer_info (server_id, player, team, frags, mesh, skin, face, ping, ngsecret) 
     VALUES (?,?,?,?,?,?,?,?,?)", 
     undef, $sid, $s{player}, $s{team}, $s{frags}, $s{mesh}, $s{skin}, $s{face}, $s{ping}, $s{ngsecret});
}

1;
