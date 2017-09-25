package MasterServer::Core::Util;

use strict;
use warnings;
use Socket;
use Encode;
use IP::Country::Fast;
use POSIX qw/strftime/;
use Exporter 'import';
our @EXPORT = qw| data2hashref 
                  ip2country 
                  host2ip 
                  valid_address 
                  db_all 
                  sqlprint |;

################################################################################
## process udp/tcp data strings from \key\value to hash
################################################################################
sub data2hashref {
  my ($self, $str) = @_;
  my @a = split /\\/, encode('UTF-8', $str||"");
  shift @a;
  my %h = (@a, (scalar @a % 2 == 1) ? "dummy" : () );
  return \%h;
}

################################################################################
## return the abbreviated country name based on IP
################################################################################
sub ip2country {
  my ($self, $ip) = @_;
  my $reg = IP::Country::Fast->new();
  return $reg->inet_atocc($ip);
}

################################################################################
## return IP of a hostname
################################################################################
sub host2ip {
  my ($self, $name) = @_;
  my $unpack = inet_aton($name) if $name;
  return inet_ntoa($unpack) if $unpack;
}

################################################################################
## Verify whether a given domain name or IP address and port are valid.
## returns 1/0 if valid/invalid ip + port. IPv4 ONLY!
################################################################################
sub valid_address {
  my ($self, $a, $p) = @_;

  # check if ip and port are in valid range
  my $val_addr = ($a =~ '^(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$') if $a;
  my $val_port = ($p =~  m/^\d+$/ && 0 < $p && $p <= 65535) if $p;
  
  # exclude local addresses
  if ($a =~ m/192.168.(\d).(\d)/ || $a =~ m/127.0.(\d).(\d)/ || $a =~ m/10.0.(\d).(\d)/) { $val_addr = 0; }
  
  # only return true if both are valid  
  return ($val_addr && $val_port);
}

################################################################################
# Adaptation of TUWF's dbAll sql function
################################################################################
sub db_all {
  my $self = shift;
  my $sqlq = shift;
  my $s = $self->{dbh};

  $sqlq =~ s/\r?\n/ /g;
  $sqlq =~ s/  +/ /g;
  my(@q) = @_ ? sqlprint($sqlq, @_) : ($sqlq);

  my($q, $r);
  my $ret = eval {
    $q = $s->prepare($q[0]);
    $q->execute($#q ? @q[1..$#q] : ());
    $r = $q->fetchall_arrayref({});
    $q->finish();
    1;
  };

  $r = [] if (!$r || ref($r) ne 'ARRAY');
  return $r;
}  

################################################################################
# sqlprint (TUWF, Yorhel):
#   ?    normal placeholder
#   !l   list of placeholders, expects arrayref
#   !H   list of SET-items, expects hashref or arrayref: format => (bind_value || \@bind_values)
#   !W   same as !H, but for WHERE clauses (AND'ed together)
#   !s   the classic sprintf %s, use with care
# This isn't sprintf, so all other things won't work,
# Only the ? placeholder is supported, so no dollar sign numbers or named placeholders
################################################################################
sub sqlprint { # query, bind values. Returns new query + bind values

  my @a;
  my $q='';
  for my $p (split /(\?|![lHWs])/, shift) {
    next if !defined $p;
    if($p eq '?') {
      push @a, shift;
      $q .= $p;
    } elsif($p eq '!s') {
      $q .= shift;
    } elsif($p eq '!l') {
      my $l = shift;
      $q .= join ', ', map '?', 0..$#$l;
      push @a, @$l;
    } elsif($p eq '!H' || $p eq '!W') {
      my $h=shift;
      my @h=ref $h eq 'HASH' ? %$h : @$h;
      my @r;
      while(my($k,$v) = (shift(@h), shift(@h))) {
        last if !defined $k;
        my($n,@l) = sqlprint($k, ref $v eq 'ARRAY' ? @$v : $v);
        push @r, $n;
        push @a, @l;
      }
      $q .= ($p eq '!W' ? 'WHERE ' : 'SET ').join $p eq '!W' ? ' AND ' : ', ', @r
        if @r;
    } else {
      $q .= $p;
    }
  }
  return($q, @a);
}

1;
