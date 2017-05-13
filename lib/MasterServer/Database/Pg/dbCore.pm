package MasterServer::Database::Pg::dbCore;

use strict;
use warnings;
use POSIX qw/strftime/;
use Exporter 'import';

our @EXPORT = qw| database_login dump_database |;

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

  # inform what db we try to load
  $self->log("info","Database: $db_type[1], $db_type[2]");
    
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

################################################################################
## Dump the database in the data/dump folder.
## useful for backups, historical data
################################################################################
sub dump_database {
  my $self = shift;
  
  # filename / time
  my $time = strftime('%Y-%m-%d-%H-%M',localtime);
  
  # FIXME
  # separate absolute path and relative path, 
  # split database filename for dump filename.
  
  # read db credentials from db login
  my @db_type = split(':', $self->{dblogin}->[0]);
  $db_type[2] =~ s/dbname=//;
  
  # use pg_dump to dump Postgresql databases
  system("pg_dump $db_type[2] -U $self->{dblogin}->[1] > $self->{root}/data/dumps/Pg-$time-$db_type[2].db");
  
  # log
  $self->log("dump", "Dumping database to /data/dumps/$db_type[1]-$time.db");
}


1;
