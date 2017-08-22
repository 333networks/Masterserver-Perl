package MasterServer::Database::SQLite::dbAddServers;

use strict;
use warnings;
use MasterServer::Core::Util 'sqlprint';
use Exporter 'import';
our @EXPORT = qw| insert_server
                  update_server 
                  insert_pending |;

################################################################################
## Insert minimalistic game data into serverlist
## params: ip, port, hostport
################################################################################
sub insert_server {
  my $self = shift;
  my %o = (@_);

  # if not found at all, add to pending
  return $self->{dbh}->do(
    "INSERT INTO serverlist (ip, port, hostport, country) VALUES (?, ?, ?, ?)", 
    undef, $o{ip}, $o{port}, $o{hostport}, $self->ip2country($o{ip}) );
}

################################################################################
## Update the server info in the serverlist
## required: id or ip + port/hostport
################################################################################
sub update_server {
  my $self = shift;
  my %o = (updated  => time, @_);

  # either id, ip+port or ip+hostport are provided.
  my %W = (
    $o{id}       ? (      'id = ?' => $o{id})       : (),
    $o{ip}       ? (      'ip = ?' => $o{ip})       : (),
    $o{port}     ? (    'port = ?' => $o{port})     : (),
    $o{hostport} ? ('hostport = ?' => $o{hostport}) : (),
  );

  # update where possible
  my %H = (
    $o{gamename} ? ('gamename = ?' => lc $o{gamename}) : (),
    $o{gamever}  ? ( 'gamever = ?' => $o{gamever})     : (),
    $o{hostname} ? ('hostname = ?' => $o{hostname})    : (),
    $o{hostport} ? ('hostport = ?' => $o{hostport})    : (),
    $o{direct}   ? (  'b333ms = CAST(? AS BOOLEAN)' => $o{direct})  : (),
    $o{direct}   ? (  'beacon = datetime(?, \'unixepoch\')'    => $o{updated}) : (),
    $o{updated}  ? ( 'updated = datetime(?, \'unixepoch\')'    => $o{updated}) : (),
  );

  my($q, @p) = sqlprint("UPDATE serverlist !H !W", \%H, \%W);
  return $self->{dbh}->do($q, undef, @p);
}

################################################################################
## check if an ip, port/hostport combination is recent in the serverlist.
## if not, add the address to the pending list
################################################################################
sub insert_pending {
  my $self = shift;
  my %o = (updated => 3600, @_ );

  # selection criteria
  my %W = (
    $o{ip}       ? (      'ip = ?' => $o{ip})       : (),
    $o{port}     ? (    'port = ?' => $o{port})     : (),
    $o{updated}  ? ('updated > datetime(?, \'unixepoch\')' => (time-$o{updated})) : (),
  );

  # determine if it already exsits
  my($q, @p) = sqlprint("SELECT id FROM serverlist !W", \%W);
  my $u = $self->{dbh}->do($q, undef, @p);
  return 0 if int($u);

  # else, insert in pending (duplicates may exist -- see remove_pending)
  return $self->{dbh}->do("INSERT INTO pending (ip, heartbeat) VALUES (?, ?)", 
    undef, $o{ip}, $o{port} );
}

1;
