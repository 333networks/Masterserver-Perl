
package MasterServer::Database::Pg::dbCiphers;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw| clear_ciphers 
                  insert_cipher 
                  get_game_props |;

################################################################################
## Clear all existing ciphers from the database
################################################################################
sub clear_ciphers {
  my $self = shift;

  # delete ALL entries
  my $u = $self->{dbh}->do("DELETE FROM games");
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
################################################################################
sub get_game_props {
  my ($self, $gn) = @_;
  
  # get cipher from db if gamename exists
  return $self->{dbh}->selectall_arrayref(
    'SELECT * FROM games WHERE gamename = ?', 
    {Slice=>{}}, 
    lc $gn)->[0];
}

1;
