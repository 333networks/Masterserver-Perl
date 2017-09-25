package MasterServer::Core::Schedulers;

use strict;
use warnings;
use AnyEvent;
use POSIX qw/strftime/;
use Exporter 'import';
use DBI;
our @EXPORT = qw | long_periodic_tasks 
                  short_periodic_tasks |;

################################################################################
## tasks that are executed only once or twice per hour
################################################################################
sub long_periodic_tasks {
  my $self = shift;
  my $prev  = 0;

  return AnyEvent->timer (
    after     =>   90, # grace time receiving beacons
    interval  => 1800,
    cb        => sub {

      # update Killing Floor stats
      $self->read_kfstats if $self->{kfstats_enabled};

      # delete old masterserver applets that have been unresponsive for a while now
      $self->remove_unresponsive_applets if (defined $self->{firstrun});

      # clean out handles from the previous round (executed or not)
      my $t = 0;
      $self->{scope}->{sync} = ();

      # Synchronize with all other 333networks masterservers that are uplinking,
      # added by synchronization or manually listed.
      if ($self->{sync_enabled}) {
        
        # get serverlist
        my $masterserverlist = $self->get_server(
          gamename  => "333networks",
          $self->{firstrun} ? (
            updated => 7200 ) : (),
        );
        
        foreach my $ms (@{$masterserverlist}) {
          # add 5 second delay to spread network/server load
          $self->{scope}->{sync}->{$t} = AnyEvent->timer(
            after => 5*$t++, 
            cb => sub{$self->synchronize($ms, "333nwm")}
          ) if ($ms->{hostport} > 0);
        }
      }

      # do NOT reset $t, keep padding time -- you should not have more than 300
      # entries in applets/syncer in total anyway.
      
      # Query Epic Games-alike applets periodically to get an additional
      # list of online UT, Unreal and other game servers. 
      if ($self->{master_applet_enabled}) {
        
        # get applet list
        my $appletlist = $self->get_masterserver_applets;

        for my $ms (@{$appletlist}) {

          # add 5 second delay to spread network/server load
          $self->{scope}->{sync}->{$t} = AnyEvent->timer(
            after => 5*$t++, 
            cb => sub{$self->synchronize($ms, "applet")}
          );
        }
      }
      
      # very long-running tasks, like database dumps.
      # interval from config
      my $curr = 0;
      $curr = strftime('%d',localtime) if ($self->{dump_db} =~ /^daily$/i  );
      $curr = strftime('%U',localtime) if ($self->{dump_db} =~ /^weekly$/i );
      $curr = strftime('%m',localtime) if ($self->{dump_db} =~ /^monthly$/i);
      $curr = strftime('%Y',localtime) if ($self->{dump_db} =~ /^yearly$/i );

      # on change, execute      
      if ($prev < $curr) {
        # skip on first run and update timer
        if ($prev == 0) { $prev = $curr; return; }
        
        # dump db and update timer
        $self->dump_database; $prev = $curr;
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
    after     => 5,
    interval  => 120,
    cb        => sub {
      # update stats on direct beacons and total number of servers
      $self->update_stats;
      
      # determine whether servers are still uplinking to us. If not, toggle. 
      $self->write_direct_beacons if (defined $self->{firstrun});
      
      # delete old servers from the "pending" list
      $self->delete_old_pending;

      # uplink to other 333networks masterservers so others can find us too
      $self->send_heartbeats;
    },
  );
}

1;
