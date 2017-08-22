package MasterServer::Core::Core;

use strict;
use warnings;
use AnyEvent;
use Exporter 'import';
use DBI;
our @EXPORT = qw | halt select_database_type main |;

################################################################################
## Handle shutting down the program in case a fatal error occurs.
## clear all other timers, network servers, etc
################################################################################
sub halt {
  my $self = shift;
  $self->log("stop", "stopping the masterserver!");
  $self->{dbh}->disconnect() if (defined $self->{dbh});
  $self->{dbh}   = undef;
  $self->{scope} = undef;
  $self->{must_halt}->send;
  exit; # time for a beer.  
}

################################################################################
## Set up the database connection
## determine the type of database and load the appropriate module
################################################################################
sub select_database_type {
  my $self = shift;
  my @db_type = split(':', $self->{dblogin}->[0]); # from config file

  # format supported?
  if ( "Pg SQLite mysql" =~ m/$db_type[1]/i) {
    # load database for this type
    MasterServer::load_recursive("MasterServer::Database::$db_type[1]");
    $self->{dbh} = $self->database_login();
    $self->halt() unless (defined $self->{dbh});
  }
  else { # we can not continue without database
    $self->log("fatal", "the masterserver could not determine the chosen database type");
    $self->halt();
  }
}

################################################################################
## Initialize all processes and start various functions
################################################################################
sub main {
  my $self = shift;
  $self->{must_halt} = AnyEvent->condvar;
  $self->version();
  
  # startup
  print "Running 333networks Master Server Application...\n";
  $self->log("info", "333networks Master Server Application.");
  $self->log("info", "hostname: $self->{masterserver_hostname}");
  $self->log("info", "build:    $self->{build_type}");
  $self->log("info", "version:  $self->{build_version}");
  $self->log("info", "author:   $self->{build_author}");
  $self->log("info", "logs:     $self->{log_dir}");
  
  # load database and set up scope for timers/network
  $self->select_database_type();
  $self->{scope} = ();  

  # load the list with ciphers from the config file if no ciphers were detected
  $self->load_ciphers() unless $self->check_cipher_count();
  $self->{game} = undef;
  
  # reload the list with masterservers and master applets from config
  $self->load_sync_masters();
  $self->load_applet_masters();
  
  # first run flag for all startup actions
  $self->{firstrun} = undef;
  $self->{firstruntime} = time;

  # beacons and serverlists (listen for UDP beacons / TCP requests)
  $self->{scope}->{beacon_catcher} = $self->beacon_catcher();
  $self->{scope}->{browser_host} = $self->browser_host();

  # recurring tasks (sync and updates)
  $self->{scope}->{long_periodic_tasks} = $self->long_periodic_tasks();
  $self->{scope}->{short_periodic_tasks} = $self->short_periodic_tasks();

  # verify and update server status
  $self->{scope}->{udp_ticker} = $self->udp_ticker() if $self->{beacon_checker_enabled};

  # all modules loaded. Running...
  $self->log("info", "all modules loaded. Masterserver is now running!");
  $self->{must_halt}->recv;
}

1;
