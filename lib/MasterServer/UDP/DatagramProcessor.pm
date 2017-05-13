package MasterServer::UDP::DatagramProcessor;

use strict;
use warnings;
use Encode;
use AnyEvent::Handle::UDP;
use Exporter 'import';

our @EXPORT = qw| process_udp_beacon 
                  process_udp_validate 
                  process_query_response 
                  process_status_response
                  process_ucc_applet_query |;

################################################################################
## Process datagrams from beacons that have \heartbeat\ and \gamename\ keys
## in the stringbuffer. If necessary, authenticate first with the secure/val
## challenge.
################################################################################
sub process_udp_beacon {
  # $self, handle, packed address, udp data, peer ip address, $port
  my ($self, $udp, $pa, $buf, $peer_addr, $port) = @_; 
  
  # received heartbeat in $buf: \heartbeat\7778\gamename\ut\ 
  my %r;
  my $raw = $buf; # raw buffer for logging if necessary
  $buf = encode('UTF-8', $buf);
  $buf =~ s/\\([^\\]+)\\([^\\]+)/$r{$1}=$2/eg;
  

  # check whether the beacon has a gamename
  if (defined $r{gamename}) {
    # log the beacon
    $self->log("beacon", "$peer_addr:$r{heartbeat} for $r{gamename}");
    
    # check if game is actually supported in our db
    my $game_props = $self->get_game_props($r{gamename});
    
    # if no entry exists, report error.
    if (defined $game_props) {
      
      # validate heartbeat data
      my $heartbeat = ($r{heartbeat} || $game_props->{default_qport});
      
      #
      # verify valid server address (ip+port)
      if ($self->valid_address($peer_addr,$heartbeat)) {
      
        # check if the entry already was not added within the last 5 seconds, throttle otherwise
        my $throttle = $self->get_pending(
          ip        => $peer_addr, 
          heartbeat => $heartbeat, 
          gamename  => $r{gamename},
          after     => 5,
          sort      => "added",
          limit     => 1
        )->[0];
        return if (defined $throttle);
        
        # generate a new secure string
        my $secure = $self->secure_string();
        
        # update beacon in serverlist if it already exists, otherwise update
        # or add to pending with new secure string.
        my $auth = $self->add_server_new(ip         => $peer_addr, 
                                         beaconport => $port, 
                                         heartbeat  => $heartbeat, 
                                         gamename   => $r{gamename}, 
                                         secure     => $secure,
                                         direct     => 1,
                                         updated    => time,
                                         beacon     => time);

        # send secure string back
        if ($auth > 0) {
          
          # verify that this is a legitimate client by sending the "secure" query
          $udp->push_send("\\secure\\$secure\\final\\", $pa);
            
          # log this as a new beacon (debug)
          #$self->log("secure", "challenged new beacon $peer_addr:$port with $secure.");
          }
      }
      
      # invalid ip+port combination, like \heartbeat\0\ or local IP
      else {
        # Log that beacon had incorrect information, such as port 0 or so. Spams log!
        $self->log("invalid","$peer_addr had bad information --> $raw");
      }
    
    }
    # unknown game
    else {
      $self->log("support","$peer_addr tries to identify as unknown game \"$r{gamename}\".");
    }
    
  }
  
  # gamename not valid or recognized, display raw buffer in case data could not 
  # be extrapolated from the heartbeat
  else {
    # log
    $self->log("support", "received unknown beacon from $peer_addr --> '$raw'");
  }
}

