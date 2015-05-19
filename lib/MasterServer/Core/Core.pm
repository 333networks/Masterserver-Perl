
package MasterServer::Core::Core;

use strict;
use warnings;
use AnyEvent;
use Exporter 'import';
use DBI;

our @EXPORT = qw | halt main |;

################################################################################
## Handle shutting down the program in case a fatal error occurs.
################################################################################
sub halt {
  my $self = shift;
  
  # log shutdown
  $self->log("stop", "Stopping the masterserver.");
  
  # clear all other timers, network servers, etc
  $self->{dbh}->disconnect() if (defined $self->{dbh});
  $self->{dbh}   = undef;
  $self->{scope} = undef;
  
  # and send signal to condition var to let the loops end
  $self->{must_halt}->send;
  
  # log halt  
  $self->log("stop", "Shutting down NOW!");
  
  # time for a beer.  
  exit;
}

################################################################################
## Initialize all processes and start various functions
################################################################################
sub main {
  my $self = shift;
  
  # condition var prevents or allows the program from ending
  $self->{must_halt} = AnyEvent->condvar;
  
  # determine version info
  $self->version();
  
  # keep several objects alive outside their original scope
  $self->{scope} = ();
  
  # startup procedure information
  $self->log("info", "333networks Master Server Application.");
  $self->log("info", "Build:   $self->{build_type}");
  $self->log("info", "Version: $self->{build_version}");
  $self->log("info", "Written by $self->{build_author}");
  $self->log("info", "Logs are written to $self->{log_dir}");
  
  # determine the type of database and load the appropriate module
  {
    # read from login
    my @db_type = split(':', $self->{dblogin}->[0]);

    # format supported?
    if ( "Pg SQLite" =~ m/$db_type[1]/i) {
      
      # inform us what DB we try to load
      $self->log("load","Loading $db_type[1] database module.");
    
      # load dbd and tables/queries for this db type
      MasterServer::load_recursive("MasterServer::Database::$db_type[1]");
      
      # Connect to database
      $self->{dbh} = $self->database_login();
      
      # and test whether we succeeded.
      $self->halt() unless (defined $self->{dbh});
    }
    else {
      # raise error and halt
      $self->log("fatal", "The masterserver could not determine the chosen database type.");
      $self->halt();
    }
  }
  
  # start the listening service (listen for UDP beacons)
  $self->{scope}->{beacon_catcher} = $self->beacon_catcher();
  
  # start the beacon checker service (query entries from the pending list)
  $self->{scope}->{beacon_checker} = $self->beacon_checker() if ($self->{beacon_checker_enabled});

  # provide server lists to clients with the browser host server
  $self->{scope}->{browser_host} = $self->browser_host();
  
  # query other masterserver applets to get more server addresses
  $self->{scope}->{ucc_applet_query} = $self->ucc_applet_query_scheduler() if ($self->{master_applet_enabled});  
  
  # synchronize with 333networks-based masterservers
  $self->{scope}->{syncer_scheduler} = $self->syncer_scheduler() if ($self->{sync_enabled});
  
  # all modules loaded. Running...
  $self->log("info", "All modules loaded. Masterserver is now running.");

  # prevent main program from ending prematurely
  $self->{must_halt}->recv;
}

1;
