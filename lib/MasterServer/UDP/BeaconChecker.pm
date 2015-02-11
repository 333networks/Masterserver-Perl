
package MasterServer::UDP::BeaconChecker;

use strict;
use warnings;
use AnyEvent::Handle::UDP;
use Exporter 'import';

our @EXPORT = qw| beacon_checker query_udp_server|;

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
################################################################################
sub beacon_checker {
  my $self = shift;
  $self->log("load", "UDP Beacon Checker is loaded.");

  # queue -- which address is next in line?
  my %q = ( pending_id => 0, server_id => 0,
            start_time => time+$self->{beacon_checker_time}[0]-1); #time+grace

  # go through all servers one by one, new and old
  my $server_info = AnyEvent->timer (
    after     => $self->{beacon_checker_time}[0],
    interval  => $self->{beacon_checker_time}[1],
    cb        => sub {
        
        # first of all, check whether we exceeded our time cap limit
        if ( (time - $q{start_time}) >= $self->{beacon_checker_time}[2] ){
          # reset queue variables          
          $q{pending_id} = 0;
          $q{server_id}  = 0;
          $q{start_time} = time;
        }
        
        # See if there are pending servers, and use existing secure string for
        # the challenge.
        my $n = $self->get_next_pending($q{pending_id});
        
        # if any entries were found, proceed
        if ( $n->[0] ) {
          
          # next pending id will be > $n
          $q{pending_id} = $n->[0];
          
          # query the server
          $self->query_udp_server($n->[1], $n->[2], $n->[3]);
          
          # work done. Wait for the next round for the next timer tick.
          return;
        }
        
        # if no pending servers left, update the other entries
        $n = $self->get_next_server($q{server_id});  
        
        # if any entries were found, proceed
        if ( $n->[0] ) {

          # next server id will be > $n
          $q{server_id} = $n->[0];
          
          # query the server (no secure string)
          $self->query_udp_server($n->[1], $n->[2], "");
          
          # work done. Wait for the next round for the next task.
          return;
        }
        
        # At this point, we are out of server entries. When new servers are 
        # added, they are immediately queried on the next round.
        # From here on, just count down until the cycle is complete.

        # debug (spams badly)
        $self->log("debug_spam", "Checker timer: t=".(time - $q{start_time}));
    }
  );
  
  # at the start of the module, remind host how often this happens
  $self->log("info", "Verifying servers every $self->{beacon_checker_time}[2] seconds.");
  
  # return the timer object to keep it alive outside of this scope
  return $server_info;
}


################################################################################
## Get the server status from any server over UDP and store the received 
## information in the database. $secure determines the type of query: 
## secure/pending or information.
################################################################################
sub query_udp_server {
  my ($self, $ip, $port, $secure) = @_;
  my $buf = "";
  
  # debug spamming
  $self->log("debug_spam", "Query server $ip:$port");
  
  # connect with UDP server
  my $udp_client; $udp_client = AnyEvent::Handle::UDP->new(
    # Bind to this host and port
    connect   => [$ip, $port],
    timeout   => 1,
    on_timeout => sub {$udp_client->destroy();}, # don't bother reporting timeouts
    on_error   => sub {$udp_client->destroy();}, # or errors
    on_recv   => sub {

      # add packet to buffer
      $buf .= $_[0];
      
      # if validate, assume that we sent a \basic\secure request.
      if ($buf =~ m/\\validate\\/){
        $self->process_udp_validate($buf, $ip, undef, $port);
      }
      # if gamename, ver, hostname and hostport are available, it should 
      # have been \basic\info
      elsif ($buf =~ m/\\gamename\\/ && $buf =~ m/\\gamever\\/ 
          && $buf =~ m/\\hostname\\/ && $buf =~ m/\\hostport\\/) {
        $self->process_query_response($buf, $ip, $port);
      }
      # else partial information received. wait for more.
      else{ }
    },
  );

  #
  # Send secure message or status, depending on provided variables
  #  
  
  # secure servers enabled and secure key provided
  if ($secure ne "" && $self->{require_secure_beacons} > 0) {
    # send secure
    $udp_client->push_send("\\basic\\\\secure\\$secure");
    
    # and log that we sent it
    $self->log("udp", "sending secure=\"$secure\" to $ip:$port");
  }
  else {
    # send information request
    $udp_client->push_send("\\basic\\\\info\\");  
    
    # and log that we sent it
    $self->log("udp","sending basic request to $ip:$port");
  }
}

1;
