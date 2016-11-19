#!/usr/bin/perl

use strict;
use warnings;

sub get_validate_string {
  my ($cipher_string, $secure_string, $enctype) = @_;
  
  # use pre-built rotations for enctype 
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
