package MasterServer::UDP::UDPTicker;

use strict;
use warnings;
use AnyEvent::Handle::UDP;
use Exporter 'import';
use Data::Dumper 'Dumper';

our @EXPORT = qw| udp_ticker |;

################################################################################
##   When addresses are stored in the 'pending' list, they are supposed to be
##   queried immediately with the secure/validate challenge to testify that
##   the server is genuine and alive.
##
##   Some servers do not support the secure-challenge on the Uplink port. These
##   servers are verified with a secure-challenge on their heartbeat ports, 
##   which are designed to respond to secure queries, as well as status queries.
##
##   Addresses collected by other scripts, whether from the UCC applet or manual
##   input via the website, are added to the pending list. It is more 
##   important to verify pending beacons and new server addresses, than to 
##   update the status of existing addresses. Therefore, pending addresses are
##   prioritized.
##
##   Another function required for 333networks is the "server info" part of the
##   site. UT servers are queried and stored in the database. This is the lowest
##   priority for the masterserver and is therefore performed last.
##
################################################################################
sub udp_ticker {
  my $self = shift;

  # inform that we are running 
  $self->log("info", "UDP Ticker is loaded.");

  # queue -- which address is next in line?
  my %reset = (start => time, id => 0);
  my %pending = (%reset, c => 0, limit =>   900); #   900s ~ 15m
  my %updater = (%reset, c => 0, limit =>  1800); #  1800s ~ 30m
  my %ut_serv = (%reset, c => 0, limit =>   300); #   300s ~  5m
  my %oldserv = (%reset, c => 0, limit => 86400); # 86400s ~ 24h
  
  my $debug_counter = 0;
  
  # go through all servers that need querying
  my $server_info = AnyEvent->timer (
    after     => 120, # first give beacons a chance to uplink
    interval  => 0.2, # 5 addresses per second is fast enough
    cb        => sub {
      
      # after the first full run was completed, reset the counters when loop time expires
      if (defined $self->{firstrun}) {
        # reset timer
        %reset = (start => time, id => 0, c => 0);
        
        #
        # it can happen that a run takes more than the allowed time
        # in that case, allow more time
        #
        
        # pending
        if (time - $pending{start} > $pending{limit}) {
          if ($pending{c} > 0) {
            # done within defined time, reset
            %pending = (%pending, %reset);
          }
        }
        
        # ut servers
        if (time - $ut_serv{start} > $ut_serv{limit}) {
          if ($ut_serv{c} > 0) {
            # done within defined time, reset
            %ut_serv = (%ut_serv, %reset);
          }
        }

        # updater
        if (time - $updater{start} > $updater{limit}) {
          if ($updater{c} > 0) {
            # done within defined time, reset
            %updater = (%updater, %reset);
          }
        }
        
        # old servers
        if (time - $oldserv{start} > $oldserv{limit}) {
          if ($oldserv{c} > 0) {
            %oldserv = (%oldserv, %reset);
          }
        }
      }

      #
      # Check pending beacons
      #

      # pending beacons/servers (15 seconds grace time)
      my $n = $self->get_pending(
        next_id => $pending{id}, 
        added   => 15,
        sort    => "id",
        limit => 1
      )->[0] if $self->{beacon_checker_enabled};
      
      # if next pending server/address exists:
      if ( $n ) {
        # next pending id will be > $n
        $pending{id} = $n->{id};

        # query the server using the heartbeat port provided in the beacon/manual add
        $self->query_udp_server(
          $n->{id}, 
          $n->{ip}, 
          $n->{heartbeat}, 
          $n->{secure}, # secure string necessary!
          1,            # request secure challenge
        );

        # our work is done for this cycle.
        return;
      }
      
      # pending are done and is allowed to reset at a later stadium
      $pending{c}++;
      
      
      #
      # Query Unreal Tournament 99 (demo) servers for serverstats
      #
      
      # next server in line
      $n = $self->get_server(
        next_id => $ut_serv{id},
        updated => 3600,
        gamename => "ut",
        sort    => "id",
        limit   => 1,
      )->[0] if $self->{utserver_query_enabled};
      
      # if next server/address exists:
      if ( $n ) {
        #next pending id will be > $n
        $ut_serv{id} = $n->{id};

        # query the server (no secure string)
        $self->query_udp_server(
          $n->{id}, 
          $n->{ip},
          $n->{port},
          "", # no secure string necessary
          2,  # request full status info
        );

        # our work is done for this cycle.
        return;
      }
      
      # ut servers are done and is allowed to reset at a later stadium
      $ut_serv{c}++;

      #
      # update existing servers (both ut/non-ut)
      #
      
      # next server in line
      $n = $self->get_server(
        next_id => $updater{id},
        updated => 7200,
        sort    => "id",
        limit   => 1,
      )->[0] if $self->{beacon_checker_enabled};
      
      # if next server/address exists:
      if ( $n ) {
        #next pending id will be > $n
        $updater{id} = $n->{id};

        # query the server (no secure string)
        $self->query_udp_server(
          $n->{id}, 
          $n->{ip},
          $n->{port},
          "", # no secure string necessary
          0,  # request info
        );

        # our work is done for this cycle.
        return;
      }
      
      # updating servers is done and is allowed to reset at a later stadium
      $updater{c}++;
      
      #
      # Query servers older than 2 hours
      #
      
      # next server in line
      $n = $self->get_server(
        next_id => $oldserv{id},
        before => 7200,
        (defined $self->{firstrun}) ? () : (updated => 86400), # FIXME long firstrun time fixed now?
        sort    => "id",
        limit   => 1,
      )->[0] if $self->{beacon_checker_enabled};
      
      # if next server/address exists:
      if ( $n ) {
        #next old server id will be > $n
        $oldserv{id} = $n->{id};

        # query the server (no secure string)
        $self->query_udp_server(
          $n->{id}, 
          $n->{ip},
          $n->{port},
          "", # no secure string necessary
          0,  # request info
        );

        # our work is done for this cycle.
        return;
      }
      
      # old servers are done and is allowed to reset at a later stadium
      $oldserv{c}++;
      
      # and notify about first run being completed
      if (!defined $self->{firstrun}) {
        # inform that first run is completed
        my $t = time-$self->{firstruntime};
        my $t_readable = ($t > 60) ? (int($t/60). " minutes ". ($t%60). " seconds") : ($t. " seconds");
        
        $self->log("info", "First run completed after $t_readable.");
        $self->{firstrun} = 0;
        
        # reset all counters and follow procedure
        %reset = (start => time, id => 0, c => 0);
        %pending = (%pending, %reset);
        %updater = (%updater, %reset);
        %ut_serv = (%ut_serv, %reset);
        %oldserv = (%oldserv, %reset);
      }
      
      # At this point, we are out of server entries. From here on, just count 
      # down until the cycle is complete and handle new entries while they are 
      # added to the list.

    }
  );
  
  # return the timer object to keep it alive outside of this scope
  return $server_info;
}

1;
