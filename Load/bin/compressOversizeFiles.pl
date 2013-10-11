#!/usr/bin/perl
use strict;

my ($dir) = @ARGV;
$dir = "." unless $dir;
&loopDir($dir, "");
exit;

sub loopDir {
   my($dir) = @_;
   chdir($dir) || die "Cannot chdir to $dir\n";
   local(*DIR);
   opendir(DIR, ".");
   while (my $f=readdir(DIR)) {
      next if ($f eq "." || $f eq "..");
      my $filesize = (stat($f))[7];
      if (-d $f) {
         &loopDir($f);
     }elsif ($filesize > 1073741824) {
	 $filesize = getFileSize($f); 
	 print "compressing $f\t$filesize\n";
	 system ("gzip $f");
	 die "failed to execute: $!\n" if ($? == -1);
     }
   }
   closedir(DIR);
   chdir("..");
}

sub getFileSize
    {
         my $file = shift;
     
         my $size = (stat($file))[7];
    
         if ($size > 1099511627776)  #   TiB: 1024 GiB
         {
             return sprintf("%.1fT", $size / 1099511627776);
         }
         elsif ($size > 1073741824)  #   GiB: 1024 MiB
         {
            return sprintf("%.1fG", $size / 1073741824);
         }
         elsif ($size > 1048576)       #   MiB: 1024 KiB
         {
            return sprintf("%.1fM", $size / 1048576);
         }
         elsif ($size > 1024)            #   KiB: 1024 B
         {
            return sprintf("%.1fK", $size / 1024);
         }
         else                                    #   bytes
         {
            return sprintf("%.0f bytes", $size);
         }
    }

1;
