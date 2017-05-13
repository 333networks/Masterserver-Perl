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
  my $prev  = 0;

  return AnyEvent->timer (
    after     =>   30,  # 30 seconds grace time
    interval  => 3600,  # execute every hour
    cb        => sub {

      # update Killing Floor stats
      $self->read_kfstats() if $self->{kfstats_enabled};

      # delete old masterserver applets that have been unresponsive for a while now
      $self->remove_unresponsive_applets() if (defined $self->{firstrun});

      # time spacer
      my $t = 0;
      
      # clean out handles from the previous round (executed or not)
      $self->{scope}->{sync} = ();

      # Synchronize with all other 333networks masterservers that are uplinking,
      # added by synchronization or manually listed.
      if ($self->{sync_enabled}) {
        
        # get serverlist
        my $masterserverlist = $self->get_server(
          updated   => 3600,
          gamename  => "333networks",
        );
        
        foreach my $ms (@{$masterserverlist}) {
          # add 5 second delay to spread network/server load
          $self->{scope}->{sync}->{$t} = AnyEvent->timer(
            after => 5*$t++, 
            cb => sub{$self->sync_with_master($ms)}
          ) if ($ms->{hostport} > 0);
        }
      }

      # do NOT reset $t, keep padding time -- you should not have more than 300
      # entries in applets/syncer in total anyway.
      
      # Query Epic Games-based UCC applets periodically to get an additional
      # list of online UT, Unreal and other game servers. 
      if ($self->{master_applet_enabled}) {
        
        # get applet list
        my $appletlist = $self->get_masterserver_applets();

        for my $ms (@{$appletlist}) {

          # add 5 second delay to spread network/server load
          $self->{scope}->{sync}->{$t} = AnyEvent->timer(
            after => 5*$t++, 
            cb => sub{$self->query_applet($ms)}
          );
        }
      }
      
      #
      # very long-running tasks, like database dumps
      # interval from config
      #
      my $curr = 0;
      $curr = strftime('%d',localtime) if ($self->{dump_db} =~ /^daily$/i  );
      $curr = strftime('%U',localtime) if ($self->{dump_db} =~ /^weekly$/i );
      $curr = strftime('%m',localtime) if ($self->{dump_db} =~ /^monthly$/i);
      $curr = strftime('%Y',localtime) if ($self->{dump_db} =~ /^yearly$/i );

      # on change, execute      
      if ($prev < $curr) {
        
        # skip on first run
        if ($prev == 0) {
          # update timer and loop
          $prev = $curr;
          return;
        }
        
        # dump db
        $self->dump_database();

        # update timekeeper
        $prev = $curr;
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
      
      # update stats on direct beacons and total number of servers
      $self->update_stats();
      
      # determine whether servers are still uplinking to us. If not, toggle. 
      $self->write_direct_beacons() if (defined $self->{firstrun});
      
      # delete old servers from the "pending" list (except for the first run)
      $self->delete_old_pending() if (defined $self->{firstrun});

      # uplink to other 333networks masterservers with heartbeats, so other
      # masterservers can find us too
      $self->send_heartbeats();

    },
  );
}

1;
