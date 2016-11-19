
package MasterServer::TCP::BrowserHost;

use strict;
use warnings;
use AnyEvent::Socket;
use AnyEvent::Handle;
use Exporter 'import';

our @EXPORT = qw| browser_host clean_tcp_handle|;

################################################################################
## wait for incoming TCP connections from game clients and other masterservers.
## respond with secure/validate, contact info and/or server lists.
## allow other masterservers to synchronize
################################################################################
sub browser_host {
  my $self = shift;

  my $browser = tcp_server undef, $self->{listen_port}, sub {
    my ($fh, $a, $p) = @_;
    
    # validated? yes = 1 no = 0
    my $auth = 0; 
    
    # debug -- new connection opened
    $self->log("tcp","New connection from $a:$p");
    
    # prep a challenge
    my $secure = $self->secure_string();
    
    # handle received data
    my $h; $h = AnyEvent::Handle->new(
      fh        => $fh,
      poll      => 'r',
      timeout   => 5,
      on_eof    => sub {$self->clean_tcp_handle(@_)},
      on_error  => sub {$self->clean_tcp_handle(@_)},
      on_read   => sub {$self->read_tcp_handle($h, $a, $p, $secure, @_)},
    );
    
    # part 1: send \basic\\secure\$key\
    $h->push_write("\\basic\\\\secure\\$secure\\final\\");
    
    # keep handle alive longer and store authentication info
    $self->{browser_clients}->{$h} = [$h, $auth];
    return;
  };
  
  # startup of TCP server complete 
  $self->log("info", "Listening for TCP connections on port $self->{listen_port}.");
  return $browser;
}

################################################################################
## clean handles on timeouts, completed requests and/or errors
################################################################################
sub clean_tcp_handle{
  my ($self, $c) = @_;
  # clean and close the connection
  delete ($self->{browser_clients}->{$c});  
  $c->destroy();
}

1;
