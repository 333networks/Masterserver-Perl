package MasterServer::UDP::BeaconCatcher;

use strict;
use warnings;
use AnyEvent::Handle::UDP;
use Socket qw(sockaddr_in inet_ntoa);
use Exporter 'import';
our @EXPORT = qw| beacon_catcher recv_beacon |;

################################################################################
## Receive UDP beacons with \heartbeat\7778\gamename\ut\ format 
## where "ut" is the game name and 7778 the query port of the server.
################################################################################
sub beacon_catcher {
  my $self = shift;
  # UDP server
  my $udp_server; $udp_server = AnyEvent::Handle::UDP->new(
    bind => ['0.0.0.0', $self->{beacon_port}],
    on_recv => sub {$self->recv_beacon(@_)},
  );
  $self->log("info", "listening for UDP beacons on port $self->{beacon_port}");
  return $udp_server;
}

################################################################################
# Receive Beacon (Spellchecker suggestion: "Bacon")
# Check for heartbeats, determine if the server is already in the database
# or trigger challenge with secure/validate if necessary.
################################################################################
sub recv_beacon {
  # $self, received data, handle, packed client address
  my ($self, $buffer, $handle, $paddress) = @_;

  # unpack ip from packed client address
  my ($port, $iaddr) = sockaddr_in($paddress);
  my $beacon_address = inet_ntoa($iaddr);
  
  # ignore localhost and restricted IPs like localhost
  return unless $self->valid_address($beacon_address, $port);

  # determine and process heartbeat
  if ($buffer =~ m/\\heartbeat\\/) {
  
    # process data and get gamename info from the database
    my $rx = $self->data2hashref($buffer);
    
    # some games use heartbeat = 0 because of default ports. Check.
    if ($rx->{heartbeat} == 0 && $rx->{gamename}) {
    
      # overwrite the heartbeat port with a known default port, or zero
      $rx->{heartbeat} = $self->get_game_props(gamename => $rx->{gamename})->[0]->{default_qport} || 0;
      
      # if no default port is listed, log and return. !! can spam the logs !!
      if ($rx->{heartbeat} == 0) {
        $self->log("invalid", "$beacon_address has no default heartbeat port listed");
        return;
      }
    }

    # update the timestamp in the database if the server already exists
    my $upd = $self->update_server(
      ip        => $beacon_address, 
      port      => $rx->{heartbeat}, 
      direct    => 1,
    );
    
    # did the update succeed?
    if ($upd > 0) {
      # then we're done here. log and return.
      $self->log("beacon", "heartbeat from $beacon_address, $rx->{heartbeat}". 
        ($rx->{gamename} ? (" for $rx->{gamename}") : "") );
    } 
    # if no update occurred, query server
    else {
      # assign BeaconChecker to query the server for secure challenge and status
      $self->query_udp_server(
        ip    => $beacon_address,
        port  => $rx->{heartbeat},
        need_validate => 1,
        direct_uplink => 1,
      );
    }
    return;
  }

  # other masterservers check if we're still alive, respond with complient data
  if ($buffer =~ m/\\(secure|basic|rules|info|players|status)\\/i) {
    $self->handle_status_query($handle, $paddress, $buffer);
    $self->log("uplink", "responding to $beacon_address, $port (sent $buffer)");
    return;
  }
  
  # Util::UDPBrowser (optional)
  if ($buffer =~ m/^\\echo\\request/i) {
    $self->udpbrowser_host($handle, $paddress, $buffer);
    return;
  }

}

1;
