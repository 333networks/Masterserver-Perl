
package MasterServer::Core::Secure;

use strict;
use warnings;
use POSIX qw/strftime/;
use Exporter 'import';

our @EXPORT = qw| load_ciphers 
                  secure_string 
                  validate_string
                  compare_challenge |;

################################################################################
## Supported Games list ciphers
## Clear the Supported Games table and insert the list of supported games AND
## their ciphers / default ports / descriptions included from the 
## data/supportedgames.pl file.
## 
## Only config files after 5 October 2015 work with this script.
################################################################################
sub load_ciphers {
  my $self = shift;
  
  # first delete the old cipher database
  $self->clear_ciphers();
  
  # start inserting ciphers (lots of 'em)
  $self->{dbh}->begin_work;
  
  # iterate through the game list
  for (keys %{$self->{game}}) {
    
    # verify entries
    my %opt = ();
    $opt{gamename}      = lc $_;
    $opt{cipher}        = $self->{game}->{$_}->{key};
    $opt{description}   = $self->{game}->{$_}->{label} || 'Unknown Game';
    $opt{default_qport} = $self->{game}->{$_}->{port} || 0;
    
    # insert the game/cipher in the db or halt on error
    if ($self->insert_cipher(%opt) < 0) {
      $self->{dbh}->rollback;
      $self->halt();
    }
  }
  
  # commit
  $self->{dbh}->commit;
  $self->log("info", "Cipher database successfully updated!");
  
  # unload the game variables from masterserver memory
  $self->{game} = undef;
  
}


################################################################################
# generate a random string of 6 characters long for the \secure\ challenge
# returns string
################################################################################
sub secure_string {
  # spit out a random string, only uppercase characters
  my @c = ('A'..'Z');
  my $s = "";
  $s .= $c[rand @c] for 1..6;
  
  # return random string
  return $s;
}

################################################################################
# authenticate the \validate\ response for the \secure\ challenge. 
# returns 1 on valid response, 0 on invalid
################################################################################
sub compare_challenge {
  my ($self, %o) = @_; 
  
  # debugging enabled? Then don't care about validation
  return 1 if ($self->{debug_validate});
  
  # secure string too long? (because vulnerable in UE)
  return 0 if (length $o{secure} > 16);
  
  # additional conditions to skip checking provided?
  $o{ignore} = "" unless $o{ignore};
  
  # ignore this game if asked to do so
  if ($o{ignore} =~ m/$o{gamename}/i){
    $self->log("secure", "ignored beacon validation for $o{gamename}");
    return 1;
  } 

  # enctype given?
  $o{enctype} = 0 unless $o{enctype};  
  
  # get cipher corresponding with the gamename
  my $cip = $self->get_game_props($o{gamename})->{cipher};  
  
  # calculate validate string
  my $val = get_validate_string($cip, $o{secure}, $o{enctype});

  # return whether or not they match
  return ($val eq $o{validate});
}

################################################################################
# obtain the secure/validate challenge string
################################################################################
sub validate_string {
  my ($self, %o) = @_;
  
  # secure string too long? (because vulnerable in UE)
  return 0 if (length $o{secure} > 16);
  
  # get cipher from gamename
  my $cip = $self->get_game_props(lc $o{gamename})->{cipher};
  
  # enctype given?
  $o{enctype} = 0 unless $o{enctype};  
  
  # calculate and return validate string
  return get_validate_string($cip, $o{secure}, $o{enctype});
}

################################################################################
# algorithm to process the response to the secure/validate query. processes
# the secure_string and returns the challenge_string with which GameSpy secure
# protocol authenticates games.
#
# the following algorithm is based on gsmsalg.h in GSMSALG 0.3.3 by Luigi 
# Auriemma, aluigi@autistici.org, aluigi.org, copyright 2004-2008. GSMSALG 0.3.3
# was released under the GNU General Public License, for more information, see
# the original software at http://aluigi.altervista.org/papers.htm#gsmsalg
#
# conversion and modification of the algorithm by Darkelarious, June 2014 with
# explicit, written permission of Luigi Auriemma.
#
# args: game cipher, 6-char challenge string, encryption type
# returns: validate string (usually 8 characters long)
# !! requires cipher hash to be configured in config! (imported or otherwise)
################################################################################
sub get_validate_string {
  my ($cipher_string, $secure_string, $enctype) = @_;
  
  # use pre-built rotations for enctype 
  # -- see GSMSALG 0.3.3 reference for copyright and more information
  my @enc_chars = ( qw |
    001 186 250 178 081 000 084 128 117 022 142 142 002 008 054 165 
    045 005 013 022 082 007 180 034 140 233 009 214 185 038 000 004 
    006 005 000 019 024 196 030 091 029 118 116 252 080 081 006 022 
    000 081 040 000 004 010 041 120 081 000 001 017 082 022 006 074 
    032 132 001 162 030 022 071 022 050 081 154 196 003 042 115 225 
    045 079 024 075 147 076 015 057 010 000 004 192 018 012 154 094 
    002 179 024 184 007 012 205 033 005 192 169 065 067 004 060 082 
    117 236 152 128 029 008 002 029 088 132 001 078 059 106 083 122 
    085 086 087 030 127 236 184 173 000 112 031 130 216 252 151 139 
    240 131 254 014 118 003 190 057 041 119 048 224 043 255 183 158 
    001 004 248 001 014 232 083 255 148 012 178 069 158 010 199 006 
    024 001 100 176 003 152 001 235 002 176 001 180 018 073 007 031 
    095 094 093 160 079 091 160 090 089 088 207 082 084 208 184 052 
    002 252 014 066 041 184 218 000 186 177 240 018 253 035 174 182 
    069 169 187 006 184 136 020 036 169 000 020 203 036 018 174 204 
    087 086 238 253 008 048 217 253 139 062 010 132 070 250 119 184 
  |),

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
      $val[$p++] = charshift($l >> 2);
      $val[$p++] = charshift((($l & 3 ) << 4) | ($m >> 4));
      $val[$p++] = charshift((($m & 15) << 2) | ($n >> 6));
      $val[$p++] = charshift($n & 63);
  }
  
  # return to ascii characters
  my $str = "";
  for (@val) { $str .= chr $_}
  
  return $str;
}

################################################################################
# rotate characters as part of the secure/validate algorithm.
# arg and return: int (representing a character)
################################################################################
sub charshift {
  my $reg = shift;
    return($reg + 65) if ($reg <  26);
    return($reg + 71) if ($reg <  52);
    return($reg - 4)  if ($reg <  62);
    return(43)        if ($reg == 62);
    return(47)        if ($reg == 63);
    
    # if all else fails
    return(0);
}

1;
