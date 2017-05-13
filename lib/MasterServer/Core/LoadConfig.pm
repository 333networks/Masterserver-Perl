package MasterServer::Core::LoadConfig;

use strict;
use warnings;
use AnyEvent;
use POSIX qw/strftime/;
use Exporter 'import';
use DBI;

our @EXPORT = qw | load_applet_masters 
                     load_sync_masters
                      add_sync_master |;

################################################################################
## Load configuration variables to the database, helper functions
################################################################################
sub load_applet_masters {
  my $self = shift;

  # loop through config entries
  foreach my $master_applet (@{$self->{master_applet}}) {
    # master_applet contains
    #   address --> domain
    #   port    --> tcp port
    #   games   --> array of gamenames
    
    # iterate through all games per entry
    for my $gamename (@{$master_applet->{games}}) {
      
      # resolve domain names
      my $applet_ip = $self->host2ip($master_applet->{address});

      # check if all credentials are valid
      if ($applet_ip && 
          $master_applet->{port} && 
          $gamename) 
      {
        # add to database
        $self->add_master_applet(
            ip        => $applet_ip,
            port      => $master_applet->{port},
            gamename  => $gamename,
          );
        
        #log
        $self->log("add", "added applet $master_applet->{address}:$master_applet->{port} for $gamename");
        
      } # else: insufficient info available
      else {
        $self->log("fail", "Could not add master applet: ".
            ($applet_ip             || "unknown ip"). ", ".
            ($master_applet->{port} || "0"). ", ".
            ($gamename              || "game"). "."
          );
      }
    } # end gamename
  } # end master_applet
  
  # reset added/updated time to last current time
  $self->reset_master_applets();
  
  # clear out the original variable, we don't use it anymore
  $self->{master_applet} = ();
  
  # report
  $self->log("info", "Applet database successfully updated!");

}

################################################################################
## There are three ways to load new masterservers to sync with.
##   1: from the config file; address, port and beaconport are provided
##   2: from a heartbeat; this automatically parses like all other servers
##   3: from another sync request. Add if sufficient info is available
################################################################################
sub load_sync_masters {
  my $self = shift;

  # loop through config entries
  foreach my $sync_host (@{$self->{sync_masters}}) {
  
    # add them to database
    $self->add_sync_master($sync_host);
  }
  
  # clear out the original variable, we don't use it anymore
  $self->{sync_masters} = ();
  
  # report
  $self->log("info", "Sync server database successfully updated!");
  
}

################################################################################
## Add a sync master according to cases 1 and 3.
## Check for valid IP, port and/or beaconport
################################################################################
sub add_sync_master {
  my ($self, $sync_host) = @_;
  
  # sync_host contains
  #   address --> domain
  #   port    --> tcp port
  #   beacon  --> udp port
  
  # resolve domain names
  my $sync_ip = $self->host2ip($sync_host->{address});
  
  # check if all credentials are valid
  if ($sync_ip && 
      $sync_host->{beacon} && 
      $sync_host->{port}) 
  {
    # select sync master from serverlist
    my $entry = $self->get_server(ip => $sync_ip, 
                                  port => $sync_host->{beacon})->[0];

    # was found, update the entry
    if (defined $entry) {
      # update the serverlist with 
      my $sa = $self->update_server_list(
        ip       => $sync_ip,
        port     => $sync_host->{beacon},
        hostport => $sync_host->{port},
        gamename => "333networks",
      );
    }
    # was not found, insert clean entry
    else {
      my $sa = $self->add_server_list(
        ip       => $sync_ip,
        port     => $sync_host->{beacon},
        hostport => $sync_host->{port},
        gamename => "333networks",
      );
      
      #log
      $self->log("add", "added sync $sync_host->{address}:$sync_host->{port},$sync_host->{beacon}");
    }
  } # else: insufficient info available
  else {
    $self->log("fail", "Could not add sync master: ".
        ($sync_ip             || "ip"). ", ".
        ($sync_host->{beacon} || "0"). ", ".
        ($sync_host->{port}   || "0"). "."
      );
  }
}

1;
