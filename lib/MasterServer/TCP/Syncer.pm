
package MasterServer::TCP::Syncer;

use strict;
use warnings;
use AnyEvent;
use AnyEvent::Handle;
use Exporter 'import';

our @EXPORT = qw| syncer_scheduler sync_with_master process_sync_list|;

################################################################################
## Syncer Scheduler
## Request the masterlist for selected or all games from other 
## 333networks-based masterservers.
################################################################################
sub syncer_scheduler {
  my $self = shift;
  
  # log active
  $self->log("load", "Synchronisation module active.");
  
  # go through the list of provided addresses
  my $i = 0;
  return AnyEvent->timer (
    after     => $self->{sync_time}[0],
    interval  => $self->{sync_time}[1],
    cb        => sub {
      # check if there's a master server entry to be synced. If not, return
      # to zero and go all over again.
      $i = 0 unless $self->{sync_masters}[$i];
      return if (!defined $self->{sync_masters}[$i]);
      
      # synchronze with master $i
      $self->log("tcp", "Attempting to synchronize with $self->{sync_masters}[$i]->{address}");
      $self->sync_with_master($self->{sync_masters}[$i]);

      #increment counter
      $i++;
    }
  );
}

################################################################################
## Sends synchronization request to another 333networks based master server and
## receives the list of games. 
################################################################################
sub sync_with_master {
  my ($self, $ms) = @_;

  # list to store all IPs in.
  my $sync_list = "";
  
  # connection handle
  my $handle; 
  $handle = new AnyEvent::Handle(
    connect  => [$ms->{address} => $ms->{port}],
    timeout  => 3,
    poll     => 'r',
    on_error => sub {$self->log("error","$! on $ms->{address} $ms->{port}"); $handle->destroy;},
    on_eof   => sub {$self->process_sync_list($sync_list, $ms);              $handle->destroy;},
    on_read  => sub {
      # receive and clear buffer
      my $m = $_[0]->rbuf;
      $_[0]->rbuf = "";

      # remove string terminator: sometimes trailing slashes are added or 
      # forgotten by sender, so \secure\abcdef is actually \secure\abcdef{\0}
      chop $m if $m =~ m/secure/;
      
      # part 1: receive \basic\\secure\$key
      if ($m =~ m/basic\\\\secure/) {

        # hash $m into %r
        my %r = ();
        $m =~ s/\\\\/\\undef\\/;
        $m =~ s/\n//;
        $m =~ s/\\([^\\]+)\\([^\\]+)/$r{$1}=$2/eg;
        
        # respond to the validate challenge
        my $validate = $self->validate_string("333networks", $r{secure}, $r{enctype});

        # part 2: send \gamename\ut\location\0\validate\$validate\final\
        $handle->push_write("\\gamename\\333networks\\location\\0\\validate\\$validate\\final\\");
        
        # part 3: request the list \sync\gamenames consisting of space-seperated game names or "all"
        my $request  = "\\sender\\$self->{masterserver_address}\\sync\\".(($self->{sync_games}[0] == 0) ? "all" : $self->{sync_games}[1])."\\final\\";
        
        # push the request to remote host
        $handle->push_write($request);
        
        # clean up $m for future receivings
        $m = "";
        
      } # end secure
      
      # part 4: receive the entire list in multiple steps
      $sync_list .= $m;
    },
  );
}

################################################################################
## Process the list of addresses that was received after querying the UCC applet
## and store them in the pending list.
################################################################################
sub process_sync_list {
  my ($self, $m, $ms) = @_;

  # replace empty values for the string "undef" and replace line endings from netcatters 
  # parse hash {gamename => list of ips seperated by space}
  my %r = ();
  $m =~ s/\\\\/\\undef\\/;
  $m =~ s/\n//;
  $m =~ s/\\([^\\]+)\\([^\\]+)/$r{$1}=$2/eg;
  
  # counter
  my $c = 0;
  
  if (exists $r{echo}) {
    # remote address says...
    $self->log("error", "$ms->{address} replied: $r{echo}");
    
  }
  
  # iterate through the gamenames and addresses
  while ( my ($gn,$addr) = each %r) {
  
    # process all games wether we have a cipher for them.
    if (defined $gn) {
      
      # some database types, such as SQLite, are slow - therefore use transactions.
      $self->{dbh}->begin_work;
      
      # l(ocations, \label\ip:port\) split up in a(ddress) and p(ort)
      foreach my $l (split(/ /, $addr)) {
        
        # search for \255.255.255.255:7778\, contains ':'
        if ($l =~ /:/) {
          my ($a,$p) = $l =~ /(.*):(.*)/;
          
          # check if address entry is valid
          if ($self->valid_address($a,$p)) {
            # count number of valid addresses
            $c++;

            # add server
            $self->syncer_add($a, $p, $gn, $self->secure_string());
            
            # print address
            $self->log("add", "syncer added $gn\t$a\t$p");
          }
          else {
            # invalid address, log
            $self->log("error", "invalid address found while syncing at $ms->{address}: $l!");
          }
       
        } # endif ($l =~ /:/)
      } # end for / /
      
      # end transaction, commit        
      $self->{dbh}->commit;
      
    } # end defined $gn
  } # end while
  
  # end message
  $self->log("sync", "received $c addresses after syncing from $ms->{address}");
}
    
1;
