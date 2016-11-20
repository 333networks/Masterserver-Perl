
package MasterServer::Database::SQLite::dbCore;

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
  
  # check if database file exists
  my $db_file = [split(':', $self->{dblogin}->[0])]->[2];
     $db_file =~ s/dbname=//i;

  unless (-e $db_file) {
    # fatal error
    $self->log("fatal", "Database file $db_file does not exist!");
    
    # end program
    $self->halt();
  }
  
  # inform what DB we try to load
  # $self->log("info","Database: $db_type[1]");
    
  # create the dbi object
  my $dbh = DBI->connect(@{$self->{dblogin}}, {PrintError => 1});
  
  # verify that the database connected
  if (defined $dbh) {
  
    # log the event
    $self->log("info","Connected to the $db_type[1] database.");
    
    # turn on error printing
    $dbh->{printerror} = 1;
    
    # synchronous read/writing to the SQLite file OFF. That means: when the script 
    # shuts down unexpectedly, i.e. because of power failure or a crash, changes 
    # to the database are NOT SAVED. However, if this setting is not turned OFF, 
    # it takes too long to write to the database, which means that new beacons, 
    # requests and servers cannot be processed. You don't have a choice, really..
    $dbh->do("PRAGMA synchronous = OFF");
    
    # allow the use of foreign keys (referencing)
    $dbh->do("PRAGMA foreign_keys = ON");
    
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