################################################################################
## Process the received validate query and determine whether the server is 
## allowed in our database. Either provide heartbeat OR port, not both.
################################################################################
sub process_udp_validate {
  # $self, udp data, ip, port
  my ($self, $buf, $peer_addr, $port, $heartbeat) = @_;
  
  # debug spamming
  # $self->log("udp", "Received response from $peer_addr:$heartbeat, sent |$buf|");
  
  # received heartbeat in $b:    \validate\string\queryid\99.9\ 
  my %r;
  $buf = encode('UTF-8', $buf);
  $buf =~ s/\\([^\\]+)\\([^\\]+)/$r{$1}=$2/eg;
  
  # get our existing knowledge about this server from the database 
  my $pending = $self->get_pending(
        ip          => $peer_addr, 
        limit       => 1,
        ($heartbeat ? (heartbeat   =>  $heartbeat) : () ),
        ($port      ? (beaconport  =>  $port)      : () ),
  )->[0];
  
  # if indeed in the pending list, check; -- if this entry is not (longer) in the list, it
  # was either removed by the BeaconChecker or cleaned out in maintenance (after X hours).
  if (defined $pending) {
    
    # determine if it uses any enctype
    my $enc = (defined $r{enctype}) ? $r{enctype} : 0;
    
    # database may not contain the correct gamename (ucc applet, incomplete beacon, other game)
    $pending->{gamename} = $r{gamename} if (defined $r{gamename});

    # verify challenge
    my $val = $self->compare_challenge(
                gamename => $pending->{gamename},
                secure   => $pending->{secure},
                enctype  => $r{enctype},
                validate => $r{validate},
                ignore   => $self->{ignore_beacon_key},
              );

    # if validated, add server to database
    if ($val > 0 || $self->{require_secure_beacons} == 0) {
      
      # select server from serverlist -- should not exist yet.
      my $srv = $self->get_server(ip => $pending->{ip}, port => $pending->{heartbeat})->[0];
      
      # was found, then update gamename and remove from pending
      if (defined $srv) {
        my $sa = $self->update_server_list(
           ip       => $pending->{ip}, 
           port     => $pending->{heartbeat},
           gamename => $pending->{gamename}
        );
        # remove the entry from pending if successfully added
        $self->remove_pending($pending->{id}) if ( $sa >= 0);
      }
      # was not found in serverlist, insert clean and remove from pending
      else {
        my $sa = $self->add_server_list(
           ip       => $pending->{ip}, 
           port     => $pending->{heartbeat},
           gamename => $pending->{gamename}
        );
        # remove the entry from pending if successfully added
        $self->remove_pending($pending->{id}) if ( $sa > 0);
      }
    }
    else {
      # else failed validation
      # calculate expected result for log
      
      my $validate_string = "";
      if ($pending->{gamename} && $pending->{secure}) {
        $validate_string = $self->validate_string(
          gamename => $pending->{gamename}, 
          secure => $pending->{secure}
        );
      }
      $self->log("secure","$pending->{id} for ". 
                          ($pending->{gamename} || "empty_p_gamename")
        ." sent: '".      ($pending->{secure}   || "empty_p_secure")
        ."', expected '". ($validate_string     || "empty_v_string")
        ."', got '".      ($r{validate}         || "empty_r_validate")
        ."'"
      );
    }
  }
  # if no entry found in pending list
  else {
    # not found
    $self->log("error","server not found in pending for ".
      ($peer_addr || "ip") .":".
      ($heartbeat || "0")  .",".
      ($port      || "0")  ." !");
  }
}

################################################################################
## Process query data that was obtained with \basic\ and/or \info\ from the
## beacon checker module.
## FIXME: error checking and data processing. ($_ || "default") instead.
################################################################################
sub process_query_response {
  # $self, udp data, ip, port
  my ($self, $buf, $ip, $port) = @_;

  # process datastream
  my %s = ();
  $buf = encode('UTF-8', $buf);
  $buf =~ s/\\([^\\]+)\\([^\\]+)/$s{$1}=$2/eg;
  
  
  
  # check whether the gamename is supported in our db
  if (exists $s{gamename} && $self->get_game_props($s{gamename})) {
  
    # parse variables
    my %nfo = ();
    $nfo{gamever}   = exists $s{gamever}  ? $s{gamever}   : "";
    $nfo{hostname}  = exists $s{hostname} ? $s{hostname}  : "$ip:$port";
    $nfo{hostport}  = exists $s{hostport} ? $s{hostport}  : 0;
    
    # some mor0ns have hostnames longer than 200 characters
    $nfo{hostname} = substr $nfo{hostname}, 0, 199 if (length $nfo{hostname} >= 199);
    
    # log results (debug)
    # $self->log("hostname", "$ip:$port is now known as $nfo{hostname}");
    
    # add or update in serverlist (assuming validation is complete)
    my $result = $self->update_server_list(
        ip          => $ip, 
        port        => $port, 
        gamename    => $s{gamename},
        %nfo);

    # if address is in pending list, remove it
    my $pen = $self->get_pending(ip => $ip, heartbeat => $port)->[0];
    $self->remove_pending($pen->{id}) if $pen;
    
    # log potential error
    $self->log("support", "no entries were updated for $ip:$port ($s{gamename}), but it was still removed from pending!") if ($result == 0 && $pen);
  }
}

