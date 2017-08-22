package MasterServer::Database::SQLite::dbCiphers;

use strict;
use warnings;
use Exporter 'import';
our @EXPORT = qw| check_cipher_count
                  clear_ciphers 
                  insert_cipher 
                  get_game_props |;

################################################################################
## Check if ciphers exist
################################################################################
sub check_cipher_count {
  my $self = shift;
  return $self->db_all('SELECT count(gamename) as num from games')->[0]->{num};
}

################################################################################
## Clear all existing ciphers from the database
################################################################################
sub clear_ciphers {
  my $self = shift;
  $self->{dbh}->do("DELETE FROM games");
}

################################################################################
## Insert the list of supported games and their ciphers / default ports / 
## descriptions included from the data/supportedgames.pl file.
################################################################################
sub insert_cipher {
  my ($self, %opt) = @_;
  
  # insert a single cipher/key combo
  my $u = $self->{dbh}->do(
     "INSERT INTO games (
          gamename, 
          cipher, 
          description, 
          default_qport) 
      VALUES(?, ?, ?, ?)", undef, 
      lc $opt{gamename}, $opt{cipher}, $opt{description}, $opt{default_qport});
  return 1 if ($u and $u > 0);
  
  # or else report error
  $self->log("error", "An error occurred adding a cipher for $opt{gamename}");
}

################################################################################
## get the cipher, description and default port that goes with given gamename
## 
################################################################################
sub get_game_props {
  my $s = shift;
  my %o = (sort => '', @_);
  
  my %where = (
    $o{gamename}      ? ('gamename = ?'       => lc $o{gamename})   : (),
    $o{cipher}        ? ('cipher = ?'         => $o{cipher})        : (),
    $o{description}   ? ('description = ?'    => $o{description})   : (),
    $o{default_qport} ? ('default_qport = ?'  => $o{default_qport}) : (),
    $o{num_uplink}    ? ('num_uplink = ?'     => $o{num_uplink})    : (),
    $o{num_total}     ? ('num_total = ?'      => $o{num_total})     : (),
    $o{num_gt}        ? ('num_total >= ?'     => $o{num_gt})        : (),
  );
  
  my @select = ( qw| gamename cipher description default_qport num_uplink num_total|,);
  my $order = sprintf {
      gamename      => 'gamename %s',
      cipher        => 'cipher %s',
      description   => 'description %s',
      default_qport => 'default_qport %s',
      num_uplink    => 'num_uplink %s',
      num_total     => 'num_total %s',
  }->{ $o{sort}||'gamename' }, $o{reverse} ? 'DESC' : 'ASC';

  return $s->db_all( q|
    SELECT !s FROM games
      !W
      ORDER BY !s|
      .($o{limit} ? " LIMIT ?" : ""),
    join(', ', @select), \%where, $order, ($o{limit} ? $o{limit} : ()),
  );
}

1;
