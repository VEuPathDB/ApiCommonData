#!/usr/bin/perl

use strict;
use Getopt::Long;
use lib "$ENV{GUS_HOME}/lib/perl";
use GUS::ObjRelP::DbiDatabase;
use GUS::Supported::GusConfig;
use Data::Dumper;

#script converts aliase ids to the source_id in dots.genefeature, generally used for quant mass spec data, this may lead to duplicate ids so that the appropriate step class, CBIL::StudyAssayResults::DataMunger::MapIdentifiersAndAverageRows, should be included in the analysisConfig.xml file. This script is not generalized for all files.  


my ($verbose,$gusConfigFile,$profileFile);

&GetOptions("verbose|v!"=> \$verbose,
            "gusConfigFile|gc=s" => \$gusConfigFile,
            "profileFile=s" => \$profileFile,
           );


$gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config" unless($gusConfigFile);

my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        $verbose,1,1,
                                        $gusconfig->getCoreSchemaName());


my $dbh = $db->getQueryHandle();

my %transcriptLength;

my %mappings;

my $dbh = $db->getQueryHandle();

my $sql = "select dbref.primary_identifier, gf.source_id, (abs(nl.start_min - nl.end_max) + 1) as transcript_length from SRes.DBRef DBRef, DoTS.GeneFeature gf, DoTS.DBRefNaFeature naf, SRes.externaldatabaserelease edr, DoTS.Transcript t, DoTS.NaLocation nl where edr.external_database_release_id = dbref.external_database_release_id and dbref.db_ref_id = naf.db_ref_id and edr.id_is_alias = 1 and (gf.is_predicted is null or gf.is_predicted !=1) and naf.na_feature_id = gf.na_feature_id and t.parent_id = gf.na_feature_id and nl.na_feature_id = t.na_feature_id";

my $stmt1 = $dbh->prepareAndExecute($sql);

while ( my($source_id, $offical_gene_id, $transcriptLen) = $stmt1->fetchrow_array()) {
     if (exists ($mappings{$source_id})) {
         if ($transcriptLength{$source_id}) {
            $mappings{$source_id} = $offical_gene_id;
            $transcriptLength{$source_id} = $transcriptLen
         }
      } else {
        $mappings{$source_id} = $offical_gene_id;
        $transcriptLength{$source_id} = $transcriptLen
      }
}
  
$stmt1->finish();

#print Dumper (\%mappings);
open(PROF, $profileFile) or die "Cannot open $profileFile for reading: $!";

while(<PROF>) {
  chomp;
  if(/^PlasmoDBID/){
        print "$_\n";
        next;
  }
  my ($geneId, @values) = split(/\t/, $_);
  
  my $newGeneId = $mappings{$geneId};
  if($newGeneId){
       print "$newGeneId\t".join("\t",@values),"\n";
     }else{
        print "$_\n";
  }
}

$db->logout();
$dbh->disconnect();
close PROF;

sub getGeneFeatureId {
  my ($sourceId, $dbh) = @_;
 
  my %transcriptLength;

  my %mappings;

  my $dbh = $db->getQueryHandle();

  my $sql = "select dbref.primary_identifier, gf.source_id, (abs(nl.start_min - nl.end_max) + 1) as transcript_length from SRes.DBRef DBRef, DoTS.GeneFeature gf, DoTS.DBRefNaFeature naf, SRes.externaldatabaserelease edr, DoTS.Transcript t, DoTS.NaLocation nl where edr.external_database_release_id = dbref.external_database_release_id and dbref.db_ref_id = naf.db_ref_id and edr.id_is_alias = 1 and (gf.is_predicted is null or gf.is_predicted !=1) and naf.na_feature_id = gf.na_feature_id and t.parent_id = gf.na_feature_id and nl.na_feature_id = t.na_feature_id";

  my $stmt1 = $dbh->prepareAndExecute($sql);

  while ( my($source_id, $offical_gene_id, $transcriptLen) = $stmt1->fetchrow_array()) {
      if (exists ($mappings{$source_id})) {
         if ($transcriptLength{$source_id}) {
            $mappings{$source_id} = $offical_gene_id;
            $transcriptLength{$source_id} = $transcriptLen
         }
      } else {
        $mappings{$source_id} = $offical_gene_id;
        $transcriptLength{$source_id} = $transcriptLen
      }
}
  $stmt1->finish();

  return $mappings{$sourceId};
}



