#!/usr/bin/perl

##to be used to copy the files from apiSiteFilesStaging to the appropriate directories in apiSiteFiles. Also it needs to replace CURRENT with the actual release number.
## both sourceDir and targetDir must be full paths to these directories

use strict;
use IO::File;
use Getopt::Long;

my($workflowVersion,$projectName,$releaseNumber,$copyFromPreRelease);

&GetOptions("projectName=s" => \$projectName,
            "workflowVersion=s" => \$workflowVersion,
            "releaseNumber=s" => \$releaseNumber,
            "copyFromPreRelease!" => \$copyFromPreRelease,
            );

die "usage: copyDownloadFilesFromStagingToReal.pl --projectName  --workflowVersion --releaseNumber [--copyFromPreRelease]\n" unless ($projectName && $workflowVersion && $releaseNumber);
die "you must use fully qualified value for --projectName\n" unless ($projectName =~ /DB/);
my $targetDir="/eupath/data/apiSiteFiles/downloadSite/${projectName}";
my $sourceDir="/eupath/data/apiSiteFilesStaging/${projectName}/${workflowVersion}/real/downloadSite/${projectName}/release-CURRENT/";
$sourceDir="/eupath/data/apiSiteFilesStagingPreRelease/${projectName}/${workflowVersion}/real/downloadSite/${projectName}/release-CURRENT/" if ($copyFromPreRelease);
die "sourceDir $sourceDir does not exist\n" unless -d "$sourceDir";
die "targetDir $targetDir does not exist\n" unless -d "$targetDir";

$targetDir = "$targetDir/release-${releaseNumber}";
print STDERR "Copying $sourceDir to $targetDir\n"; 
system ("cp -r $sourceDir $targetDir");
print "failed to execute: $!\n" if ($? == -1);
chdir $targetDir or die "Can't chdir to $targetDir\n";
&loopDir($targetDir);
print STDERR "Creating Release_number file under $targetDir\n"; 
my $filename = "$targetDir/Release_number";
open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
print $fh "$releaseNumber\n";
close $fh;

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
