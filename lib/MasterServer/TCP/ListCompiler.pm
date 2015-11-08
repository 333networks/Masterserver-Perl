
package MasterServer::TCP::ListCompiler;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT = qw| compile_list compile_list_cmp compile_sync |;

################################################################################
## compile the list of \ip\ip:port\ addresses and parse them into the 
## plaintext return string.
################################################################################
sub compile_list {
  my ($self, $gamename) = @_;
  
  # get the list from database
  my $serverlist = $self->get_game_list($gamename);
  
  # prepare empty return string
  my $response_string = "";
  
  # add address as regular \ip\127.0.0.1:7777\ format
  for (@{$serverlist}){

    # append \ip\ip:port to string
    $response_string .= "\\ip\\$_->[0]:$_->[1]";
   }
   
  # return the string with data
  return $response_string;
}

################################################################################
## compile the list of binary ip:port addresses and parse them into the 
## ABCDE return string.
################################################################################
sub compile_list_cmp {
  my ($self, $gamename) = @_;
  
  # get the list from database
  my $serverlist = $self->get_game_list($gamename);
  
  # prepare empty return string
  my $response_string = "";

  # compile a return string
  for (@{$serverlist}){
    
    # convert ip address to ABCDEF mode
    my ($A, $B, $C, $D) = ($_->[0] =~ /(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/);
    my ($E, $F) = ($_->[1] >> 8, $_->[1] & 0xFF);
    
    # print as chr string of 6 bytes long      
    my $bin = ""; $bin .= (chr $A) . (chr $B) . (chr $C) . (chr $D) . (chr $E) . (chr $F);
    
    # append to list of addresses
    $response_string .= $bin;
  }

  # return the string with data
  return $response_string;
}


################################################################################
## compile a list of all requested games --or-- if not specified, a list of
## all games
################################################################################
sub compile_sync {
  my ($self, $sync) = @_;
  
  # prepare empty return string
  my $response_string = "";
  my @games;
  
  # client requests to sync all games
  if ($sync eq "all") {
    # get array of gamenames from db
    my $sg = $self->get_gamenames();
    for (@{$sg}) {push @games, $_->[0];}
  }
  # only selected games
  else {
    # split request into array
    @games = split " ", $sync;
  }
  
  # only get unique values from array
  @games = map { $_ => 1 } @games;

  # get the list for every requested gamename
  for my $g (@games) {
    
    # $g is now a gamename -- check if it's supported. Else ignore.
    if (length $self->get_cipher(lc $g) > 1) {
      
      # get list from database
      my $list = $self->get_game_list($g);
      
      # add all games to string separated by spaces
      my $gamestring = "";
      foreach $_ (@{$list}) {$gamestring .= "$_->[0]:$_->[1] ";}

      # if it contains at least one entry, add the list to the response list
      $response_string .= "\\$g\\$gamestring" if (length $gamestring >= 7);
    }
  }

  # return \gamename\addresses\gamename2\addresses2 list
  return $response_string;
}

1;
