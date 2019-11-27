#!/usr/bin/perl

use strict;
use JSON;
use Getopt::Long;
use GUS::Model::SRes::Taxon;
use GUS::Model::SRes::TaxonName;
use GUS::Supported::GusConfig;


## TODO, better to ignore null record

my ($organismAbbrev, $gusConfigFile, $outputFileName, $outputFileDir, $help);

&GetOptions('organismAbbrev=s' => \$organismAbbrev,
            'gusConfigFile=s' => \$gusConfigFile,
            'outputFileName=s' => \$outputFileName,
            'outputFileDir=s' => \$outputFileDir,
            'help|h' => \$help
            );

&usage() if ($help);
&usage("Missing a Required Argument") unless (defined $organismAbbrev);


$gusConfigFile = "$ENV{GUS_HOME}/config/gus.config" unless ($gusConfigFile);
my $verbose;
my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        $verbose,0,1,
                                        $gusconfig->getCoreSchemaName()
                                       );
my $dbh = $db->getQueryHandle();


my $outputFileName = $organismAbbrev . "_geneIdMapping.tab" unless($outputFileName);
if ($outputFileDir) {
  $outputFileName = "\./" . $outputFileDir. "\/". $outputFileName;
}

my $extDbRlsId = getPrimaryExtDbRlsIdFromOrganismAbbrev ($organismAbbrev);

open (OUT, ">$outputFileName") || die "cannot open $outputFileName file to write.\n";
print OUT "gene ID\ttranscipt ID\ttranslation ID\n";

my $sql = "
select gf.SOURCE_ID, t.SOURCE_ID, taf.SOURCE_ID
from dots.genefeature gf, dots.transcript t, DOTS.TRANSLATEDAAFEATURE taf
where gf.NA_FEATURE_ID=t.PARENT_ID and t.NA_FEATURE_ID=taf.NA_FEATURE_ID
and gf.EXTERNAL_DATABASE_RELEASE_ID=$extDbRlsId";

my $stmt = $dbh->prepareAndExecute($sql);

while (my ($gSourceId, $tSourceId, $pSourceId)
       = $stmt->fetchrow_array()) {
  print OUT "$gSourceId\t$tSourceId\t$pSourceId\n";
}

close OUT;

$dbh->disconnect();

###########
sub getPrimaryExtDbRlsIdFromOrganismAbbrev{
  my ($abbrev) = @_;

  my $extDbRlsName = $abbrev . "_primary_genome_RSRC";

  my $sql = "select edr.external_database_release_id from sres.externaldatabaserelease edr, sres.externaldatabase ed
             where ed.name = '$extDbRlsName'
             and edr.external_database_id = ed.external_database_id";

  my $stmt = $dbh->prepareAndExecute($sql);

  my @rlsIdArray;
  while ( my($extDbRlsId) = $stmt->fetchrow_array()) {
      push @rlsIdArray, $extDbRlsId;
    }

  die "No extDbRlsId found for '$extDbRlsName'" unless(scalar(@rlsIdArray) > 0);

  die "trying to find unique extDbRlsId for '$extDbRlsName', but more than one found" if(scalar(@rlsIdArray) > 1);

  return @rlsIdArray[0];
}

sub usage {
  die
"
A script to generate gene, transcript, translation ID mapping file that required by EBI

Usage: perl generateGeneTransciptProteinIdMapping.pl --organismAbbrev pfalCD01

where:
  --organismAbbrev:   required, eg. pfal3D7
  --outputFileName:   optional, default is organismAbbrev_genome.json
  --outputFileDir:    optional, default is the current dir
  --gusConfigFile:    optional, default is \$GUS_HOME/config/gus.config

";
}
