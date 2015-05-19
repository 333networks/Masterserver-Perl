
package MasterServer::UDP::UCCAppletQuery;

use strict;
use warnings;
use AnyEvent;
use AnyEvent::Handle;
use Exporter 'import';

our @EXPORT = qw| ucc_applet_query_scheduler query_applet |;

################################################################################
## Query Epic Games'-based UCC applets periodically to get an additional
## list of online UT, Unreal (or other) game servers. 
################################################################################
sub ucc_applet_query_scheduler {
  my $self = shift;
  $self->log("load", "UCC Applet Query Scheduler is loaded.");
  
  my $i = 0;
  return AnyEvent->timer (
    after     => $self->{master_applet_time}[0],
    interval  => $self->{master_applet_time}[1],
    cb        => sub {
      # check if there's a master server entry to be queried. If not, return
      # to zero and go all over again.
      $i = 0 unless $self->{master_applet}[$i];
      return if (!defined $self->{master_applet}[$i]);
      
      # perform the query
      $self->query_applet($self->{master_applet}[$i]);

      #increment counter
      $i++;
    }
  );
}

################################################################################
## The UCC Applet (Epic Megagames, Inc.) functions as a master server for one 
## single game. However, it does not always follow the defined protocol.
## This module connects with UCC masterserver applets to receive the list.
################################################################################
sub query_applet {
  my ($self, $ms) = @_;
  
  # be nice to notify
  $self->log("query","start querying $ms->{ip}:$ms->{port} for '$ms->{game}' games");

  # list to store all IPs in.
  my $master_list = "";
  
  # connection handle
  my $handle; 
  $handle = new AnyEvent::Handle(
    connect  => [$ms->{ip} => $ms->{port}],
    timeout  => 5,
    poll     => 'r',
    on_error => sub {$self->log("error", "$! on $ms->{ip}:$ms->{port}."); $handle->destroy;},
    on_eof   => sub {$self->process_ucc_applet_query($master_list, $ms);  $handle->destroy;},
    on_read  => sub {
    
      # receive and clear buffer
      my $m = $_[0]->rbuf;
      $_[0]->rbuf = "";

      # remove string terminator
      chop $m if $m =~ m/secure/;
          
      # part 1: receive \basic\\secure\$key
      if ($m =~ m/\\basic\\\\secure\\/) {
        # skip to part 3: also request the list \list\gamename\ut -- skipped in UCC applets
        #$handle->push_write("\\list\\\\gamename\\$ms->{game}");
        $handle->push_write("\\list\\");
      }
      
      # part 3b: receive the entire list in multiple steps.
      if ($m =~ m/\\ip\\/) {
        # add buffer to the list
        $master_list .= $m;
      }
    }
  );
}

1;
