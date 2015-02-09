
package MasterServer::UDP::BeaconCatcher;

use strict;
use warnings;
use AnyEvent::Handle::UDP;
use Socket qw(sockaddr_in inet_ntoa);
use Exporter 'import';

our @EXPORT = qw| beacon_catcher on_beacon_receive|;

##
## Receive UDP beacons according the \heartbeat\7778\gamename\ut\ format 
## where "ut" depicts the game and 7778 the query port of the game.
sub beacon_catcher {
  my $self = shift;
  
  # module startup log
  $self->log("loader","Loading UDP Beacon Catcher.");
  
  # UDP server
  my $udp_server; 
     $udp_server = AnyEvent::Handle::UDP->new(
  
    # Bind to this host and use the port specified in the config file
    bind => ['0.0.0.0', $self->{beacon_port}],
  
    # when datagrams are received
    on_recv => sub {$self->on_beacon_receive(@_)},
  );
  
  # display that the server is up and listening for beacons
  $self->log("ok", "Listening for UT Beacons on port $self->{beacon_port}.");
  
  # allow object to exist beyond this scope. Objects have ambitions too.
  return $udp_server;
}

## process (new) beacons
sub on_beacon_receive {
  # $self, beacon address, handle, packed client address
  my ($self, $b, $udp, $pa) = @_; 

  # unpack ip from packed client address
  my ($port, $iaddr) = sockaddr_in($pa);
  my $peer_addr      = inet_ntoa($iaddr);
  
  # if the beacon has a length longer than a certain amount, assume it is
  # a fraud or crash attempt
  if (length $b > 64) {
    # log
    $self->log("attack","length exceeded in beacon: $peer_addr:$port sent $b");
    
    # truncate and try to continue
    $b = substr $b, 0, 64;
  }
  
  # if a heartbeat format was detected...
  $self->process_udp_beacon($udp, $pa, $b, $peer_addr, $port) 
    if ($b =~ m/\\heartbeat\\/ && $b =~ m/\\gamename\\/);
  
  # or if this is a secure response, verify the response code and add mark it verified
  $self->process_udp_validate($b, $peer_addr, $port, undef) 
    if ($b =~ m/\\validate\\/);
}

1;
