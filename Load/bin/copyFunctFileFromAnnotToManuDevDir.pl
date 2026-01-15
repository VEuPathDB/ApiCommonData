#!/usr/bin/perl

## May. 2016
## usage: copyFunctFileFromAnnotToManuDevDir.pl --fileToCopy product.txt

use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use strict;

my ($fileToCopy, $help, $preVersion);

&GetOptions(
	    "fileToCopy=s" => \$fileToCopy,
	    "preVersion=s" => \$preVersion,
            "help|h" => \$help,
           );

&usage() if($help);
&usage("Missing a Required Argument") unless(defined $fileToCopy);

my $curDir = `pwd`;
chomp $curDir;
print "\$curDir = $curDir\n";

my ($project, $orgAbbrev, $soTerm, $version, $source);
if ($curDir =~ /\/eupath\/data\/EuPathDB\/manualDelivery\/(\S+?)\/(\S+?)\/genome\/(\S+?)\/(\S+?)\/workSpace\//i) {
  $project = $1;
  $orgAbbrev = $2;
  $version = $4;
  $soTerm = $3;
  $source = $3;
  if ($source =~ /GeneDB_GFF/) {
    $source = "GeneDB";
  } elsif ($source =~ /(\S+?)\_(\S+?)\_(\S+)/) {
    $source = $2;
  }
}
print "\$project = $project; \$orgAbbrev = $orgAbbrev; \$soTerm = $soTerm; \$version = $version\n";

my ($outDir, $workDir, $finalDir, $fromDir, $finalFile);

