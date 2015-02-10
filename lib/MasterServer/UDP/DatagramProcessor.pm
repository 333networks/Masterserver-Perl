
package MasterServer::UDP::DatagramProcessor;

use strict;
use warnings;
use Encode;
use AnyEvent::Handle::UDP;
use Exporter 'import';

our @EXPORT = qw| process_udp_beacon process_udp_validate process_query_response |;


## process beacons that have a \heartbeat\ and \gamename\ format
sub process_udp_beacon {
  # $self, handle, packed address, udp data, peer ip address, $port
  my ($self, $udp, $pa, $buf, $peer_addr, $port) = @_; 
  
  # received heartbeat in $buf: \heartbeat\7778\gamename\ut\ 
  my %r;
  $buf = encode('UTF-8', $buf);
  $buf =~ s/\\([^\\]+)\\([^\\]+)/$r{$1}=$2/eg;
  
  # check whether the beacon has a gamename that is supported in our list
  if (defined $r{gamename} && exists $self->{game}->{lc $r{gamename}}) {
    # log the beacon
    $self->log("beacon", "$peer_addr:$r{heartbeat} for $r{gamename}");
    
    # some games (like bcommander) have a default port and don't send a
    # heartbeat port.
    if ($r{heartbeat} == 0) {
      # assuming a default port exists
      if (exists $self->{game}->{lc $r{gamename}}->{port}) {
        $r{heartbeat} = $self->{game}->{lc $r{gamename}}->{port};
      }
    }
    
    #
    # verify valid server address (ip+port)
    if ($self->valid_address($peer_addr,$r{heartbeat})) {
      
      # generate a new secure string
      my $secure = $self->secure_string();
      
      # update beacon in serverlist if it already exists, otherwise update
      # or add to pending with new secure string.
      my $auth = $self->add_beacon($peer_addr, $port, $r{heartbeat}, $r{gamename}, $secure);
      
      # send secure string back
      if ($auth > 0) {
        
        # verify that this is a legitimate client by sending the "secure" query
        $udp->push_send("\\secure\\$secure\\final\\", $pa);
          
          # log this as a new beacon
          $self->log("secure", "challenged new beacon $peer_addr:$port with $secure.");
        }
    }
    
    # invalid ip+port combination, like \heartbeat\0\ or local IP
    else {
      # Log that beacon had incorrect information, such as port 0 or so. Spams log!
      $self->log("invalid","$peer_addr:$r{heartbeat} ($r{heartbeat}) had bad information");
    }
  }
  
  # gamename not valid or not found in supportedgames.pl
  else {
    # log
    $self->log("support", "received unknown beacon \"$r{gamename}\" from $peer_addr:$r{heartbeat}");
  }
}


## process the received validate query and determine whether the server is allowed in our database
sub process_udp_validate {
  # $self, udp data, ip, port
  my ($self, $buf, $peer_addr, $port, $heartbeat) = @_;
  
  # received heartbeat in $b:    \validate\string\queryid\99.9\ 
  my %r;
  $buf = encode('UTF-8', $buf);
  $buf =~ s/\\([^\\]+)\\([^\\]+)/$r{$1}=$2/eg;
  
  # get our existing knowledge about this server from the database 
  # if the heartbeat/queryport known? then use that instead as beacon ports --> may vary after server restarts!
  my $pending = (defined $heartbeat) ? $self->get_pending_info($peer_addr, $heartbeat) : $self->get_pending_beacon($peer_addr, $port);
  
  # if indeed in the pending list, check -- if this entry is not (longer) in the list, it
  # was either removed by the BeaconChecker or cleaned out in maintenance (after X hours).
  if (defined $pending) {
    
    #determine if it uses any enctype
    my $enc = (defined $r{enctype}) ? $r{enctype} : 0;
    
    # database may not contain the correct gamename (ucc applet, incomplete beacon, change of gameserver)
    $pending->[4] = (defined $r{gamename} && exists $self->{game}->{lc $r{gamename}}) ? $r{gamename} : $pending->[4];

    # verify    challenge          gamename       secure         enctype validate_response
    my $val = $self->validated_beacon($pending->[4], $pending->[5], $enc,   $r{validate});
    
    # log challenge results (compensate if $port was not provided)
    $port = (defined $port) ? $port : $heartbeat;
    $self->log("secure", "$peer_addr:$port validated with $val for $pending->[4]");

    # if validated, add to db          
    if ($val > 0) {
      
      # successfully added?             ip,            query port,    gamename
      my $sa = $self->add_to_serverlist($pending->[1], $pending->[3], $pending->[4]);
      
      # remove the entry from pending if successfully added
      $self->remove_pending($pending->[0]) if ( $sa >= 0);
      
      # and set as direct beacon
      $self->set_direct_beacon($pending->[1], $pending->[3]);
    }
    else {
      # else failed validation            
      $self->log("error","beacon $peer_addr:$port failed validation for $pending->[4] (details: $pending->[5] sent, got $r{validate})");
    }
  }
}

## process query data that was obtained with \basic\ and/or \info\
sub process_query_response {
  # $self, udp data, ip, port
  my ($self, $buf, $ip, $port) = @_;

  #process datastream
  my %s;
  $buf = encode('UTF-8', $buf);
  $buf =~ s/\\([^\\]+)\\([^\\]+)/$s{$1}=$2/eg;
  
  # check whether the gamename is supported in our db
  if (defined $s{gamename} && exists $self->{game}->{lc $s{gamename}}) {
  
    # parse variables
    my %nfo = ();
    
    $nfo{gamename}  = lc $s{gamename}; 
    $nfo{gamever}   = exists $s{gamever}  ? $s{gamever}   : "";
    $nfo{hostname}  = exists $s{hostname} ? $s{hostname}  : "$ip:$port";
    $nfo{hostport}  = exists $s{hostport} ? $s{hostport}  : 0;
    
    # some mor0ns have values longer than 100 characters
    $nfo{hostname} = substr $nfo{hostname}, 0, 99 if (length $nfo{hostname} >= 99);
    
    # log results
    $self->log("hostname", "$ip:$port\t is now known as\t $nfo{hostname}");
    
    # if only validated servers are allowed in the list
    if ($self->{require_secure_beacons} > 0) {
      # only update in database
      $self->update_serverlist($ip, $port, \%nfo);
    }
    # otherwise also add the server to serverlist if required
    else{
      # add to serverlist and update anyway
      $self->add_to_serverlist($ip, $port, $nfo{gamename});
      $self->update_serverlist($ip, $port, \%nfo);
      
      # if address is in pending list, remove it
      my $pending = $self->get_pending_info($ip, $port);
      $self->remove_pending($pending->[0]) if $pending;
    }
  }
}

1;
