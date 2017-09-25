package MasterServer::UDP::DatagramProcessor;

use strict;
use warnings;
use Exporter 'import';
our @EXPORT = qw| process_datagram |;

################################################################################
## Process datagrams after querying a server.
## %o contains ip, port, recv buffer, secure string
################################################################################                  
sub process_datagram {
  my ($self, %o) = @_;
  my $rx = $self->data2hashref($o{rxbuf});

  # can not proceed if validate was provided, but not gamename
  return 0 if ( $rx->{validate} && not($rx->{gamename}) );
  # do not process data if no hostport was provided.
  return 0 unless $rx->{hostport};

  # truncate excessively long fields like hostname
  $rx->{hostname} = substr $rx->{hostname}, 0, 199 if (length $rx->{hostname} >= 199);
  
  # try updating serverlist info based on ip/hostport
  my $update = $self->update_server(
    ip        => $o{ip},
    hostport  => $rx->{hostport},
    direct    => $o{direct},
    %{$rx},
  );

  # if not found, insert it in the table, after verification
  if ($update == 0) {
    # can not proceed if gamename was provided, but not validate
    return 0 if ( not($rx->{validate}) && $rx->{gamename} );
  
    # does the recv buffer contain a validation segment?
    my $auth = $self->auth_server(
      gamename  => lc $rx->{gamename},
      secure    => $o{secure},
      enctype   => $rx->{enctype},
      validate  => $rx->{validate},
    ) if ($rx->{validate} && $rx->{gamename});

    # if authenticated, or known to be incapable of authenticating (tribesv)
    if ($auth || $self->{secure_unsupported} =~ m/$rx->{gamename}/i ) {
      # add to the database in three steps. First, insert basic data.
      $self->insert_server(
        ip        => $o{ip},
        port      => $o{port},
        hostport  => $rx->{hostport},
      );
      # second, update the entry with all available information
      $self->update_server(
        ip        => $o{ip},
        hostport  => $rx->{hostport},
        direct    => $o{direct},
        %{$rx},
      );
      # third, insert an entry for extended server information
      $self->insert_extended(
        ip        => $o{ip}, 
        hostport  => $rx->{hostport}
      );
      # log new beacon
      $self->log("add", "new server $o{ip}, $rx->{hostport}". 
        ($rx->{gamename} ? (" for $rx->{gamename}") : "") );

      # addresses are often added through pending list. delete if successful
      $self->remove_pending(ip => $o{ip}, port => $o{port});
    }
    else {
      # log: failed secure test
      my $val_str = $self->validate_string(
        gamename  => lc $rx->{gamename},
        secure    => $o{secure},
        enctype   => $rx->{enctype},
        validate  => $rx->{validate},
      );
      $self->log("secure","$o{ip}, $o{port} failed validation for ".($rx->{gamename} || "empty_gamename") );
      $self->log("secure", 
        "cipher: "   .($self->get_game_props(gamename => $rx->{gamename})->[0]->{cipher} || "empty_cipher") . ", "
       ."secure: "   .($o{secure}      || "empty_secure"). ", "
       ."expected: " .($val_str        || "empty_v_string"). ", "
       ."received: " .($rx->{validate} || "empty_r_validate"));

      # remove addresses anyway to prevent error spamming in log
      $self->remove_pending(ip => $o{ip}, port => $o{port});
      return 0;
    }
  }
  
  # select server id for faster/easier referencing
  my $sid = $self->get_server(
    ip        => $o{ip}, 
    hostport  => $rx->{hostport}, 
    limit     => 1
  )->[0]->{id} || 0;
  
  # server not found in db. strange. manually deleted? ignore and return.
  return 0 unless $sid;

  # update extended information with the unified/new info columns
  my ($uei, $upi) = unify_information($sid,$rx);
  my $u = $self->update_extended(sid => $sid, %{$uei});
  
  # update player information (first delete, then add new)
  $self->delete_players($sid);
  for my $pl (@{$upi}) {$self->insert_players(@{$pl});}
  
  # return true when all done
  return 1 if int($u || 0);
  
  # update possibly failed because we migrated from an older serverlist.
  $self->log("warning", "no extended information for $o{ip}, $rx->{hostport} to update");
  
  # insert extended table entry again
  $self->insert_extended(
    ip        => $o{ip}, 
    hostport  => $rx->{hostport}
  );
  
  # and try to update it again (players were already added independently)
  $u = $self->update_extended(sid => $sid, %{$uei});
  
  # return true when all done
  return 1 if int($u || 0);
  
  # now we're toast
  $self->log("error", "failed to insert $o{ip}, $rx->{hostport} extended information twice");
  return 0;
}

################################################################################
## Process data into readable player stat columns
## server id, received data buffer hash
## returns unified extended info, unified player info
################################################################################     
sub unify_information {
  my ($sid, $rx) = @_;
  my %uei; # unified extended info
  my @upi; # unified  player  info
  
  # FIXME unify with {player playername name, other keys/columns}

  # first process all available player entries
  for (my $i = 0; exists $rx->{"player_$i"}; $i++) {
    # add player info to UPI and remove from hash
    my @player;
    push @player, $sid;
    push @player, delete $rx->{"player_$i"} || "Derp";
    push @player, delete $rx->{"team_$i"};
    push @player, int (delete $rx->{"frags_$i"} || 0);
    push @player, delete $rx->{"mesh_$i"};
    push @player, delete $rx->{"skin_$i"};
    push @player, delete $rx->{"face_$i"};
    push @player, int (delete $rx->{"ping_$i"} || 0);
    push @player, delete $rx->{"ngsecret_$i"};
    push @upi, \@player;
  }
  # return remaining values, player array
  return ($rx, \@upi);
}

1;
