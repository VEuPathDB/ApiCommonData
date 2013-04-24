#!/usr/bin/perl

## to be run if undoing all the HTS SNP features for organism


use strict;
use Getopt::Long;
use lib "$ENV{GUS_HOME}/lib/perl";
use GUS::ObjRelP::DbiDatabase;
use GUS::Supported::GusConfig;

my $gusConfigFile = $ENV{GUS_HOME} ."/config/gus.config";
my $referenceOrganism;
my $noCommit;
my $verbose;

&GetOptions("gusConfigFile|gc=s"=> \$gusConfigFile,
            "verbose|v!"=> \$verbose,
            "referenceOrganism|r=s"=> \$referenceOrganism,
            "noCommit|nc!"=> \$noCommit,
            );

if (!$referenceOrganism){
die <<endOfUsage;
undoInitHtsSnpFeatures.pl usage:

  undoInitHtsSnpFeatures.pl  --gusConfigFile|gc <gusConfigFile [\$GUS_HOME/config/gus.config] --referenceOrganism <organism on which SNPs are predicted .. ie aligned to .. in dots.snpfeature.organism> --verbose|v! --noCommit|nc <if present then doesn't commit>\n
endOfUsage
}

my $gusConfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusConfig->getDbiDsn(),
                                         $gusConfig->getDatabaseLogin(),
                                         $gusConfig->getDatabasePassword(),
                                         $verbose, 0, 1,
                                         $gusConfig->getCoreSchemaName()
                                        );

my $dbh = $db->getQueryHandle();

my $seqvarSQL = <<SQL;
delete from DoTS.NaFeature where
parent_id in (
select sf.na_feature_id
from dots.snpfeature sf, SRES.externaldatabase d, SRES.externaldatabaserelease rel
where d.name = 'InsertSnps.pm NGS SNPs INTERNAL'
and rel.external_database_id = d.external_database_id
and sf.external_database_release_id = rel.external_database_release_id
and sf.organism = '$referenceOrganism')
SQL

print "Deleting from DoTS.SeqVariation for '$referenceOrganism'\n";
my $vr = $dbh->do($seqvarSQL) or die $dbh->errstr;
$dbh->commit() unless $noCommit;

print "  Deleted $vr rows from DoTS.SeqVariation\n\n";

my $locSQL = <<SQL;
delete from DoTS.NaLocation where
na_feature_id in (
select sf.na_feature_id
from dots.snpfeature sf, SRES.externaldatabase d, SRES.externaldatabaserelease rel
where d.name = 'InsertSnps.pm NGS SNPs INTERNAL'
and rel.external_database_id = d.external_database_id
and sf.external_database_release_id = rel.external_database_release_id
and sf.organism = '$referenceOrganism')
SQL

print "Deleting from DoTS.NaLocation\n";
my $lr = $dbh->do($locSQL) or die $dbh->errstr;
$dbh->commit() unless $noCommit;

print "  Deleted $lr rows from DoTS.NaLocation\n\n";


my $snpSQL = <<SQL;
delete from DoTS.SnpFeature
where na_feature_id in (
select sf.na_feature_id
from dots.snpfeature sf, SRES.externaldatabase d, SRES.externaldatabaserelease rel
where d.name = 'InsertSnps.pm NGS SNPs INTERNAL'
and rel.external_database_id = d.external_database_id
and sf.external_database_release_id = rel.external_database_release_id
and sf.organism = '$referenceOrganism')
SQL

print "Deleting from DoTS.SnpFeature\n";
my $sr = $dbh->do($snpSQL) or die $dbh->errstr;
$dbh->commit() unless $noCommit;

##rollback if not committing
$dbh->rollback() if $noCommit;

print "  Deleted $sr rows from DoTS.SnpFeature\n\n";

print "undoInitHtsSnpFeatures.pl:  removed $vr SeqVariations, $lr NaLocations and $sr SnpFeatures\n";

$db->logout();

