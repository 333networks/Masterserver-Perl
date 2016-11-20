
package MasterServer::Database::Pg::dbCore;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw| database_login |;

################################################################################
## login to the database with credentials provided in the config file.
## returns dbh object or quits application on error.
##
## Recommended database types: Postgresql, MySQL or SQLite. Warranty void if
## other database types are used. Use at your own risk.
################################################################################
sub database_login {
  my $self = shift;

  # get db info
  my @db_type = split(':', $self->{dblogin}->[0]);
    
  # create the dbi object
  my $dbh = DBI->connect(@{$self->{dblogin}}, {PrintError => 1});
  
  # verify that the database connected
  if (defined $dbh) {
  
    # log the event
    $self->log("info","Connected to the $db_type[1] database.");
    
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
  
  # in case of any other error, return undef.
  return undef;
}

1;
