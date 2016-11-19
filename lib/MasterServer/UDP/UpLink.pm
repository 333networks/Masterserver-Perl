package MasterServer::UDP::UpLink;

use strict;
use warnings;
use Encode;
use AnyEvent::Handle::UDP;
use Socket qw(sockaddr_in inet_ntoa);
use Exporter 'import';

our @EXPORT = qw| send_heartbeats 
                  do_uplink 
                  process_uplink_response
                  process_udp_secure 
                  process_udp_basic |;

################################################################################
## Broadcast heartbeats to other masterservers
##
################################################################################
sub send_heartbeats {
  my $self = shift;

  # in order to be permitted to sync, you need to share your address too so
  # others can sync from you too. 
  if ($self->{sync_enabled}) {

    # uplink to every entry of the masterserver brotherhood list
    foreach my $uplink (values %{$self->masterserver_list()}) {
      # send uplink
      $self->do_uplink($uplink->{ip}, $uplink->{udp});
    }
  }
}


################################################################################
## Do an uplink to other 333networks-based masterservers so we can be shared
## along the 333networks synchronization protocol. Other 333networks-based
## masterservers are shared in this way too.
################################################################################
sub do_uplink {
  my ($self, $ip, $port) = @_;
  
  # do not proceed if not all information is available
  return unless (defined $ip && defined $port && $port > 0);
  
  # debug spamming
  $self->log("uplink", "Uplink to Masterserver $ip:$port");
  
  # connect with UDP server
  my $udp_client; $udp_client = AnyEvent::Handle::UDP->new(
    # Bind to this host and port
    connect     => [$ip, $port],
    timeout     => 5,
    on_timeout  => sub {$udp_client->destroy();}, # don't bother reporting timeouts
    on_error    => sub {$udp_client->destroy();}, # or errors
    on_recv     => sub {$self->process_uplink_response(@_)},
  );

  # Send heardbeat
  $udp_client->push_send("\\heartbeat\\$self->{beacon_port}\\gamename\\333networks");
}

################################################################################
## Process requests received after uplinking
##
################################################################################
sub process_uplink_response {
  # $self, beacon address, handle, packed client address
  my ($self, $b, $udp, $pa) = @_; 
  
  # unpack ip from packed client address
  my ($port, $iaddr) = sockaddr_in($pa);
  my $peer_addr      = inet_ntoa($iaddr);
  
  # if the beacon has a length longer than a certain amount, assume it is
  # a fraud or crash attempt
  if (length $b > 64) {
    # log
    $self->log("attack","length exceeded in uplink response: $peer_addr:$port sent $b");
    
    # truncate and try to continue
    $b = substr $b, 0, 64;
  }

  # check if this is a secure challenge
  $self->process_udp_secure($udp, $pa, $b, $peer_addr) 
    if ($b =~ m/\\secure\\/);
}


################################################################################
## Process the received secure query and respond with the correct response
##
################################################################################
sub process_udp_secure {
  # $self, handle, packed address, udp data, peer ip address, $port
  my ($self, $udp, $pa, $buf, $peer_addr) = @_; 
  
  # received secure in $buf: \basic\secure\l8jfVy
  my %r;
  my $raw = $buf; # raw buffer for logging if necessary
  $buf = encode('UTF-8', $buf);
  $buf =~ s/\\\\/\\undef\\/;
  $buf =~ s/\n//;
  $buf =~ s/\\([^\\]+)\\([^\\]+)/$r{$1}=$2/eg;

  # scope
  my $response = "";
  
  # provide basic information if asked for (not uncommon)
  if (defined $r{basic}) {
    # compile basic string (identical to process_udp_basic)
    
    # format: \gamename\ut\gamever\348\minnetver\348\location\0\final\\queryid\16.1
    $response .= "\\gamename\\333networks"
              .  "\\gamever\\$self->{short_version}"
              .  "\\location\\0"
              .  "\\hostname\\$self->{masterserver_hostname}"
              .  "\\hostport\\$self->{listen_port}";
  }

  # we only respond with gamename = 333networks
  if (defined $r{secure}) {
    # get response
    $response .= "\\validate\\"
              .  $self->validate_string(gamename => "333networks",
                                        enctype  => 0,
                                        secure   => $r{secure});
  }
  
  # send the response to the \basic\\secure\wookie query
  $udp->push_send("$response\\final\\", $pa);
}

################################################################################
## Respond to basic or status queries
## TODO: abstract function for this -- otherwise these functions pile up.
################################################################################
sub process_udp_basic {
  # $self, handle, packed address, udp data, peer ip address, $port
  my ($self, $udp, $pa, $buf, $peer_addr) = @_; 

  # received basic or status in $buf: \basic\ or \status\
  my %r;
  $buf = encode('UTF-8', $buf);
  $buf =~ s/\\\\/\\undef\\/;
  $buf =~ s/\n//;
  $buf =~ s/\\([^\\]+)\\([^\\]+)/$r{$1}=$2/eg;
  
  # scope
  my $basic = "";
  # provide basic information
  
  if (defined $r{basic} || defined $r{status} || defined $r{info}) {
    # compile basic string (identical to process_udp_basic)
    
    # format: \gamename\ut\gamever\348\minnetver\348\location\0\final\\queryid\16.1
    $basic = "\\gamename\\333networks"
           . "\\gamever\\$self->{short_version}"
           . "\\location\\0"
           . "\\hostname\\$self->{masterserver_hostname}"
           . "\\hostport\\$self->{listen_port}";
  }
  
  # send the response to the \basic\ or \status\
  $udp->push_send("$basic\\final\\", $pa);
}
1;
