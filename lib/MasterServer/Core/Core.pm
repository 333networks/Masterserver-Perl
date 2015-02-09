
package MasterServer::Core::Core;

use strict;
use warnings;
use AnyEvent;
use Exporter 'import';
use Data::Dumper 'Dumper';
use DBI;

our @EXPORT = qw | halt main |;

##
## Halt
## Handle shutting down the program for whatever reason.
sub halt {
  my $self = shift;
  
  # When other processes are still 
  # running, set all other scopes 
  # to null/undef?

  # log shutdown
  $self->log("stop", "Stopping the masterserver now.");
  
  # and send signal to condition var
  $self->{must_halt}->send;
  
  # allow everything to be written to the logs
  sleep(2);
  
  exit;
}

##
## Main
## Initialize all processes and start them
sub main {
  my $self = shift;
  
  # condition var prevents or allows the program from ending
  $self->{must_halt} = AnyEvent->condvar;
  
  # determine version info
  $self->version();
  
  # keep several objects alive outside their original scope
  $self->{scope} = ();
  
  
  # Startup procedure
  $self->log("info", "333networks Master Server Application.");
  $self->log("info", "Build:   $self->{build_type}");
  $self->log("info", "Version: $self->{build_version}");
  $self->log("info", "   Written by $self->{build_author}");
  $self->log("info", "Logs are written to $self->{log_dir}");
  
  
  # determine the type of database and load the appropriate module
  { # start db type
    # read from login
    my @db_type = split(':', $self->{dblogin}->[0]);

    # format supported (yet)?
    if ( "Pg SQLite" =~ m/$db_type[1]/i) {
      
      # inform us what DB we try to load
      $self->log("loader","Loading $db_type[1] database module.");
    
      # load dbd and tables/queries for this db type
      MasterServer::load_recursive("MasterServer::Database::$db_type[1]");
      
      # Connect to database
      $self->{dbh} = $self->database_login(); #FIXME!!!!
    }
    else {
      # raise error and halt
      $self->log("fatal", "The masterserver could not determine the chosen database type.");
      $self->halt();
    }
  }  # end db type
  
  
  # start the listening service (listen for UDP beacons)
  $self->{scope}->{beacon_catcher} = $self->beacon_catcher();
  
  
  $self->log("info", "All modules loaded. Starting...");

  
=pod  

  ##############################################################################
  ##
  ##   Initiate Scheduled tasks
  ##
  ##   Main Tasks
  ##      beacon_catcher   (udp server)
  ##      beacon_checker   (udp client, timer)
  ##      browser_server   (tcp server)
  ##      
  ##   Synchronization
  ##      ucc_applet_query (tcp client, timer)
  ##      syncer_scheduler (tcp client, timer)
  ##
  ##   333networks website specific
  ##      ut_server_query  (udp client, timer)
  ##
  ##   Core Functions
  ##      maintenance      (timer, dbi)
  ##      statistics       (timer, dbi)
  ##
  ## (store objects in hash to keep them alive outside their own scopes)
  ##############################################################################
  
  ## servers
   $ae{beacon_catcher}    = $self->beacon_catcher();
   $ae{beacon_checker}    = $self->beacon_checker_scheduler();
   $ae{browser_server}    = $self->browser_server();

   # synchronizing
   $ae{ucc_applet_query}  = $self->ucc_applet_query_scheduler();
   $ae{syncer_scheduler}  = $self->syncer_scheduler();

   # status info for UT servers (333networks site)
   $ae{ut_server_scheduler} = $self->ut_server_scheduler();  
   
   # maintenance
   $ae{maintenance_runner}  = $self->maintenance_runner();
   $ae{stats_runner}        = $self->stats_runner();
=cut










  # prevent main program from ending prematurely
  $self->{must_halt}->recv;
  $self->log("stop", "Logging off. Enjoy your day.");
}

1;
