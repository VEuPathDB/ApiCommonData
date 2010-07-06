#!/usr/bin/perl

# replaces arg1 with arg2 and makes a tscp original file

use strict;
use Getopt::Long;

my($ask,$nb,$old,$new);

&GetOptions("old=s" => \$old, 
            "new=s" => \$new,
            );

if (!$old){
print <<endOfUsage;
Replace.perl usage:

  replace.pl -old \"string to be replaced\" -new \"string to replace it with\" <filenames>

  A time-stamped-copy will be made of the original file for backup purposes.

endOfUsage
}

foreach my $file (@ARGV){
  my $new_file = "";
  my $replace = 0;
  open (F, "$file");
  my $len = length($file);
  $len += 3;
  while (<F>) {
    my $dnrp = 0;
    my $rpc = 0;
    while (m/$old/g) {
        $replace++;
        $_ =~ s|$old|$new|;
    } 
    $new_file .= $_;
  }
  if ( $replace >= 1) {
    print "$replace replacements made in $file\n";
    system ("cp $file $file.bak");
    open (OUT, ">$file");
    print OUT $new_file;
    close OUT;
  }
}


