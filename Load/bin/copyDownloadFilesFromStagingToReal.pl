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

##to be used to copy the files from apiSiteFilesStaging to the appropriate directories in apiSiteFiles. Also it needs to replace CURRENT with the actual release number.
## both sourceDir and targetDir must be full paths to these directories

use strict;
use IO::File;
use Getopt::Long;

my($workflowVersion,$projectName,$releaseNumber);

&GetOptions("projectName=s" => \$projectName,
            "workflowVersion=s" => \$workflowVersion,
            "releaseNumber=s" => \$releaseNumber,
            );

die "usage: copyDownloadFilesFromStagingToReal.pl --projectName  --workflowVersion --releaseNumber\n" unless ($projectName && $workflowVersion && $releaseNumber);
die "you must use fully qualified value for --projectName\n" unless ($projectName =~ /DB/);
my $targetDir="/eupath/data/apiSiteFiles/downloadSite/${projectName}";
my $sourceDir="/eupath/data/apiSiteFilesStaging/${projectName}/${workflowVersion}/real/downloadSite/${projectName}/release-CURRENT/";
die "sourceDir $sourceDir does not exist\n" unless -d "$sourceDir";
die "targetDir $targetDir does not exist\n" unless -d "$targetDir";

$targetDir = "$targetDir/release-${releaseNumber}";
print STDERR "Copying $sourceDir to $targetDir\n"; 
system ("cp -r $sourceDir $targetDir");
print "failed to execute: $!\n" if ($? == -1);
chdir $targetDir or die "Can't chdir to $targetDir\n";
&loopDir($targetDir);

sub loopDir {
   my($dir) = @_;
   chdir($dir) || die "Cannot chdir to $dir\n";
   local(*DIR);
   opendir(DIR, ".");
   while (my $f=readdir(DIR)) {
      next if ($f eq "." || $f eq "..");
      if (-d $f) {
	  print STDERR "Replacing 'CURRENT' with release number $releaseNumber under $f\n"; 
         &loopDir($f);
     }else{
	   my $oldname= $f;
	   $f =~ s/CURRENT/$releaseNumber/;
           my $fileSize =  (stat($oldname))[7];
	   if($fileSize<1){
	       unlink($oldname) or die "Can't remove empty file $oldname\n";
	       print STDERR "Delete empty file $f\n";
	   }else{
	        rename $oldname, $f or die "Can't rename $oldname to $f: $!"; ;
	   }

     }
   }
   closedir(DIR);
   chdir("..");
}

1;