################################################################################
## Process status data that was obtained with \status\ from the
## UT serverstats checker module.
################################################################################
sub process_status_response {
  # $self, udp data, ip, port
  my ($self, $buf, $ip, $port) = @_;

  # process datastream
  my %s;
  $buf = encode('UTF-8', $buf);
  $buf =~ s/\\([^\\]+)\\([^\\]+)/$s{$1}=$2/eg;
  
  # check whether this server is in our database
  my $serverlist_id = $self->get_server(ip => $ip, port => $port)->[0];
  
  # only allow servers that were approved/past pending
  if (defined $serverlist_id) {

    #
    # pre-process variables before putting them in the db
    #
    
    # gamename should in all cases be "ut" (we only allow this for UT games at the moment!)
    return if (!defined $s{gamename} || $s{gamename} ne "ut");
    
    # some people trying to sneak their Unreal servers into the UT serverlist
    return if (!defined $s{gamever} || $s{gamever} eq "227i");
    
    # some sanity checks for the presentation
    $s{hostname} = substr $s{hostname}, 0, 199 if ($s{hostname} && length $s{hostname} >= 199);
    $s{mapname}  = substr $s{mapname},  0,  99 if ($s{mapname}  && length $s{mapname}  >= 99);
    $s{maptitle} = substr $s{maptitle}, 0,  99 if ($s{maptitle} && length $s{maptitle} >= 99);

    #
    # Store info in database
    #

    # check if the ID already exists in the database
    my $utserver_id = $self->get_utserver(id => $serverlist_id->{id})->[0];
    
    # add and/or update
    $self->add_utserver($ip, $port) if (not defined $utserver_id);
    $self->update_utserver($serverlist_id->{id}, %s);
    
    #
    # Player info
    #
    
    # delete all players for this server.
    $self->delete_utplayers($serverlist_id->{id});
    
    # iterate through all player IDs and add them to the database
    for (my $i = 0; exists $s{"player_$i"}; $i++) {
      
      # shorten name (some people might be overcompensating their names)
      $s{"player_$i"} = substr $s{"player_$i"}, 0, 39 if (length $s{"player_$i"} > 39);
      
      my %player = ();
      $player{player}   = exists $s{"player_$i"}   ?     $s{"player_$i"}     : "Player";
      $player{team}     = exists $s{"team_$i"}     ?     $s{"team_$i"}     : 255;
      $player{team}     = ($player{team} =~ m/^[0-3]/ ) ? int($player{team}) : 255;
      $player{frags}    = exists $s{"frags_$i"}    ? int($s{"frags_$i"})   : 0;
      $player{mesh}     = exists $s{"mesh_$i"}     ?     $s{"mesh_$i"}     : "";
      $player{skin}     = exists $s{"skin_$i"}     ?     $s{"skin_$i"}     : "";
      $player{face}     = exists $s{"face_$i"}     ?     $s{"face_$i"}     : "";
      $player{ping}     = exists $s{"ping_$i"}     ? int($s{"ping_$i"})    : 0;
      $player{ngsecret} = exists $s{"ngsecret_$i"} ?     $s{"ngsecret_$i"} : ""; # contains bot info
      
      # write to db
      $self->insert_utplayer($serverlist_id->{id}, %player);
    }

    # log results (debug)
    #$self->log("utserver", 
    #  "$serverlist_id->{id}, $ip:$port,\t".
    #  ($s{numplayers} || "0") ."/".
    #  ($s{maxplayers} || "0") ."players, ".
    #  ($s{mapname}    || "mapname")  .",".
    #  ($s{hostname}   || "hostname")
    #);
  }
}

################################################################################
## Process the list of addresses that was received after querying the UCC applet
## and store them in the pending list.
################################################################################
sub process_ucc_applet_query {
  my ($self, $buf, $ms) = @_;
  $buf = encode('UTF-8', $buf);
  
  # counter
  my $c = 0;
  
  # database types such as SQLite are slow, therefore use transactions.
  $self->{dbh}->begin_work;
  
  # parse $buf into an array of [ip, port]
  foreach my $l (split(/\\/, $buf)) {
  
    # search for \ip\255.255.255.255:7778\, contains ':'
    if ($l =~ /:/) {
      my ($a,$p) = $l =~ /(.*):(.*)/;
      
      # check if address entry is valid
      if ($self->valid_address($a,$p)) {
        # count number of valid addresses
        $c++;
        
        # print address (debug)
        # $self->log("add", "applet query added $ms->{gamename}\t$a\t$p");
        
        # add server
        $self->add_server_new(ip         => $a,
                              beaconport => $p,
                              heartbeat  => $p, 
                              gamename   => $ms->{gamename}, 
                              secure     => $self->secure_string(),
                              updated    => time);
      }
      # invalid address, log
      else {$self->log("error", "invalid address found at master applet $ms->{ip}, $l!");}
    }
  }
  
  # end transaction, commit        
  $self->{dbh}->commit;

  # update time if successful applet query
  $self->update_master_applet(
    ip        => $ms->{ip},
    port      => $ms->{port},
    gamename  => $ms->{gamename}, 
  ) if ($c > 0);
  
  # print findings
  $self->log("applet-rx","found $c addresses at $ms->{ip} for $ms->{gamename}.");
}

1;
