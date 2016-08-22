#!/usr/bin/perl

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use Getopt::Long;

use GUS::Supported::GusConfig;

use DBI;
use DBD::Oracle;

my ($help, $gusConfigFile, $prevMappedFile, $outputFile);

&GetOptions('help|h' => \$help,
            'gus_config=s' => \$gusConfigFile,
            'prev_mapped_file=s' => \$prevMappedFile,
            'output_file=s' => \$outputFile
            );


unless(-e $gusConfigFile) {
  print STDERR "USING DEFAULT location for gus config\n";
  $gusConfigFile = "$ENV{GUS_HOME}/config/gus.config";
}

my $gusConfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $login       = $gusConfig->getDatabaseLogin();
my $password    = $gusConfig->getDatabasePassword();
my $dbiDsn      = $gusConfig->getDbiDsn();

my $dbh = DBI->connect($dbiDsn, $login, $password) or die DBI->errstr;
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;

open(FILE, $prevMappedFile) or die "Cannot open file $prevMappedFile for reading: $!";
open(OUT, "> $outputFile") or  die "Cannot open file $outputFile for writing: $!";


my $prevMapped = {};

while(<FILE>) {
  chomp;
  my @a = split(/\t/, $_);

  

  $prevMapped->{$a[5]}->{$a[0]}++;
}
close FILE;

my $sql = "select ot.name as qualifier, c.value
from apidb.datasource ds
   , sres.externaldatabase d
   , sres.externaldatabaserelease r
   , study.study s
   , study.studylink sl
   , study.protocolappnode pan
   , study.characteristic c
   , sres.ontologyterm ot
where ds.type = 'isolates' 
and ds.subtype = 'sequencing_typed'
and ds.name = d.name
and ds.version = r.version
and d.EXTERNAL_DATABASE_ID = r.EXTERNAL_DATABASE_ID
and r.EXTERNAL_DATABASE_RELEASE_ID = s.EXTERNAL_DATABASE_RELEASE_ID
and s.STUDY_ID = sl.study_id
and sl.PROTOCOL_APP_NODE_ID = pan.PROTOCOL_APP_NODE_ID
and pan.PROTOCOL_APP_NODE_ID = c.PROTOCOL_APP_NODE_ID
and c.ontology_term_id = ot.ontology_term_id
and ot.name in ('host', 'isolation_source', 'country')
MINUS
(select 'host', name from sres.taxonname
UNION
select 'country', ot.name
from sres.ontologyterm ot
   , sres.externaldatabase d
   , sres.externaldatabaserelease r
where d.name = 'Ontology_gaz_RSRC'
and d.EXTERNAL_DATABASE_ID = r.EXTERNAL_DATABASE_ID
and r.EXTERNAL_DATABASE_RELEASE_ID = ot.EXTERNAL_DATABASE_RELEASE_ID
UNION
select 'isolation_source', ot.name
from sres.ontologyterm ot
   , sres.externaldatabase d
   , sres.externaldatabaserelease r
where d.name in ('OBO_Ontology_envo_RSRC', 'OBO_Ontology_pl_RSRC', 'OBO_Ontology_uberon_RSRC')
and d.EXTERNAL_DATABASE_ID = r.EXTERNAL_DATABASE_ID
and r.EXTERNAL_DATABASE_RELEASE_ID = ot.EXTERNAL_DATABASE_RELEASE_ID
)";
my $sh = $dbh->prepare($sql);
$sh->execute();

while(my ($qualifier, $term) = $sh->fetchrow_array()) {
   unless($prevMapped->{$qualifier}->{$term} ) {
     print OUT "$qualifier\t$term\n";
 }
}

$sh->finish();
$dbh->disconnect();

1;
