
package MasterServer::Core::Core;

use strict;
use warnings;
use AnyEvent;
use Exporter 'import';
use DBI;

our @EXPORT = qw | halt select_database_type main |;

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
## Set up the database connection
################################################################################
sub select_database_type {
  my $self = shift;

  # Connect to database
  $self->{dbh} = $self->database_login();
    
  # and test whether we succeeded.
  $self->halt() unless (defined $self->{dbh});
}

################################################################################
## Initialize all processes and start various functions
################################################################################
sub main {
  my $self = shift;
  
  # condition var prevents or allows the program from ending
  $self->{must_halt} = AnyEvent->condvar;
  
  # force version info
  $self->version();
  
  # print startup
  print "Running...\n";
  
  # keep several objects alive outside their original scope
  $self->{scope} = ();
  
  # startup procedure information
  $self->log("info", "");
  $self->log("info", "");
  $self->log("info", "333networks Master Server Application.");
  $self->log("info", "Hostname: $self->{masterserver_hostname}");
  $self->log("info", "Build:    $self->{build_type}");
  $self->log("info", "Version:  $self->{build_version}");
  $self->log("info", "Author:   $self->{build_author}");
  $self->log("info", "Logs:     $self->{log_dir}");
  
  # determine the type of database and load the appropriate module
  $self->select_database_type();
  
  #
  # Prepare necessary tasks for running the masterserver
  #
  
  # (re)load the list with ciphers from the config file, into the database
  $self->load_ciphers();
  
  # set first run flag to avoid ignoring servers after downtime
  $self->{firstrun} = undef;
  $self->{firstruntime} = time;

  ###  
  #
  # activate all schedulers and functions
  #
  ###
  
  #
  # Timers
  #
  # tasks that are executed once or twice per hour
  $self->{scope}->{long_periodic_tasks} = $self->long_periodic_tasks();
  #
  # tasks that are executed every few minutes
  $self->{scope}->{short_periodic_tasks} = $self->short_periodic_tasks();
  #
  # tasks that are executed every few milliseconds
  $self->{scope}->{udp_ticker} = $self->udp_ticker();
  
  #
  # Network listeners
  #
  # start the listening service (listen for UDP beacons)
  $self->{scope}->{beacon_catcher} = $self->beacon_catcher();
  #
  # provide server lists to clients with the browser host server
  $self->{scope}->{browser_host} = $self->browser_host();
  
  # all modules loaded. Running...
  $self->log("info", "All modules loaded. Masterserver is now running.");
  
  # prevent main program from ending prematurely
  $self->{must_halt}->recv;
}

1;