if ($fileToCopy) {
  if ($fileToCopy =~ /^dbxref_ec/i || $fileToCopy =~ /^ec/i ) {
    my $tempSource = ($source =~ /genbank/i) ? 'gb' : $source;
    $outDir = "/eupath/data/EuPathDB/manualDelivery/$project/$orgAbbrev/function/$tempSource\_ECAssociations/$version/";
    $finalFile = "ec.txt";

    ## for testing
    my $processedEcFile = "ec.txt.addProteinId";
    $preVersion = $version if (!$preVersion);
    my $cmd4ec = "replaceTransIdWithProteinId.pl --organismAbbrev $orgAbbrev --extDbRlsVer $preVersion --ecFile $fileToCopy > $processedEcFile";
    system($cmd4ec) if ($cmd4ec);
    $fileToCopy = $processedEcFile;

  } elsif ($fileToCopy =~ /^product/i) {
    $outDir = "/eupath/data/EuPathDB/manualDelivery/$project/$orgAbbrev/function/$source\_product_names/$version/";
    $finalFile = "products.txt";
  } elsif ($fileToCopy =~ /^genename/i || $fileToCopy =~ /^gene/i || $fileToCopy =~ /^name/i ) {
    $outDir = "/eupath/data/EuPathDB/manualDelivery/$project/$orgAbbrev/function/$source\_gene_names/$version/";
    $finalFile = "geneName.txt";
  } elsif ($fileToCopy =~ /^go_asso/i || $fileToCopy =~ /^GO/i ) {
    $outDir = "/eupath/data/EuPathDB/manualDelivery/$project/$orgAbbrev/function/$source\_GOAssociations/$version/";
    $finalFile = "associations.gas";
  } elsif ($fileToCopy =~ /^synonym/i) {
    $outDir = "/eupath/data/EuPathDB/manualDelivery/$project/$orgAbbrev/function/synonym/$source/$version/";
    $finalFile = "synonyms.txt";
  } elsif ($fileToCopy =~ /^dbxref/i && $fileToCopy !~ /^dbxref_ec/i ) {
    my $dbxrefType = $fileToCopy;
    $dbxrefType =~ s/^(\S+?)\_(\S+?)\.txt/$2/;
    $dbxrefType =~ s/\.transcript$//;
    $dbxrefType = lc ($dbxrefType);
    $outDir = "/eupath/data/EuPathDB/manualDelivery/$project/$orgAbbrev/dbxref/$dbxrefType\_from_annotation/$version/";
    $finalFile = "mapping.txt";
    print "dbxref type are $dbxrefType\n";
  } elsif ($fileToCopy =~ /^literature/i ) {
    my $dbxrefType = "pmid";
    $outDir = "/eupath/data/EuPathDB/manualDelivery/$project/$orgAbbrev/dbxref/$dbxrefType\_from_annotation/$version/";
    $finalFile = "mapping.txt";
    print "dbxref type are $dbxrefType\n";
  } elsif ($fileToCopy =~ /^alias/i || $fileToCopy =~ /^old_locus_tag/i || $fileToCopy =~ /^previous_systematic_id/i || $fileToCopy =~ /^transcript_id/i) {
    if ($fileToCopy =~ /transcript$/i || $fileToCopy =~ /^transcript/i) {
      $outDir = "/eupath/data/EuPathDB/manualDelivery/$project/$orgAbbrev/alias/PreviousTranscriptIDs/$version/";
    } else {
      $outDir = "/eupath/data/EuPathDB/manualDelivery/$project/$orgAbbrev/alias/PreviousGeneIDs/$version/";
    }
    $finalFile = "aliases.txt";
  } elsif ($fileToCopy =~ /^proteinid/i || $fileToCopy =~ /^protein_id/i) {
    $outDir = "/eupath/data/EuPathDB/manualDelivery/$project/$orgAbbrev/alias/gbProteinId/$version/";
    $finalFile = "aliases.txt";
  } elsif ($fileToCopy =~ /^note/i || $fileToCopy =~ /^comment/i) {
    if ($fileToCopy =~ /transcript$/i) {
      $outDir = "/eupath/data/EuPathDB/manualDelivery/$project/$orgAbbrev/comment/$source"."_transcript/$version/";
    }else{
      $outDir = "/eupath/data/EuPathDB/manualDelivery/$project/$orgAbbrev/comment/$source"."_gene/$version/";
    }
    $finalFile = "comments.txt";
  } elsif ($fileToCopy =~ /^eupathdb_uc/i) {
    $outDir = "/eupath/data/EuPathDB/manualDelivery/$project/$orgAbbrev/dbxref/EuPathDB_comment/$version/";
    $finalFile = "mapping.txt";
  } else {
    print "WARNING: fileToCopy has not been configged yet\n";
    exit;
  }


  if ($outDir && $finalFile) {
    $workDir = $outDir. "workSpace";
    $finalDir = $outDir . "final";
    $fromDir = $outDir . "fromProvider";

    my $cmd1 = "mkdir -p $workDir";
    `$cmd1`;
    my $cmd2 = "mkdir -p $finalDir";
    `$cmd2`;
    my $cmd3 = "mkdir -p $fromDir";
    `$cmd3`;

    print "done $cmd1\ndone $cmd2\ndone $cmd3\n";

    my $cmd4 = "cp $fileToCopy $finalDir/$finalFile";
    `$cmd4`;
    print "done $cmd4\n";

    my $readmeFile = $workDir . "/README";
    print "\$readmeFile = $readmeFile\n";

    my $cmdP1 = "echo \"data extracted from annotation\" > $readmeFile";
    $curDir =~ s/(.+workSpace).*/$1/i;
    my $cmdP2 = "echo \"for more info, please see $curDir/README\" >> $readmeFile";
    my $cmdP3 = "echo \"cp $curDir/extractQualifiers/$fileToCopy final/$finalFile\" >> $readmeFile";
    `$cmdP1`;
    `$cmdP2`;
    `$cmdP3`;

  } else {
    print "double check arguments\n";
    exit;
  }

} else {
  print "missed argument \$fileToCopy\n";
  exit;
}


sub usage {
  die "
A script to copy qualifiers value that extract from annotation
 to the manual delivery directory
Usage: copyFunctFileFromAnnotToManuDevDir.pl --fileToCopy product.txt

where
  --fileToCopy: the file name that need to copy
  --preVersion: optional, only need when do functional annotation update,
                 we use the previous version of external_database_version to run the isf testing

";
}


