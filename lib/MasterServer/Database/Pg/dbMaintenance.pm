package MasterServer::Database::Pg::dbMaintenance;

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
  my ($self) = shift;

  # remove servers
  my $u = $self->{dbh}->do(
     "DELETE FROM pending 
      WHERE added < to_timestamp(?)", undef, time-3600);
  
  # notify 
  $self->log("delete", "Removed $u entries from pending.") if ($u > 0);
}

################################################################################
## Remove an entry from the pending list. Returns 0 if removed or -1 in case
## of error(s).
################################################################################
sub remove_pending {
  my ($self, $id) = @_;
  
  # if address is in list, update the timestamp
  my $u = $self->{dbh}->do("DELETE FROM pending WHERE id = ?", undef, $id);
  
  # notify 
  $self->log("delete", "removed pending id $id from pending") if ($u > 0);
}

1;
