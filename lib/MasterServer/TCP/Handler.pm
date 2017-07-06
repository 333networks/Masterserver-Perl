package MasterServer::TCP::Handler;

use strict;
use warnings;
use AnyEvent::Socket;
use AnyEvent::Handle;
use Exporter 'import';

our @EXPORT = qw| read_tcp_handle 
                  handle_validate 
                  handle_list
                  handle_sync |;

################################################################################
## wait for incoming TCP connections from game clients and other masterservers.
## respond with secure/validate, contact info and/or server lists.
## allow other masterservers to synchronize
################################################################################
sub read_tcp_handle {
  my ($self, $h, $a, $p, $secure, $c) = @_;

  # clear the buffer
  my $m = $c->rbuf;
  $c->rbuf = "";
  
  # did the client validate already?
  my $val = $self->{browser_clients}->{$h}[1];
  
  # in case of errors, log the original message
  my $rxbuf = $m;
  #$self->log("debug","$a:$p sent $rxbuf");

  # allow multiple blocks to add to the response string
  my $response = "";
     
  # replace empty values for the string "undef" and replace line endings from netcatters 
  # parse the received data and extrapolate all the query commands found
  my %r = ();
  $m =~ s/\\\\/\\undef\\/;
  $m =~ s/\\$/\\undef\\/;
  $m =~ s/\\([^\\]+)\\([^\\]+)/$r{$1}=$2/eg;
  
  # secure/validate challenge
  # part 2: receive \gamename\ut\location\0\validate\$validate\final\
  $val = $self->handle_validate(\%r, $h, $secure, $a, $p) 
    if (exists $r{validate} && !$val);
  
  # return address list
  # part 3: wait for the requested action: \list\\gamename\ut\
  $self->handle_list($val, \%r, $c, $a, $p) if (exists $r{list} && exists $r{gamename});
  
  # Sync request from another 333networks-based masterserver. Respond with list
  # of requested games (or all games).
  $self->handle_sync($val, \%r, $c, $a, $p) if (exists $r{sync});
  
  #
  # Support echo: doesn't do anything but print to log if not suppressed.
  $self->log("echo","($a:$p): $r{echo}") if $r{echo};
  
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  # improper syntax/protocol -- no valid commands found
  # respond with an error.
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  if ("sync validate list" =~ m/\Q$response\E/i) {
    
    # error message to client
    $c->push_write("\\echo\\333networks did not understand your request. ".
                   "Contact us via 333networks.com\\final\\");

    # and log it
    $self->log("error","invalid request from browser $a:$p with unknown message \"$rxbuf\".");
  } # end if weird query
  else {
    $c->push_write($response . "\\final\\") if ($response ne "");
  }
}

################################################################################
## The master server opens the connection with the \secure\ challenge. The
## client should respond with basic information about itself and the 
## \validate\ response. In this code block we verify the challenge/response.
################################################################################
sub handle_validate {
  my ($self, $r, $h, $secure, $a, $p) = @_;
  
  # auth var init
  my $val = 0;
  
  # pass or fail the secure challenge
  if (exists $r->{gamename} && $self->get_game_props(gamename => $r->{gamename})) {

    # game exists and we have the key to verify the response
    $val = $self->compare_challenge(
                gamename => $r->{gamename},
                secure   => $secure,
                enctype  => $r->{enctype},
                validate => $r->{validate},
                ignore   => $self->{ignore_browser_key},
              );    

    # update for future queries
    $self->{browser_clients}->{$h}[1] = $val;
  }
  elsif (exists $r->{gamename}) {
    # log
    $self->log("support", "received unknown gamename request \"$r->{gamename}\" from $a:$p.");
  }

  # log (debug)
  #$self->log("secure","$a:$p validated with $val for $r->{gamename}, $secure, $r->{validate}");
  
  # return auth status
  return $val;
}

################################################################################
## At this point, the client should be validated and ready to request with
## the \secure\ command and is allowed to ask for the list.
################################################################################
sub handle_list {
  my ($self, $val, $r, $c, $a, $p) = @_;
  
  # confirm validation
  if ($val && exists $r->{gamename}) {
    
    # prepare the list
    my $data = "";
    
    # determine the return format
    if ($r->{list} =~ /^cmp$/i) {
      # return addresses as byte format (ip=ABCD port=EF)
      $data .= $self->compile_list_cmp($r->{gamename});
    }
    else {
      # return addresses as regular \ip\127.0.0.1:7777\ format
      $data .= $self->compile_list($r->{gamename});
    }
    
    # finalize response string
    $data .= "\\final\\";
    
    # immediately send to client
    $c->push_write($data);
      
    # log successful
    $self->log("list","$a:$p successfully retrieved the list for $r->{gamename}.");
    
    # clean and close the connection
    #$self->log("tcp","closing $a:$p");
    $self->clean_tcp_handle($c);
  }

  # proper syntax/protocol, but incorrect validation. Therefore respond with
  # an 'empty' list, returning only \final\.
  else {
    # return error/empty list
    $c->push_write("\\echo\\333networks failed to validate your request. Use the correct authorization cipher!\\final\\");
    
    # log it too
    $self->log("error","browser $a:$p failed validation for $r->{gamename}");

    # clean and close the connection
    #$self->log("tcp","closing $a:$p");
    $self->clean_tcp_handle($c);        
  }
}

################################################################################
## Respond to \sync\ requests from other 333networks-based masterservers. After
## validation, sync behaves in much the same way as \list\,
################################################################################
sub handle_sync {
  my ($self, $val, $r, $c, $a, $p) = @_;
  
  # alternate part 3: wait for the requested action: \sync\(all|list of games)\sender\domainname
  $self->log("tcp","Sync request from $a:$p found.");

  if ($val && exists $r->{sync}) {

    # compile list of addresses
    my $data  = $self->compile_sync($r->{sync});
       $data .= "\\final\\";

    # send to remote client
    $c->push_write($data);
    
    # log successful (debug)
    $self->log("sync-tx","$a:$p successfully synced.");
    
    # clean and close the connection
    #$self->log("tcp","closing $a:$p");
    $self->clean_tcp_handle($c);
    
  }
  # proper syntax/protocol, but incorrect validation. Therefore respond with
  # an 'empty' list, returning only \final\.
  else {
    
    # return error/empty list
    $c->push_write("\\echo\\333networks failed to validate your request. Use a proper authorization key!\\final\\");
    
    # log it too
    $self->log("error","$a:$p failed synchronization.");

    # clean and close the connection
    #$self->log("tcp","closing $a:$p");
    $self->clean_tcp_handle($c);        
  }
}  

1;
