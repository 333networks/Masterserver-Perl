
package MasterServer::UDP::BeaconChecker;

use strict;
use warnings;
use AnyEvent::Handle::UDP;
use Exporter 'import';

our @EXPORT = qw| query_udp_server|;

################################################################################
## Get the server status from any server over UDP and store the received 
## information in the database. $secure determines the type of query: 
## secure/pending or information.
################################################################################
sub query_udp_server {
  my ($self, $id, $ip, $port, $secure, $message_type) = @_;
  my $buf = "";
  
  # debug spamming
  $self->log("udp", "Query server $id ($ip:$port)");
  
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
      
      # message type 0: \basic\\info\
      # if gamename, ver, hostname and hostport are available, but NOT the value 
      # "listenserver", it would have been \basic\info
      if ($buf =~ m/\\gamename\\/ && 
          $buf =~ m/\\hostname\\/ && 
          $buf =~ m/\\hostport\\/ &&
          $buf !~ m/\\listenserver\\/ ) {
        $self->process_query_response($buf, $ip, $port);
      }
      
      # message type 1: \basic\\secure\wookie
      # if validate, assume that we sent a \basic\secure request.
      if ($buf =~ m/\\validate\\/){
        $self->process_udp_validate($buf, $ip, undef, $port);
      }
      
      # message type 2: \status\
      # contains same info as \basic\\info, but also "listenserver". Only for UT.
      if ($buf =~ m/\\gamename\\ut/ && 
          $buf =~ m/\\hostname\\/   && 
          $buf =~ m/\\hostport\\/   &&
          $buf =~ m/\\listenserver\\/ ) {
        $self->process_status_response($buf, $ip, $port);
      }

      # else partial information received. wait for more.
      # else { }
    },
  );

  #
  # Send secure message or status, depending on provided variables
  # Message types can be 
  #   0: \basic\\info\
  #   1: \basic\\secure\wookie
  #   2: \status\
  #
  
  # determine the message
  my $message = "\\basic\\\\info\\"; # default 0
     $message = "\\basic\\\\secure\\$secure" if ($secure ne "" && $self->{require_secure_beacons} > 0); # message_type 1
     $message = "\\status\\" if ($message_type == 2);

  # send selected message
  $udp_client->push_send($message);
}

1;
