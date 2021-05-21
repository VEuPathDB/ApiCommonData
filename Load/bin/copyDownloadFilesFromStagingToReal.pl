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

##to be used to copy the files from apiSiteFilesStaging to the appropriate directories in apiSiteFiles. Also it needs to replace CURRENT with the actual build number.
## both sourceDir and targetDir must be full paths to these directories
use strict;
use IO::File;
use Getopt::Long;
use File::Find;

my($workflowVersion,$projectName,$buildNumber,$copyFromPreRelease);

&GetOptions("projectName=s" => \$projectName,
            "workflowVersion=s" => \$workflowVersion,
            "buildNumber=s" => \$buildNumber,
            "copyFromPreRelease!" => \$copyFromPreRelease,
            );

die "usage: copyDownloadFilesFromStagingToReal.pl --projectName  --workflowVersion --buildNumber [--copyFromPreRelease]\n" unless ($projectName && $workflowVersion && $buildNumber);
#die "you must use fully qualified value for --projectName\n" unless ($projectName =~ /DB/);
my $targetDir="/eupath/data/apiSiteFiles/downloadSite/${projectName}";
my $sourceDir="/eupath/data/apiSiteFilesStaging/${projectName}/${workflowVersion}/real/downloadSite/${projectName}/release-CURRENT/";
$sourceDir="/eupath/data/apiSiteFilesStagingPreRelease/${projectName}/${workflowVersion}/real/downloadSite/${projectName}/release-CURRENT/" if ($copyFromPreRelease);
die "sourceDir $sourceDir does not exist\n" unless -d "$sourceDir";
die "targetDir $targetDir does not exist\n" unless -d "$targetDir";

$targetDir = "$targetDir/release-${buildNumber}";
print STDERR "Copying $sourceDir to $targetDir\n"; 
system ("cp -r $sourceDir $targetDir");
print "failed to execute: $!\n" if ($? == -1);
chdir $targetDir or die "Can't chdir to $targetDir\n";
&loopDir($targetDir);
&deleteEmptyDirs($targetDir);

print STDERR "Creating Build_number file under $targetDir\n"; 
my $filename = "$targetDir/Build_number";
open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
print $fh "$buildNumber\n";
close $fh;

#print STDERR "Moving pathway files to /eupath/data/apiSiteFiles/downloadSite/${projectName}/pathwayFiles\n";
#if ( -d "/eupath/data/apiSiteFiles/downloadSite/${projectName}/pathwayFiles"){
#	system ("mv /eupath/data/apiSiteFiles/downloadSite/${projectName}/pathwayFiles /eupath/data/apiSiteFiles/downloadSite/${projectName}/pathwayFiles.save");
#	print "failed to execute: $!\n" if ($? == -1);
#}
#system ("mv  ${targetDir}/pathwayFiles /eupath/data/apiSiteFiles/downloadSite/${projectName}/pathwayFiles");
#print "failed to execute: $!\n" if ($? == -1);
#system ("rm -fr /eupath/data/apiSiteFiles/downloadSite/${projectName}/pathwayFiles.save") if ( -d "/eupath/data/apiSiteFiles/downloadSite/${projectName}/pathwayFiles.save");


sub loopDir {
   my($dir) = @_;
   chdir($dir) || die "Cannot chdir to $dir\n";
   local(*DIR);
   opendir(DIR, ".");
   while (my $f=readdir(DIR)) {
      next if ($f eq "." || $f eq "..");
      if (-d $f) {
	  print STDERR "Replacing 'CURRENT' with build number $buildNumber under $f\n"; 
         &loopDir($f);
     }else{
	   my $oldname= $f;
	   $f =~ s/CURRENT/$buildNumber/;
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

sub deleteEmptyDirs {
   my($dir) = @_;
   chdir($dir) || die "Cannot chdir to $dir\n";
   finddepth(sub{rmdir $_ if -d },'.');
   chdir("..");
}

1;
