package MasterServer::UDP::BeaconCatcher;

use strict;
use warnings;
use AnyEvent::Handle::UDP;
use Socket qw(sockaddr_in inet_ntoa);
use Exporter 'import';

our @EXPORT = qw| beacon_catcher on_beacon_receive|;

################################################################################
## Receive UDP beacons with \heartbeat\7778\gamename\ut\ format 
## where "ut" is the game name and 7778 the query port of the server.
################################################################################
sub beacon_catcher {
  my $self = shift;
  
  # display that the server is up and listening for beacons
  $self->log("info", "Listening for UDP beacons on port $self->{beacon_port}.");
  
  # UDP server
  my $udp_server; 
     $udp_server = AnyEvent::Handle::UDP->new(
  
    # Bind to this host and use the port specified in the config file
    bind => ['0.0.0.0', $self->{beacon_port}],
  
    # when datagrams are received
    on_recv => sub {$self->on_beacon_receive(@_)},
  );
  
  # allow object to exist beyond this scope. Objects have ambitions too.
  return $udp_server;
}

################################################################################
## Determine the content of the received information and process it.
################################################################################
sub on_beacon_receive {
  # $self, beacon address, handle, packed client address
  my ($self, $b, $udp, $pa) = @_; 

  # unpack ip from packed client address
  my ($port, $iaddr) = sockaddr_in($pa);
  my $peer_addr      = inet_ntoa($iaddr);
  
  # assume fraud/crash attempt if response too long
  if (length $b > 64) {
    # log
    $self->log("attack","length exceeded in beacon: $peer_addr:$port sent $b");
    
    # truncate and try to continue
    $b = substr $b, 0, 64;
  }

  # FIXME: note to self: order is important when having combined queries!
  # TODO:  find a more elegant and long-time solution for this.

  # if this is a secure response, verify the response
  $self->process_udp_validate($b, $peer_addr, $port, undef) 
    if ($b =~ m/\\validate\\/);

  # if a heartbeat format was detected...
  $self->process_udp_beacon($udp, $pa, $b, $peer_addr, $port) 
    if ($b =~ m/\\heartbeat\\/ && $b =~ m/\\gamename\\/);
  
  # if other masterservers check if we're still alive
  $self->process_udp_secure($udp, $pa, $b, $peer_addr) 
    if ($b =~ m/\\secure\\/ || $b =~ m/\\basic\\/ || $b =~ m/\\status\\/ || $b =~ m/\\info\\/);
}

1;
