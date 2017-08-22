package MasterServer::TCP::Syncer;

use strict;
use warnings;
use AnyEvent;
use AnyEvent::Handle;
use Exporter 'import';
our @EXPORT = qw| synchronize
                  process_applet
                  process_syncer |;

################################################################################
## Synchronize with UCC Applets (Epic Megagames, Inc.) or other 333networks
## based masterservers. 
################################################################################
sub synchronize {
  my ($self, $ms, $type) = @_;
  my $ipbuflist = "";

  # connection handle
  my $handle; $handle = new AnyEvent::Handle(
    connect  => [$ms->{ip} => $ms->{hostport}],
    timeout  => $self->{timeout_time},
    poll     => 'r',
    on_error => sub {$handle->destroy; $self->error($!, "$ms->{ip}:$ms->{hostport}");},
    on_eof   => sub {
      $handle->destroy;
      if ($type eq "applet") {$self->process_applet($ipbuflist, $ms);}
      if ($type eq "333nwm") {$self->process_syncer($ipbuflist, $ms);}
    },
    on_read  => sub {
      # receive and clear buffer
      my $m = $_[0]->rbuf;
      $_[0]->rbuf = "";

      # part 1: receive \basic\\secure\$key
      if ($m =~ m/\\basic\\\\secure\\/) {

        # use provided gamename for applet or 333networks for syncer
        my $gamename = "";
        $gamename = $ms->{gamename} if ($type eq "applet");
        $gamename = "333networks"   if ($type eq "333nwm");
        
        # processess received data and respond to challenge
        my $rx = $self->data2hashref($m);
        my $validate = $self->validate_string(
          gamename => $gamename, 
          enctype  => $rx->{enctype}, 
          secure   => $rx->{secure}
        );

        # send challenge response
        $handle->push_write("\\gamename\\$gamename\\location\\0\\validate\\$validate\\final\\");

        # part 3a: also request the list \list\\gamename\ut
        my $request = "";
        if ($type eq "applet") {
          $request = "\\list\\\\gamename\\$ms->{gamename}\\final\\";}
        # part 3b: request the list \sync\[gamenames] consisting of space-seperated game names or "all"
        if ($type eq "333nwm") {
          $request  = "\\sync\\".($self->{sync_games}[0] == 0 ? "all" : $self->{sync_games}[1] )."\\final\\";}

        # push the request to remote host
        $handle->push_write($request);
      }
      
      # part 4: receive the entire list in multiple steps.
      # continue receiving data and adding to the buffer
      else {$ipbuflist .= $m;}
    }
  );
}

################################################################################
## Process the list of addresses received from the UCC applet masterserver and 
## move new addresses to the pending list.
################################################################################
sub process_applet {
  my ($self, $buf, $ms) = @_;
  my $new = 0; my $tot = 0;

  # database types such as SQLite are slow, therefore use transactions.
  $self->{dbh}->begin_work;

  # parse $buf into an array of [ip, port]
  foreach my $l (split /\\/, $buf) {
    
    # search for \ip\255.255.255.255:7778\ and capture ip and port
    if (my ($address,$port) = $l =~ /([\.\w]+):(\d+)/ ) {
      # check if address entry is valid
      if ($self->valid_address($address,$port)) {

        # add server and count new/total addresses
        $new += $self->insert_pending(ip => $address, port => $port);
        $tot++;
      }
      # invalid address, log
      else {$self->log("error", "invalid address found at $ms->{ip}:$ms->{hostport} > $l (applet)");}
    }
  } # end foreach
  
  # complete transaction        
  $self->{dbh}->commit;

  # update time if successful applet query
  $self->update_master_applet(ip => $ms->{ip}, port => $ms->{hostport}, gamename => $ms->{gamename} ) 
    if ($tot > 0);

  # print findings
  $self->log("syncer","found $tot ($new new) addresses at $ms->{ip},$ms->{hostport} for $ms->{gamename} (applet)");
}

################################################################################
## Process the list of addresses received from the 333networks masterserver and 
## move new addresses to the pending list.
################################################################################
sub process_syncer {
  my ($self, $buf, $ms) = @_;
  my $new = 0; my $tot = 0;

  # extract to hash: gamename => ( address list )
  my $rx = $self->data2hashref($buf);
  
  # use transactions for large numbers of ip/ports
  $self->{dbh}->begin_work;
  
  # iterate through the gamenames and addresses
  while ( my ($gamename,$addresslist) = each %{$rx}) {

    # parse $buf into an array of [ip, port]
    foreach my $l (split / /, $addresslist) {
    
      # search for \ip\255.255.255.255:7778\ and capture ip and port
      if (my ($address,$port) = $l =~ /([\.\w]+):(\d+)/ ) {
      
        # check if address entry is valid
        if ($self->valid_address($address,$port)) {
          # add server and count new/total addresses
          $new += $self->insert_pending(ip => $address, port => $port);
          $tot++;        

        }
        # invalid address, log
        else {$self->log("error", "invalid address found at $ms->{ip}:$ms->{hostport} > $l (333nwm)");}
      }
    } # end  foreach
  } # end while
  
  # complete transaction        
  $self->{dbh}->commit;
  
  # update time if successful sync master query
  $self->update_server(ip => $ms->{ip}, hostport => $ms->{hostport}) 
    if ($tot > 0);
  
  # end message
  $self->log("syncer", "found $tot ($new new) addresses at $ms->{ip},$ms->{hostport} (333nwm)");
}

1;
