#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
use strict;

my ($dir) = @ARGV;
$dir = "." unless $dir;
&loopDir($dir, "");
exit;

sub loopDir {
   my($dir, $margin) = @_;
   chdir($dir) || die "Cannot chdir to $dir\n";
   local(*DIR);
   opendir(DIR, ".");
   while (my $f=readdir(DIR)) {
      next if ($f eq "." || $f eq "..");
      my $filesize = getFileSize($f); 
      if (-d $f) {
	 print "$margin$f\n";
         &loopDir($f,$margin."   ");
     }else{
	 print "$margin$f\t$filesize\n";
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
