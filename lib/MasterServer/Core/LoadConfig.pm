package MasterServer::Core::LoadConfig;

use strict;
use warnings;
use DBI;
use POSIX qw/strftime/;
use Exporter 'import';
our @EXPORT = qw | load_applet_masters 
                     load_sync_masters
                      add_sync_master |;

################################################################################
## Load configuration variables to the database, helper functions
################################################################################
sub load_applet_masters {
  my $self = shift;

  # iterate through all games per entry
  foreach my $master_applet (@{$self->{master_applet}}) {
    for my $gamename (@{$master_applet->{games}}) {
      
      # resolve domain names
      my $applet_ip = $self->host2ip($master_applet->{address});

      # check if all credentials are valid
      if ($applet_ip && $master_applet->{port} && $gamename) {
        $self->add_master_applet(
            ip        => $applet_ip,
            hostport  => $master_applet->{port},
            gamename  => $gamename,
          );
        $self->log("add", "added applet $master_applet->{address}:$master_applet->{port} for $gamename");
      } # else: insufficient info available
      else { $self->log("fail", "could not add master applet: ".
              ($applet_ip             || "unknown ip"). ", ".
              ($master_applet->{port} || "0"). ", ".
              ($gamename              || "game"));}
    } # end gamename
  } # end master_applet
  
  # reset added/updated time clear the applet list from memory
  $self->reset_master_applets;
  $self->{master_applet} = ();
  $self->log("info", "applet database successfully updated");

}

################################################################################
## There are three ways to load new masterservers to sync with.
##   1: from the config file; address, port and beaconport are provided
##   2: from a heartbeat; this automatically parses like all other servers
##   3: from another sync request. Add if sufficient info is available
################################################################################
sub load_sync_masters {
  my $self = shift;

  # add config entries to database
  foreach my $sync_host (@{$self->{sync_masters}}) {
    $self->add_sync_master($sync_host);}
  
  # clear list from memory
  $self->{sync_masters} = ();
  $self->log("info", "sync server database successfully updated");
  
}

################################################################################
## Add a sync master according to cases 1 and 3.
## Check for valid IP, port and/or beaconport
################################################################################
sub add_sync_master {
  my ($self, $sync_host) = @_;
  my $sync_ip = $self->host2ip($sync_host->{address});
  
  # check if all credentials are valid
  if ($sync_ip && $sync_host->{beacon}) {
    # add it to the pending list so it gets picked up with the "normal" status update
    $self->insert_pending(ip => $sync_ip, port => $sync_host->{beacon});
    $self->log("add", "added sync $sync_host->{address}:$sync_host->{beacon}");
  } # else: insufficient info available
  else { $self->log("fail", "failed to add sync master: ".
          ($sync_host->{address}|| "domain"). ", ".
          ($sync_ip             || "invalid ip"). ", ".
          ($sync_host->{beacon} || "invalid beacon port") );
  }
}

1;
