package MasterServer::TCP::ListCompiler;

use strict;
use warnings;
use Exporter 'import';
our @EXPORT = qw| generate_list generate_sync compile_sync |;

################################################################################
## compile the list of \ip\ip:port\ addresses and parse them into the 
## plaintext or compressed address string.
################################################################################
sub generate_list {
  # gamename and \list\(|cmp)
  my ($self, $gamename, $cmp) = @_;
  
  # get the list from database
  my $serverlist = $self->get_server(
    updated => 3600,
    gamename => $gamename,
  );
  
  my $list = "";
  # which format?
  if ($cmp eq "cmp") {
    # compressed format (ABCDEF format)
    for (@{$serverlist}) {
      my ($A, $B, $C, $D) = ($_->{ip} =~ /(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/);
      my ($E, $F) = ($_->{port} >> 8, $_->{port} & 0xFF);
      my $bin = ""; $bin .= (chr $A) . (chr $B) . (chr $C) . (chr $D) . (chr $E) . (chr $F);
      $list .= $bin;}
  }
  else {
    # normal format (regular \ip\127.0.0.1:7777\ format)
    for (@{$serverlist}) {
      $list .= "\\ip\\$_->{ip}:$_->{port}";}
  }
  
  # list ready
  return $list;
}

################################################################################
## compile a list of addresses for all available or requested games.
## opts: all | list of games
################################################################################
sub generate_sync {
  my ($self, $sync) = @_;
  my $list = "";
  my %games = ();

  # prepare list of games
  my $avail = $self->get_gamenames();
  if ($sync eq "all") {
    # if "all" is requested, check which games we have available
    $games{$_->[0]} = 1 for (@{$avail}); }
  else {
    # otherwise, see which of the requested addresses match our db
    for (@{$avail}) {$games{$_->[0]} = 1 if ($sync =~ m/$_->[0]/i); } }
  
  # get the list for every requested gamename
  for my $gamename (keys %games) {
      
      # get list from database
      my $listref = $self->get_server(gamename => $gamename, updated => 3600);
      
      # add all games to string separated by spaces
      my $addresses = "";
      foreach (@{$listref}) {$addresses .= "$_->{ip}:$_->{port} ";}

      # if it contains at least one entry, add the list to the response list
      $list .= "\\$gamename\\$addresses" if (length $addresses >= 7);
  }
  # list ready
  return $list;
}

1;
