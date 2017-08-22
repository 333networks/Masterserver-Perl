package MasterServer::Database::Pg::dbCore;

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
  
  # connect to Pg database
  my $dbh = DBI->connect(@{$self->{dblogin}}, {PrintError => 1});
  
  # verify that the database connected
  if (defined $dbh) {
    $self->log("info","Connected to $db_type[1] database $db_type[2]");
    $dbh->{printerror} = 1;
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
  my @db_type = split(':', $self->{dblogin}->[0]);
  $db_type[2] =~ s/dbname=//;
  
  # use pg_dump to dump Postgresql databases
  system("pg_dump $db_type[2] -U $self->{dblogin}->[1] > $self->{root}/data/dumps/Pg-$time-$db_type[2].db");
  $self->log("dump", "Dumping database to /data/dumps/Pg-$time-$db_type[2].db");
}


1;
