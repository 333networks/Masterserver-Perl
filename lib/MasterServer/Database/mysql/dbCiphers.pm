
package MasterServer::Database::mysql::dbCiphers;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw| clear_ciphers 
                  insert_cipher 
                  get_cipher 
                  get_default_port |;

################################################################################
## Clear all existing ciphers from the database
################################################################################
sub clear_ciphers {
  my $self = shift;

  # delete ALL entries
  my $u = $self->{dbh}->do("DELETE FROM games");
  
  # notify 
  $self->log("delete", "Removed all ciphers") if ($u > 0);

  # removed from games
  return 2 if ($u > 0);

  # or else report notice
  $self->log("notice", "No ciphers deleted!");
  return -1;

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
      $opt{gamename}, $opt{cipher}, $opt{description}, $opt{default_qport});
  
  # notify
  $self->log("add", "Added cipher for $opt{gamename}") if ($u and $u > 0);
  return 1 if ($u and $u > 0);
  
  # or else report error
  $self->log("error", "An error occurred adding a cipher for $opt{gamename}");
  return -1;
  
}


################################################################################
## get the cipher that goes with gamename
################################################################################
sub get_cipher {
  my ($self, $gn) = @_;

  # no gamename specified? "undef" is not a known cipher, so send that instead.  
  return 'undef' if !$gn;
  
  # get cipher from db if gamename exists
  my $cipher = $self->{dbh}->selectall_arrayref(
    'SELECT cipher FROM games WHERE gamename = ?', undef, 
    lc $gn)->[0]->[0];
  
  # return a non-zero-length string
  return ($cipher ? $cipher : 'undef');
}

################################################################################
## get the default query port that goes with gamename
################################################################################
sub get_default_port {
  my ($self, $gn) = @_;

  # no gamename specified? default port is 0
  return 0 if !$gn;
  
  # get port from db if gamename exists
  my $p = $self->{dbh}->selectall_arrayref(
    'SELECT default_qport FROM games WHERE gamename = ?', undef, 
    lc $gn)->[0]->[0];
  
  # return port or zero
  return $p || 0;
}

1;
