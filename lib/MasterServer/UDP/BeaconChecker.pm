package MasterServer::UDP::BeaconChecker;

use strict;
use warnings;
use AnyEvent::Handle::UDP;
use Exporter 'import';
our @EXPORT = qw| query_udp_server |;

################################################################################
## Get the server status from any server over UDP and store the received 
## information in the database. $secure determines the type of query: 
## secure/pending or information.
## options: ip, port, need_validate, direct_uplink
################################################################################
sub query_udp_server {
  my ($self, %o) = @_;
  my $buffer = "";

  # if a secure/validate challenge is still required, generate secure string
  my $secure = $self->secure_string if $o{need_validate};
  
  # connect with UDP server
  my $udp_client; $udp_client = AnyEvent::Handle::UDP->new(
    connect    => [$o{ip}, $o{port}],
    timeout    => $self->{timeout_time},
    on_timeout => sub {$udp_client->destroy;},
    on_error   => sub {$udp_client->destroy;},
    on_recv    => sub {
      # add received data to buffer
      $buffer .= $_[0];
      
      # buffer completed receiving all relevant information?
      if ($buffer =~ m/\\final\\/) {

        # try to process datagram
        $self->process_datagram(
          ip      => $o{ip},
          port    => $o{port},
          rxbuf   => $buffer,
          secure  => $secure,
          direct  => $o{direct_uplink},
        );
      }
      
      # else partial information received. wait for more.
      # else { }
    },
  );

  # determine the requests and send message
  $udp_client->push_send("\\secure\\$secure") if $o{need_validate};
  $udp_client->push_send("\\status\\");
}

1;
