
package MasterServer::Core::Schedulers;

use strict;
use warnings;
use AnyEvent;
use POSIX qw/strftime/;
use Exporter 'import';
use DBI;

our @EXPORT = qw | 
   long_periodic_tasks 
  short_periodic_tasks 
|;

################################################################################
## tasks that are executed only once or twice per hour
################################################################################
sub long_periodic_tasks {
  my $self = shift;
  my $num  = 0;

  return AnyEvent->timer (
    after     =>  300,  # 5 minutes grace time
    interval  => 1800,  # execute every half hour
    cb        => sub {

      ## update Killing Floor stats
      $self->read_kfstats();

      # time spacer
      my $t = 0;
      
      # clean out handles from the previous round (executed or not)
      $self->{scope}->{sync} = ();
      
      ## Query Epic Games'-based UCC applets periodically to get an additional
      ## list of online UT, Unreal (or other) game servers. 
      if ($self->{master_applet_enabled}) {
        for my $ms (@{$self->{master_applet}}) {
        
          # add 3 second delay to spread network/server load
          $self->{scope}->{sync}->{$t} = AnyEvent->timer(
            after => 3*$t++, 
            cb => sub{$self->query_applet($ms)}
          );
        }
      }
      
      # do NOT reset $t, keep padding time -- you should not have more than 600
      # entries in applets/syncer in total.
      
      ## Request the masterlist for selected or all games from other 
      ## 333networks-based masterservers that uplinked to us and otherwise made
      ## our list (config, manual entry, etc)
      if ($self->{sync_enabled}) {
        foreach my $ms (values %{$self->masterserver_list()}) {
        
          # add 3 second delay to spread network/server load
          $self->{scope}->{sync}->{$t} = AnyEvent->timer(
            after => 3*$t++, 
            cb => sub{$self->sync_with_master($ms) if ($ms->{tcp} > 0)}
          );
        }
      }
      
      #
      # Also very long-running tasks, like once per day:
      #
      if ($num++ >= 47) {
        # reset counter
        $num = 0;
        
        #
        # do database dump
        #
        my $time = strftime('%Y-%m-%d-%H-%M',localtime);
      
        # read db type from db login
        my @db_type = split(':', $self->{dblogin}->[0]);
        $db_type[2] =~ s/dbname=//;
        
        if ($db_type[1] eq "Pg") {
          # use pg_dump to dump Postgresql databases
          system("pg_dump $db_type[2] -U $self->{dblogin}->[1] > $self->{root}/data/dumps/$db_type[1]-$time.db");
          $self->log("dump", "Dumping database to /data/dumps/$db_type[1]-$time.db");
        }
      }
      
    },
  );
}

################################################################################
## tasks that are executed every few minutes
################################################################################
sub short_periodic_tasks {
  my $self = shift;
  
  return AnyEvent->timer (
    after     => 10,
    interval  => 120,
    cb        => sub {
      
      ## update stats on direct beacons and total number of servers
      $self->update_stats();
      
      ## determine whether servers are still uplinking to us. If not, toggle. 
      $self->write_direct_beacons() if (defined $self->{firstrun});
      
      ## delete old servers from the "pending" list (except for the first run)
      $self->delete_old_pending() if (defined $self->{firstrun});

      ## uplink to other 333networks masterservers with heartbeats,
      ## that way we can index other masterservers too
      $self->send_heartbeats();
      
      #
      # more short tasks?
      #
    },
  );
}

1;
