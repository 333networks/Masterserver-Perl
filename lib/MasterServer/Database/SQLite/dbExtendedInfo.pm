package MasterServer::Database::SQLite::dbExtendedInfo;

use strict;
use warnings;
use MasterServer::Core::Util 'sqlprint';
use Exporter 'import';
our @EXPORT = qw| insert_extended
                  update_extended
                  delete_players
                  insert_players |;

################################################################################
## Add extended server information for a new server.
## opts: ipm hostport
################################################################################
sub insert_extended {
  my $self = shift;
  my %o = ( @_);
  return $self->{dbh}->do(
    "INSERT INTO extended_info (server_id)
     SELECT (SELECT id FROM serverlist WHERE ip = ? AND hostport = ?)", 
    undef, $o{ip}, $o{hostport});
}

################################################################################
## Update serverinfo for an existing address to the utserver list.
## opts: all server info data fields.
################################################################################
sub update_extended {
  my $self = shift;
  my %o = (updated => time, @_);

  # try updating it in serverlist
  my %H = (
    $o{minnetver}           ? (            'minnetver = ?' => $o{minnetver} )           : (),
    $o{location}            ? (             'location = ?' => $o{location} )            : (),
    $o{listenserver}        ? (         'listenserver = ?' => $o{listenserver})         : (),
    $o{AdminName}           ? (            'adminname = ?' => $o{AdminName})            : (),
    $o{AdminEMail}          ? (           'adminemail = ?' => $o{AdminEMail})           : (),
    $o{password}            ? (             'password = ?' => $o{password})             : (),
    $o{gametype}            ? (             'gametype = ?' => $o{gametype})             : (),
    $o{gamestyle}           ? (            'gamestyle = ?' => $o{gamestyle})            : (),
    $o{changelevels}        ? (         'changelevels = ?' => $o{changelevels})         : (),
    $o{maptitle}            ? (             'maptitle = ?' => $o{maptitle})             : (),
    $o{mapname}             ? (              'mapname = ?' => $o{mapname})              : (),
    $o{numplayers}          ? (           'numplayers = ?' => $o{numplayers})           : ('numplayers = ?' => 0),
    $o{maxplayers}          ? (           'maxplayers = ?' => $o{maxplayers})           : ('maxplayers = ?' => 0),
    $o{minplayers}          ? (           'minplayers = ?' => $o{minplayers})           : ('minplayers = ?' => 0),
    $o{botskill}            ? (             'botskill = ?' => $o{botskill})             : (),
    $o{balanceteams}        ? (         'balanceteams = ?' => $o{balanceteams} )        : (),
    $o{playersbalanceteams} ? (  'playersbalanceteams = ?' => $o{playersbalanceteams})  : (),
    $o{friendlyfire}        ? (         'friendlyfire = ?' => $o{friendlyfire})         : (),
    $o{maxteams}            ? (             'maxteams = ?' => $o{maxteams})             : (),
    $o{timelimit}           ? (            'timelimit = ?' => $o{timelimit})            : (),
    $o{goalteamscore}       ? (        'goalteamscore = ?' => $o{goalteamscore})        : (),
    $o{fraglimit}           ? (            'fraglimit = ?' => $o{fraglimit})            : (),
    $o{mutators}            ? (             'mutators = ?' => $o{mutators})             : ('mutators = ?' => "None"),
    $o{updated}             ? ( 'updated = datetime(?, \'unixepoch\')' => $o{updated})  : (),
  );
  
  my($q, @p) = sqlprint("UPDATE extended_info !H WHERE server_id = ?", \%H, $o{sid});
  return $self->{dbh}->do($q, undef, @p);
}

################################################################################
## Delete all players from a certain server ID
## opts: server id
################################################################################
sub delete_players {
  my ($self, $sid) = @_;
  
  # delete players with server_id
  return $self->{dbh}->do(
    "DELETE FROM player_info WHERE server_id = ?",
    undef, $sid);
}

################################################################################
## Insert player info for a single player in server sid
## opts: server id, player info
################################################################################
sub insert_players {
  my ($self, @pl) = @_;
  my($q, @p) = sqlprint("INSERT INTO player_info (server_id, player, team, frags, mesh, skin, face, ping, ngsecret) VALUES (!l)", \@pl);
  return $self->{dbh}->do($q, undef, @p);
}

1;
