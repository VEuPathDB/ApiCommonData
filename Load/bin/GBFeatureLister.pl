#!/usr/bin/perl

my %featHash;
my $qualifiers = {};

my $featName = '';
while (<>) {
  if (/^     ([a-z]+)/i) {
     $featHash{$featName} = $qualifiers;
     $featName = $1;
     $qualifiers = $featHash{$featName};
     $qualifiers = {} unless $qualifiers;
  }
  elsif (/^                     \/(\w+)=/) {
     my $qualifier=$1;
     $qualifiers->{$qualifier} = 1; 
   } 
}

foreach my $feat (keys %featHash) {
    print "$feat\n";
    $qualifiers = $featHash{$feat};
    foreach my $item (keys %$qualifiers) {
       print "   $item\n"; 
    }
}
