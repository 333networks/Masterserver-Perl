package MasterServer::UDP::UpLink;

use strict;
use warnings;
use AnyEvent::Handle::UDP;
use Socket qw(sockaddr_in inet_ntoa);
use Exporter 'import';
our @EXPORT = qw| send_heartbeats 
                  do_uplink 
                  process_udp_secure 
                  handle_status_query |;

# for compliance, query ID
my $query_id = 0;

################################################################################
## Broadcast heartbeats to other masterservers
##
################################################################################
sub send_heartbeats {
  my $self = shift;

  # in order to be permitted to sync, you need to share your address too so
  # others can sync from you too. 
  if ($self->{sync_enabled}) {
  
    # get serverlist
    my $masterserverlist = $self->get_server(
        updated   => 3600,
        gamename  => "333networks",
      );
    
    # uplink to every 333networks-based masterserver
    foreach my $ms (@{$masterserverlist}) {
      # send uplink
      $self->do_uplink($ms->{ip}, $ms->{port});
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
  
  # report uplinks to log
  $self->log("uplink", "uplink to Masterserver $ip:$port");
  
  # connect with UDP server
  my $udp_client; $udp_client = AnyEvent::Handle::UDP->new(
    connect     => [$ip, $port],
    timeout     => $self->{timeout_time},
    on_timeout  => sub {$udp_client->destroy()},
    on_error    => sub {$udp_client->destroy()},
    on_recv     => sub {
      my ($self, $buf, $udp, $pa) = @_; 
      $self->handle_status_query($udp, $pa, $buf)
        if ($buf =~ m/secure/);
    },
  );

  # Send heardbeat
  $udp_client->push_send("\\heartbeat\\$self->{beacon_port}\\gamename\\333networks");
}

################################################################################
## Respond to status-like queries. Supported: basic, info, rules, status.
## Note: this replaces the \about\ query in the TCP handler!
################################################################################
sub handle_status_query {
  # self, handle, packed address, buffer
  my ($self, $udp, $paddress, $buffer) = @_; 
  my $rx = $self->data2hashref($buffer);
  my $response = "";
  
  # for compliance, query ids between 0-99
  $query_id = ($query_id >= 98) ? 1 : ++$query_id;
  my $sub_id = 1;
  
  # get database info to present game stats, where num_total > 0
  my $maxgames = $self->check_cipher_count();
  my $gameinfo = $self->get_game_props(
    num_gt => 1, 
    sort => "num_total", 
    reverse => 1
  );

  # secure challenge  
  if (defined $rx->{secure}) {
    $response .= "\\validate\\"
              .  $self->validate_string(
                    gamename => "333networks",
                    enctype  => 0,
                    secure   => $rx->{secure}
                 );
  }
  
  # basic query
  if (defined $rx->{basic} || defined $rx->{status}) {
    $response .= "\\gamename\\333networks"
              .  "\\gamever\\$self->{short_version}"
              .  "\\location\\0"
              .  "\\queryid\\$query_id.".$sub_id++;
  }
  
  # info query
  if (defined $rx->{info} || defined $rx->{status}) {
    $response .= "\\hostname\\".($self->{masterserver_hostname} || "")
              .  "\\hostport\\$self->{listen_port}"
              .  "\\gametype\\MasterServer"
              .  "\\mapname\\333networks"
              .  "\\numplayers\\".(scalar @{$gameinfo} || 0)
              .  "\\maxplayers\\".($maxgames || 0)
              .  "\\gamemode\\openplaying"
              .  "\\queryid\\$query_id.".$sub_id++;
  }
  
  # rules query
  if (defined $rx->{rules} || defined $rx->{status}) {
    $response .= "\\mutators\\333networks synchronization, UCC Master applet synchronization, Server Status Checker"
              .  "\\AdminName\\".($self->{masterserver_name} || "")
              .  "\\AdminEMail\\".($self->{masterserver_contact} || "")
              .  "\\queryid\\$query_id.".$sub_id++;
  }

  # close query with final tag
  $response .= "\\final\\";
  
  # split the response in chunks of 512 characters and send
  while (length $response > 512) {
    my $chunk = substr $response, 0, 512, '';
    $udp->push_send($chunk, $paddress);
  }
  # last <512 chunk
  $udp->push_send($response, $paddress);
}

1;
