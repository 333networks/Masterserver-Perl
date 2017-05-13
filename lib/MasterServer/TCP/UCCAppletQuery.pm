package MasterServer::TCP::UCCAppletQuery;

use strict;
use warnings;
use AnyEvent;
use AnyEvent::Handle;
use Exporter 'import';

our @EXPORT = qw| query_applet |;

################################################################################
## The UCC Applet (Epic Megagames, Inc.) functions as a master server for one 
## single game. However, it does not always follow the defined protocol.
## This module connects with UCC masterserver applets to receive the list.
################################################################################
sub query_applet {
  my ($self, $ms) = @_;
  
  # be nice to notify
  $self->log("tcp","start querying $ms->{ip}:$ms->{port} for '$ms->{gamename}' games");

  # list to store all IPs in.
  my $master_list = "";
  
  # connection handle
  my $handle; 
  $handle = new AnyEvent::Handle(
    connect  => [$ms->{ip} => $ms->{port}],
    timeout  => $self->{timeout_time},
    poll     => 'r',
    on_error => sub {$self->error($!, "$ms->{ip}:$ms->{port}"); $handle->destroy;},
    on_eof   => sub {$self->process_ucc_applet_query($master_list, $ms);  $handle->destroy;},
    on_read  => sub {
    
      # receive and clear buffer
      my $m = $_[0]->rbuf;
      $_[0]->rbuf = "";
      
      # remove string terminator
      chop $m if $m =~ m/secure/;
          
      # part 1: receive \basic\\secure\$key
      if ($m =~ m/\\basic\\\\secure\\/) {

        # received data
        my %r;
        $m =~ s/\\([^\\]+)\\([^\\]+)/$r{$1}=$2/eg;

        # respond to challenge
        my $validate = $self->validate_string(gamename => $ms->{gamename},
                                              enctype  => $r{enctype}||0,
                                              secure   => $r{secure});

        # send response
        $handle->push_write("\\gamename\\$ms->{gamename}\\location\\0\\validate\\$validate\\final\\");
        
        # part 3: also request the list \list\gamename\ut -- skipped in UCC applets
        $handle->push_write("\\list\\\\gamename\\$ms->{gamename}\\final\\");
        
      }
      
      # part 3b: receive the entire list in multiple steps.
      # $m contains \ip\ or part of that string
      else {
        # add buffer to the list
        $master_list .= $m;
      }
    }
  );
}

1;
