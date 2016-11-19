#!/usr/bin/perl

use strict;
use warnings;
use Encode;
use AnyEvent;
use AnyEvent::Handle;

our %S;

################################################################################
# Verify whether a given domain name or IP address and port are valid.
# returns the valid ip-address + port, or 0 when not.
################################################################################
sub valid_address {
  my $h = shift;

  # split up address and port
  my ($a, $p) = ($h =~ m/:/) ? $h =~ /(.*):(.*)/ : ($h,0);
  return (undef,undef) unless ($a && $p);
  
  # resolve hostname when needed -- shouldn't even be in the list! FIXME
  #if($a =~ /[a-zA-Z]/g) {
  #   my $raw_addr = (gethostbyname($a))[4];
  #   my @octets = unpack("C4", $raw_addr);
  #   $a = join(".", @octets);
  #}
  
  # check if IP and port are in valid range
  $a = ($a =~ '\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b') ? $a : 0;
  $p = (0 < $p && $p <= 65535) ? $p : 0;
  
  # exclude addresses where we don't want people sniffing
  for (qw|192.168.(.\d*).(.\d*) 127.0.(.\d*).(.\d*) 10.0.(.\d*).(.\d*)|){$a = 0 if ($a =~ m/$_/)}

  return ($a, $p);
}

sub query_master {
  my $ms = shift;

  for my $g (@{$ms->{games}}) {
  
    my $cv = AnyEvent->condvar;
    my $master_list  = "";
    my $handle; $handle = new AnyEvent::Handle(
      connect  => [$ms->{ip} => $ms->{port}],
      timeout  => 15,
      poll     => 'r',
      on_error => sub {
        print "($ms->{ip}, $g) $!\n"; 
        $handle->destroy;
        $cv->send;
        },
      on_eof   => sub {
        process_received_data($master_list, $g, $ms);
        $handle->destroy;
        $cv->send;
        },
      on_read  => sub {
        my $m = $_[0]->rbuf;
        $_[0]->rbuf = "";

        # part 1: receive \basic\\secure\$key
        if ($m =~ m/\\basic\\\\secure\\/) {

          # received data
          my %r;
          $m =~ s/\\([^\\]+)\\([^\\]+)/$r{$1}=$2/eg;

          # respond to challenge
          my $validate = get_validate_string($S{game}->{$g}->{key}, $r{secure}, $r{enctype}||0);
        
          # print and send response
          $handle->push_write("\\gamename\\$g\\location\\0\\validate\\$validate\\final\\");
          
          #part 3: also request the list \list\gamename\ut -- skipped in UCC applets
          $handle->push_write("\\list\\\\gamename\\$g\\final\\");
        }
        
        # part 3b: receive the entire list in multiple steps.
        if ($m =~ m/\\ip\\/) { $master_list .= $m; }
      }
    );
    $cv->recv;
  }
}

sub process_received_data {
  my ($buf, $g, $ms) = @_;
  $buf = encode('UTF-8', $buf);
  
  #counter
  my $c = 0;
  
  # parse $buf into an array of [ip, port]
  foreach my $l (split(/\\/, $buf)) {
  
    # search for \ip\255.255.255.255:7778\, contains ':'
    if ($l =~ /:/) {
      my ($a,$p) = valid_address($l);
      next unless ($a && $p);
      db_add_server(ip => $a, port => $p);
      $c++;
    }
  }
  
  print "found $c \t$g \taddresses at $ms->{ip}.\n" if ($c > 0 );
}

1;
