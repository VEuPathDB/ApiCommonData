#!/usr/bin/perl

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use GUS::Supported::GusConfig;
use GUS::ObjRelP::DbiDatabase;

my ($gusConfigFile, $verbose);

&GetOptions("gusConfigFile=s" => \$gusConfigFile,
            "verbose!"        => \$verbose );

my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        $verbose,0,1,
                                        $gusconfig->getCoreSchemaName());

my $dbh = $db->getQueryHandle(0);

my $sql = "select source_id, ec_numbers,ortholog_number, paralog_number, orthomcl_name from apidbtuning.GENEATTRIBUTES order by  ORGANISM, species, source_id";

my $sth = $dbh->prepare($sql);
$sth->execute;

open OUT, ">GenesByTaxon_summary.txt";
print OUT "[Gene ID] [EC Numbers] [Ortholog count] [Paralog count] [Ortholog Group]\n";
while (my $row = $sth -> fetchrow_arrayref) {
  my ($source_id, $ec, $ortholog_number, $paralog_number, $orthomcl_name) = @$row;
  print OUT "$source_id, $ec, $ortholog_number, $paralog_number, $orthomcl_name\n";
}

$sth->finish;
close OUT;

open OUT, ">GenesByEcNumber_summary.txt";

$sql =<<EOL;
SELECT DISTINCT ga.source_id, ec_numbers,ortholog_number, paralog_number, orthomcl_name
FROM dots.aaSequenceEnzymeClass asec,
sres.enzymeClass ec, ApidbTuning.GeneAttributes ga
WHERE ga.aa_sequence_id = asec.aa_sequence_id
AND asec.enzyme_class_id = ec.enzyme_class_id
AND asec.evidence_code != 'OrthoMCLDerived'
order by ga.source_id
EOL

print OUT "[Gene ID] [EC Numbers] [Ortholog count] [Paralog count] [Ortholog Group]\n";

$sth = $dbh->prepare($sql);
$sth->execute;

while (my $row = $sth -> fetchrow_arrayref) {
  my ($source_id, $ec, $ortholog_number, $paralog_number, $orthomcl_name) = @$row;
  print OUT "$source_id, $ec, $ortholog_number, $paralog_number, $orthomcl_name\n";
}

$dbh->disconnect; 
