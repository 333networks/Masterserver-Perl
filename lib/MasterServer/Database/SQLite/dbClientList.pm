
package MasterServer::Database::SQLite::dbClientList;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw| get_gamenames
                  get_game_list |;


################################################################################
## get a list of distinct gamenames currently in the database. it does not 
## matter whether they are recent or old, as long as the game is currently in
## the database.
## 
## returns: hashref of gamenames
################################################################################
sub get_gamenames {
  my $self = shift;

  return $self->{dbh}->selectall_arrayref(
     "SELECT distinct gamename 
      FROM serverlist");
}

################################################################################
## get the list of games of a certain $gamename, excluding the ones excempted
## via the blacklist
## only returns server addresses that are no more than 1 hours old
################################################################################
sub get_game_list {
  my ($self, $gamename) = @_;
  
  return $self->{dbh}->selectall_arrayref(
    "SELECT ip, port 
     FROM serverlist
     WHERE updated > datetime(CURRENT_TIMESTAMP, '-3600 seconds')
     AND gamename = ?
     AND NOT blacklisted", 
     undef, lc $gamename);
}


1;
