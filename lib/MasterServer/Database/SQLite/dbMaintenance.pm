package MasterServer::Database::SQLite::dbMaintenance;

use strict;
use warnings;
use Exporter 'import';
our @EXPORT = qw| delete_old_pending 
                      remove_pending |;

################################################################################
## delete unresponsive servers from the pending list
## where the server is unresponsive for more than 1 hour
################################################################################
sub delete_old_pending {
  my $self = shift;
  my $u = $self->{dbh}->do(
     "DELETE FROM pending 
      WHERE added < datetime(?, \'unixepoch\')", undef, time-3600);
  $self->log("delete", "Removed $u entries from pending.") if ($u > 0);
}

################################################################################
## Remove an entry from the pending list. Returns 0 if removed or -1 in case
## of error(s).
################################################################################
sub remove_pending {
  my $self = shift;
  my %o = ( @_); 
  my $u = $self->{dbh}->do("DELETE FROM pending WHERE ip = ? AND heartbeat = ?", 
    undef, $o{ip}, $o{port});
  $self->log("delete", "removed $o{ip}, $o{port} from pending (".$u."x)") if ($u > 0);
}

1;
