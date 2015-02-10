
package MasterServer::Database::Pg::dbCore;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw| database_login |;

################################################################################
## database_login
## login to the database with credentials provided in the config file.
## returns dbh object
################################################################################
sub database_login {
  my $self = shift;

  # create the dbi object
  my $dbh = DBI->connect(@{$self->{dblogin}}, {PrintError => 0});
  
  # verify that the database connected
  if (defined $dbh) {
    # log the event
    $self->log("load","Connected to the Postgres database.");
    
    # turn on error printing
    $dbh->{printerror} = 1;
    
    # return the dbi object for further use
    return $dbh;
  }
  else {
    # fatal error
    $self->log("fatal", "$DBI::errstr!");
    
    # end program
    $self->halt();
  }
  
  # unreachable
  return undef;
}

1;
