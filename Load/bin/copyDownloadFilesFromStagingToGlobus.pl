#!/usr/bin/perl

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use DBI;
use Getopt::Long; 
use CBIL::Util::PropertySet;

my ($build_number, $commit);
my $STAGING = "/eupath/data/apiSiteFilesStaging";
my $GLOBUS  = "/eupath/data/apiSiteFiles/globusGenomesShare";

my $usage =<<EOL;
This script is to copy new or updated genome files from 
apiSiteFilesStaging to globusGenomesShare for each release

Usage:
  copyDownloadFilesFromStagingToGlobus.pl --build_number 46 --commit
  Note: 1. source GUS_HOME first,
        2. run the command with "--commit" if you are sure about the command

EOL

GetOptions( "build_number=s" => \$build_number,
            "commit!"        => \$commit );

die $usage unless $build_number;

my $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, [], 1);

my $user = $gusconfig->{props}->{databaseLogin};
my $pass = $gusconfig->{props}->{databasePassword};
my $dsn  = $gusconfig->{props}->{dbiDsn};
my $dbh  = DBI->connect($dsn, $user, $pass) or die DBI::errstr;

my $sql =<<SQL;
SELECT distinct o.PROJECT_NAME, w.version, o.NAME_FOR_FILENAMES, 
       o.is_annotated_genome,  r.BUILD_NUMBER_INTRODUCED
FROM apidbtuning.datasetpresenter r, 
     apidbtuning.DATASETPROPERTY y, 
     apidb.organism o, 
     apidb.workflow w
WHERE r.DATASET_PRESENTER_ID=y.DATASET_PRESENTER_ID
     and r.type='genome' 
     and (r.BUILD_NUMBER_INTRODUCED=$build_number or 
         (y.property='buildNumberRevised' and y.value=$build_number))
     and w.name = o.PROJECT_NAME
     and o.abbrev || '_primary_genome_RSRC' = r.name
SQL

my $sth = $dbh->prepare($sql);
$sth->execute;

while(my $row = $sth->fetchrow_arrayref) {
   my($project, $wf_version, $organism, $is_annotated, $build_number) = @$row;
   #print "$project, $wf_version, $organism, $is_annotated, $build_number \n";
   print "\n===========================================\n";

   # remove old genome and gff files if they exist
   my @oldfiles = glob("$GLOBUS/$project-*\_$organism\_*Genome.fasta"); 

  foreach (@oldfiles) {
     print "rm $_\n";
     system("rm $_") if $commit;
  }

  @oldfiles = glob("$GLOBUS/$project-*\_$organism\_*.gff");
  foreach (@oldfiles) {
     print "rm $_\n";
     system("rm $_") if $commit;
  }

  # Copy genome file and change file name: CURRENT to build_number
  my $srcDir = "$STAGING/$project/$wf_version/real/downloadSite/$project/release-CURRENT/$organism/fasta/data";
  chdir($srcDir);
  my @files = glob("$project-CURRENT\_$organism\_*Genome.fasta");
  if (scalar @files == 0) {
      print "WARNING.  There are no genome files in this directory: $srcDir\n";
  } elsif (scalar @files > 1) {
      print "Expecting only one genome file but got more in this directory: $srcDir\n";
      print $_."\n" foreach (@files);
      die;
  }
  my $newFileName = $files[0];
  $newFileName =~ s/-CURRENT_/-$build_number\_/;
  my $cmd = "cp $srcDir/$files[0] $GLOBUS/$newFileName";
  print "$cmd\n";
  system($cmd) if $commit;

  # Copy GFF file and change file name: CURRENT to build_number
  my $srcDir = "$STAGING/$project/$wf_version/real/downloadSite/$project/release-CURRENT/$organism/gff/data";
  chdir($srcDir);
  my @files = glob("$project-CURRENT\_$organism*.gff");
  if (scalar @files == 0) {
      print "WARNING.  There are no GFF files in this directory: $srcDir\n";
  } elsif (scalar @files > 1) {
      print "Expecting only one GFF file but got more in this directory: $srcDir\n";
      print $_."\n" foreach (@files);
      die;
  }
  my $newFileName = $files[0];
  $newFileName =~ s/-CURRENT_/-$build_number\_/;
  my $cmd = "cp $srcDir/$files[0] $GLOBUS/$newFileName";
  print "$cmd\n";
  system($cmd) if $commit;

}
