package MasterServer::UDP::UDPTicker;

use strict;
use warnings;
use AnyEvent::Handle::UDP;
use Exporter 'import';
our @EXPORT = qw| udp_ticker |;

################################################################################
##   When addresses are provided from secondary sources (master applets, 
##   synchronization or manual addition, they are queried by this udp_ticker.
##   When they validate (which also implies correct router settings) they are
##   added to the masterserver list.
##
##   Some servers do not support the secure-challenge or do not respond to 
##   queries directly. By retrieving the server information we are able to 
##   make exceptions on a case to case basis.
##
##   Other than previous MS-Perl versions, unresponsive servers are no longer
##   checked. When servers become fail to report in after 2 hours, they remain 
##   are considered offline and will remain archived. This server can become
##   active again by uplinking to one of the affiliated masterservers.
################################################################################
sub udp_ticker {
  my $self = shift;

  # queue: start time, server id, counter, time limit
  my %p = (start => time, id => 0, c => 0, limit => 900); # pending: 15m
  my %u = (start => time, id => 0, c => 0, limit => 300); # updater:  5m

  # tick through pending list and server list
  my $server_info = AnyEvent->timer (
    after     => 120, # grace time receiving beacons
    interval  => 0.2, # ~5 servers/s
    cb        => sub {
      # reset counters if minimum time before reset passed + list processed
      if ($self->{firstrun}) {
        if ($p{c} && time - $p{start} > $p{limit}) { # pending reset
          %p = (%p, start => time, id => 0, c => 0); }
        if ($u{c} && time - $u{start} > $u{limit}) { # updater reset
          %u = (%u, start => time, id => 0, c => 0); }
      }
      
      # Check pending addresses
      if ( my $n = $self->get_pending(next_id => $p{id}, limit => 1)->[0] ) {
        $p{id} = $n->{id}; # next id will be >$n

        # assign BeaconChecker to query the server for validate, status
        $self->query_udp_server(
          ip    => $n->{ip},
          port  => $n->{heartbeat},
          need_validate => 1,
        );
        return;
      }
      $p{c}++; # all pending addresses were processed
      
      # Update server status
      if ( my $n = $self->get_server(
        next_id => $u{id}, 
        updated => 7200, # count >2h as unresponsive
        limit => 1
      )->[0] ) {
        $u{id} = $n->{id}; # next id will be >$n

        # assign BeaconChecker to query the server for status (no validate)
        $self->query_udp_server(
          ip    => $n->{ip},
          port  => $n->{port},
        );
        return;
      }    
      $u{c}++; # all servers were processed  
      
      # first run complete?
      if ($self->{firstrun}) {
        # done. no other actions required
        return;
      } else {
        # notify about first run being completed and reset
        my $t = time-$self->{firstruntime};
        my $t_readable = ($t > 60) ? (int($t/60). " minutes ". ($t%60). " seconds") : ($t. " seconds");

        $self->log("info", "first run completed after $t_readable");
        delete $self->{firstruntime};
        $self->{firstrun} = 1;
      }
      # Run complete. Count down until the minimum time has elapsed and handle
      # new server entries as they are added to the list.
    }
  );
  # allow object to exist beyond this scope. Objects have ambitions too.
  $self->log("info", "UDP ticker is loaded");
  return $server_info;
}

1;
