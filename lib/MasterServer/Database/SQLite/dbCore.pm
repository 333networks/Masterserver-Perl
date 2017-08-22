package MasterServer::Database::SQLite::dbCore;

use strict;
use warnings;
use POSIX qw/strftime/;
use Exporter 'import';
our @EXPORT = qw| database_login dump_database |;

################################################################################
## login to the database with credentials provided in the config file.
## returns dbh object or quits application on error.
################################################################################
sub database_login {
  my $self = shift;
  my @db_type = split(':', $self->{dblogin}->[0]);

  # check if database file exists
  my $db_file = [split(':', $self->{dblogin}->[0])]->[2];
     $db_file =~ s/dbname=//i;

  # fatal error if database does not exist
  unless (-e $db_file) {
    $self->log("fatal", "Database file $db_file does not exist!");
    $self->halt();
  }

  # connect to SQLite database
  my $dbh = DBI->connect(@{$self->{dblogin}}, {PrintError => 1});
  
  # verify that the database connected
  if (defined $dbh) {
    $self->log("info","Connected to the $db_type[1] database $db_type[2]");
    $dbh->{printerror} = 1;
    
    # synchronous read/writing to the SQLite file OFF. Faster, but risk on data
    # loss on crashes, premature exits or power failure.
    $dbh->do("PRAGMA synchronous = OFF");
    
    # allow the use of foreign keys (referencing)
    $dbh->do("PRAGMA foreign_keys = ON");
    return $dbh;
  }
  else {
    # fatal error
    $self->log("fatal", "$DBI::errstr!");
    $self->halt();
  }
}

################################################################################
## Dump the database in the data/dump folder.
## useful for backups, historical data
################################################################################
sub dump_database {
  my $self = shift;
  my $time = strftime('%Y-%m-%d-%H-%M',localtime);
  
  # read db credentials from db login
  my @db_type = split ':', $self->{dblogin}->[0];
  $db_type[2] =~ s/dbname=//;
  my @db_path = split '/', $db_type[2];
  
  # make a copy of the database file
  system("cp $db_type[2] $self->{root}/data/dumps/SQLite-$time-$db_path[-1]");
  $self->log("dump", "Dumping database to /data/dumps/SQLite-$time-$db_path[-1]");
}

1;
