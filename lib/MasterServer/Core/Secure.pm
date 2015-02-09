
package MasterServer::Core::Secure;

use strict;
use warnings;
use POSIX qw/strftime/;
use Exporter 'import';

our @EXPORT = qw| secure_string validated_beacon validated_request validate_string charshift get_validate_string|;

## generate a random string of 6 characters long for the \secure\ challenge
sub secure_string {
  # spit out a random string, only uppercase characters
  my @c = ('A'..'Z');
  my $s = "";
  $s .= $c[rand @c] for 1..6;
  
  # return random string
  return $s;
}

## Check if beacon has a valid response.
sub validated_beacon {
  my ($self, $gamename, $secure, $enctype, $validate) = @_;
  
  # debugging enabled? Then don't care about validation
  return 1 if ($self->{debug_validate});
  
  # enctype given? 
  $enctype = 0 unless $enctype;
  
  if ($self->{ignore_beacon_key} =~ m/$gamename/i){
    $self->log("secure", "Ignored beacon validation for $gamename.");
    return 1;
  }
  
  # compare received response with challenge
  return ($self->validate_string($gamename, $secure, $enctype) eq $validate) || 0;
}

## Check if request has valid response
sub validated_request {
  my ($self, $gamename, $secure, $enctype, $validate) = @_;
  
  # debugging enabled? Then don't care about validation
  return 1 if ($self->{debug_validate});
  
  # enctype given? 
  $enctype = 0 unless $enctype;
  
  # ignore games and beacons that are listed
  if ($self->{ignore_browser_key} =~ m/$gamename/i){
    $self->log("secure", "Ignored browser validation for $gamename.");
    return 1;
  }
  
  # compare received response with challenge
  return ($self->validate_string($gamename, $secure, $enctype) eq $validate) || 0;
}

################################################################################
# calculate the \validate\ response for the \secure\ challenge. 
# args: gamename, secure_string, encryption type
# returns: validate string (usually 8 characters long)
# !! requires cipher hash to be configured in config! (imported or else)
################################################################################
sub validate_string {
  my ($self, $game, $sec, $enc)  = @_;
  
  # get cipher from gamename
  my $cip = $self->{game}->{$game}->{key} || "XXXXXX";
  
  # don't accept challenge longer than 16 characters -- usually h@xx0rs
  if (length $sec > 16) {
    return "0"}
  
  # check for valid encryption choises
  my $enc_val = (defined $enc && 0 <= $enc && $enc <= 2) ? $enc : 0;
  
  # calculate and return validate string
  return $self->get_validate_string($cip, $sec, $enc_val);
}

################################################################################
# rotate characters as part of the secure/validate algorithm.
# arg and return: int (representing a character)
################################################################################
sub charshift {
  my ($self, $reg) = @_;
    return($reg + 65) if ($reg <  26);
    return($reg + 71) if ($reg <  52);
    return($reg - 4)  if ($reg <  62);
    return(43)        if ($reg == 62);
    return(47)        if ($reg == 63);
    
    # if all else fails
    return(0);
}

################################################################################
# algorithm to calculate the response to the secure/validate query. processes
# the secure_string and returns the challenge_string with which GameSpy secure
# protocol authenticates games.
#
# the following algorithm is based on gsmsalg.h in GSMSALG 0.3.3 by Luigi 
# Auriemma, aluigi@autistici.org, aluigi.org, copyright 2004-2008. GSMSALG 0.3.3
# was released under the GNU General Public License, for more information, see
# the original software at http://aluigi.altervista.org/papers.htm#gsmsalg
#
# conversion and modification of the algorithm by Darkelarious, June 2014.
#
# args: game cipher, 6-char challenge string, encryption type
# returns: validate string (usually 8 characters long)
# !! requires cipher hash to be configured in config! (imported or else)
################################################################################
sub get_validate_string {
  my ($self, $cipher_string, $secure_string, $enctype) = @_;
  
  # import pre-built rotations from config for enctype 
  # -- see GSMSALG 0.3.3 reference for copyright and more information
  my @enc_chars = $self->{enc_chars};

  # convert to array of characters
  my @cip = split "", $cipher_string;
  my @sec = split "", $secure_string;

  # length of strings/arrays which should be 6
  my $sec_len = scalar @sec;
  my $cip_len = scalar @cip;
  
  # from this point on, work with ordinal values
  for (0..$sec_len-1) { $sec[$_] = ord $sec[$_]; }
  for (0..$cip_len-1) { $cip[$_] = ord $cip[$_]; }
  
  # helper vars
  my ($i,$j,$k,$l,$m,$n,$p);

  # too short or too long -- return empty string
  return "" if ($sec_len <= 0 || $sec_len >= 32);
  return "" if ($cip_len <= 0 || $cip_len >= 32);
  
  # temporary array with ascii characters
  my @enc;
  for(0..255) {$enc[$_] = $_;}

  $j = 0;
  for(0..255) {
      $j += $enc[$_] + $cip[$_ % $cip_len];
      $j = $j % 256;
      $l = $enc[$j];
      $enc[$j] = $enc[$_];
      $enc[$_] = $l;
  }

  # store temporary positions  
  my @tmp;
  
  $j = 0;
  $k = 0;
  for($i = 0; $sec[$i]; $i++) {
      $j += $sec[$i] + 1;
      $j = $j % 256;
      $l = $enc[$j];
      $k += $l;
      $k = $k % 256;
      $m = $enc[$k];
      $enc[$k] = $l;
      $enc[$j] = $m;
      $tmp[$i] = $sec[$i] ^ $enc[($l + $m) & 0xff];
  }
  
# part of the enctype 1-2 process
  for($sec_len = $i; $sec_len % 3; $sec_len++) {
      $tmp[$sec_len] = 0;
  }
  
  if ($enctype == 1) {
    for (0..$sec_len-1) {
      $tmp[$_] = $enc_chars[$tmp[$_]];
    }
  }
  elsif ($enctype == 2) {
    for (0..$sec_len-1) {
      $tmp[$_] ^= $cip[$_ % $cip_len];
    }
  }  
  
  # parse the validate array
  $p = 0;
  my @val;
  for($i = 0; $i < $sec_len; $i += 3) {
      $l = $tmp[$i];
      $m = $tmp[$i + 1];
      $m = $m % 256;
      $n = $tmp[$i + 2];
      $n = $n % 256;
      $val[$p++] = $self->charshift($l >> 2);
      $val[$p++] = $self->charshift((($l & 3 ) << 4) | ($m >> 4));
      $val[$p++] = $self->charshift((($m & 15) << 2) | ($n >> 6));
      $val[$p++] = $self->charshift($n & 63);
  }
  
  # return to ascii characters
  my $str = "";
  for (@val) { $str .= chr $_}
  
  return $str;
}

1;
