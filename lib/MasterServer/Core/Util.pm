
package MasterServer::Core::Util;

use strict;
use warnings;
use IP::Country::Fast;
use POSIX qw/strftime/;
use Exporter 'import';

our @EXPORT = qw| valid_address ip2country |;

################################################################################
## return the abbreviated country based on IP
################################################################################
sub ip2country {
my ($self, $ip) = @_;
  my $reg = IP::Country::Fast->new();
  return $reg->inet_atocc($ip);
}

################################################################################
## Verify whether a given domain name or IP address and port are valid.
## returns 1/0 if valid/invalid ip + port
################################################################################
sub valid_address {
  my ($self, $a, $p) = @_;
  
  # check if ip and port are in valid range
  my $val_addr = ($a =~ '\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b');
  my $val_port = (0 < $p && $p <= 65535);
  
  # exclude addresses where we don't want people sniffing
  for (qw|192.168.(.\d*).(.\d*) 127.0.(.\d*).(.\d*) 10.0.(.\d*).(.\d*)|){$val_addr = 0 if ($a =~ m/$_/)}
  
  # only return true if both are valid  
  return ($val_addr && $val_port);
}

1;
