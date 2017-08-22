package MasterServer::TCP::BrowserHost;

use strict;
use warnings;
use AnyEvent::Socket;
use AnyEvent::Handle;
use Exporter 'import';
our @EXPORT = qw| browser_host |;

# keep handle alive and store authentication info
my %conn = ();

################################################################################
## wait for incoming TCP connections from game clients and other masterservers.
## respond with secure/validate and/or server lists.
## allow other masterservers to synchronize
################################################################################
sub browser_host {
  my $self = shift;

  my $browser = tcp_server undef, $self->{listen_port}, sub {
    my ($fh, $addr, $port) = @_;
    my $auth = 0; 
    
    # prepare a secure/validate challenge
    my $secure = $self->secure_string();

    # handle for client connection
    my $client; $client = AnyEvent::Handle->new(
      fh        => $fh,
      poll      => 'r',
      timeout   => $self->{timeout_time},
      on_eof    => sub {drop_handle($client);},
      on_error  => sub {drop_handle($client);$self->error($!, "client $addr:$port");},
      on_read   => sub {
        # receive data
        my $rx = $self->data2hashref($client->rbuf);$client->rbuf = "";

        # Support echo: log, but don't respond (or recursive echo abuse)
        $self->log("echo","msg $addr:$port: $rx->{echo}") if $rx->{echo};
        
        # first check for validation info
        if ($rx->{validate} && $rx->{gamename}) {
          $auth = $self->auth_browser(
            gamename => $rx->{gamename},
            secure   => $secure,
            enctype  => $rx->{enctype},
            validate => $rx->{validate},
          );
          $conn{$client}[1] = $auth;
          $self->log("secure", "client $addr:$port failed validation $rx->{gamename}") unless $auth;}
        
        # list request with valid gamename / challenge
        if ($auth && $rx->{gamename} && exists $rx->{list}) {
          $client->push_write($self->generate_list($rx->{gamename}, $rx->{list})."\\final\\");
          $self->log("list","$addr:$port retrieved the list for $rx->{gamename}");
          drop_handle($client)}
        
        # sync request with valid gamename / challenge
        if ($auth && $rx->{sync}) {
          $client->push_write($self->generate_sync($rx->{sync})."\\final\\");
          $self->log("syncer","$addr:$port synchronized $rx->{sync}");
          drop_handle($client)}
        
        # request without valid gamename and/or authentication
        if (!$auth && ($rx->{sync} || exists $rx->{list}) ) {
          $client->push_write("\\echo\\You failed to authenticate. See 333networks.com for more info.\\final\\");
          $self->log("warning","$addr:$port failed to authenticate before requesting a list/sync");
          drop_handle($client);}
      },
    );
    
    # part 1: send \basic\\secure\$key\
    $client->push_write("\\basic\\\\secure\\$secure\\final\\");
    
    # keep handle alive and store authentication info
    $conn{$client} = [$client, $auth];
  };
  
  # startup of TCP server complete 
  $self->log("info", "listening for TCP connections on port $self->{listen_port}");
  return $browser;
}

################################################################################
## clean handles on timeouts, completed requests and/or errors
################################################################################
sub drop_handle { 
  my $c = shift;
  delete $conn{$c};  
  $c->destroy();
}

1;
