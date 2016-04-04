#!/usr/bin/perl

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use GUS::Supported::GusConfig;
use GUS::ObjRelP::DbiDatabase;

my ($gusConfigFile, $outputGenesByTaxon, $outputGenesByEcNumber, $verbose);

&GetOptions("gusConfigFile=s"         => \$gusConfigFile,
            "outputGenesByTaxon=s"    => \$outputGenesByTaxon,
            "outputGenesByEcNumber=s" => \$outputGenesByEcNumber,
            "verbose!"                => \$verbose );

my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        $verbose,0,1,
                                        $gusconfig->getCoreSchemaName());

my $dbh = $db->getQueryHandle(0);

my $sql =<<SQL;
SELECT gf.source_id, ec.ec_numbers, orthologs.name as ortholog_name, tas.taxon_id
FROM dots.TranslatedAaSequence tas, 
     dots.GeneFeature gf, 
     dots.Transcript t, 
     dots.TranslatedAaFeature taf,
     (SELECT aa_sequence_id,
             SUBSTR(apidb.tab_to_string(set(cast(COLLECT(ec_number order by ec_number)
                    as apidb.varchartab)), '; '), 1, 300) AS ec_numbers
      FROM (SELECT DISTINCT asec.aa_sequence_id,
                 ec.ec_number || ' (' || ec.description || ')' AS ec_number
            FROM dots.AaSequenceEnzymeClass asec, sres.EnzymeClass ec
            WHERE ec.enzyme_class_id = asec.enzyme_class_id
             AND NOT asec.evidence_code = 'OrthoMCLDerived'
            )
      GROUP BY aa_sequence_id) ec,
      (select gf.na_feature_id, sg.name
       from dots.genefeature gf, dots.SequenceSequenceGroup ssg, 
            dots.SequenceGroup sg, core.TableInfo ti
       where gf.na_feature_id = ssg.sequence_id
         and ssg.sequence_group_id = sg.sequence_group_id
         and ssg.source_table_id = ti.table_id
         and ti.name = 'GeneFeature') orthologs
WHERE tas.aa_sequence_id = ec.aa_sequence_id(+)
  AND t.na_feature_id = taf.na_feature_id
  AND taf.aa_sequence_id = tas.aa_sequence_id
  and gf.na_feature_id = t.parent_id
  AND gf.na_feature_id = orthologs.na_feature_id(+)
SQL

my $sth = $dbh->prepare($sql);
$sth->execute;

my %hash;
while (my $row = $sth -> fetchrow_arrayref) {
  my ($source_id, $ec,  $orthomcl_name) = @$row;
  $hash{$source_id} = { ec              => $ec, 
                        orthomcl_name   => $orthomcl_name, 
                        ortholog_number => 0, 
                        paralog_number  => 0 };
}

$sth->finish;

# get ortholog_number
my $sql_ortholog =<<SQL;
WITH A as 
( $sql )
SELECT a1.source_id, count(*) as ortholog_number from A a1, A a2
WHERE a1.ortholog_name = a2.ortholog_name
  AND a1.taxon_id != a2.taxon_id
GROUP BY a1.source_id
SQL

$sth = $dbh->prepare($sql_ortholog);
$sth->execute;

while (my $row = $sth -> fetchrow_arrayref) {
  my ($source_id, $ortholog_number) = @$row;
  $hash{$source_id}->{ortholog_number} = $ortholog_number;
}

$sth->finish;

# get paralog_number
my $sql_paralog =<<SQL;
WITH A as 
( $sql )
SELECT a1.source_id, count(*) as paralog_number from A a1, A a2
WHERE a1.ortholog_name = a2.ortholog_name
  AND a1.taxon_id = a2.taxon_id
  AND a1.source_id != a2.source_id
GROUP BY a1.source_id
SQL

$sth = $dbh->prepare($sql_paralog);
$sth->execute;

while (my $row = $sth -> fetchrow_arrayref) {
  my ($source_id, $paralog_number) = @$row;
  $hash{$source_id}->{paralog_number} = $paralog_number;
}

$sth->finish;

# get all data out
open OUT, ">$outputGenesByTaxon";
open OUT_EC, ">$outputGenesByEcNumber";
print OUT "[Gene ID] [EC Numbers] [Ortholog count] [Paralog count] [Ortholog Group]\n";
print OUT_EC "[Gene ID] [EC Numbers] [Ortholog count] [Paralog count] [Ortholog Group]\n";

while(my ($k, $v) = each %hash) {
  my $source_id = $k;
  my $ec = $hash{$k}->{ec};
  my $ortholog_number = $hash{$k}->{ortholog_number};
  my $paralog_number = $hash{$k}->{paralog_number};
  my $orthomcl_name = $hash{$k}->{orthomcl_name};
  print OUT "$source_id, $ec, $ortholog_number, $paralog_number, $orthomcl_name\n";
  print OUT_EC "$source_id, $ec, $ortholog_number, $paralog_number, $orthomcl_name\n" if $ec; 
}

$dbh->disconnect; 
