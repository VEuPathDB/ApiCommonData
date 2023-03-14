#!/usr/bin/perl
#  -*- mode: cperl -*-

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use GUS::Supported::GusConfig;
use DBI;
use DBD::Oracle;
use JSON;
use Memoize;
map { memoize($_) } qw/termNameToId termIdToName isAchildofB commonAncestor/;

# use utf8::all; # TO DO: sort out utf-8 if needed

#
# TO DO:
#
# 1. integration into nextflow and reflow
#
# 2. usage function!


my ($gusConfigFile, $extDbRlsSpec, $veupathOntologySpec, $fallbackSpecies, $verbose, $testFunctions);

&GetOptions("gusConfigFile=s"         => \$gusConfigFile,
	    "extDbRlsSpec=s"          => \$extDbRlsSpec,
            "veupathOntologySpec=s"   => \$veupathOntologySpec,
	    "fallbackSpecies=s"       => \$fallbackSpecies,
            "verbose!"                => \$verbose,
	    "testFunctions"           => \$testFunctions);  # test isAchildofB and commonAncestor functions with some hardcoded species names and quit

my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $dbh = DBI->connect($gusconfig->getDbiDsn(),
		       $gusconfig->getDatabaseLogin(),
		       $gusconfig->getDatabasePassword());

die sprintf("FATAL ERROR: could not connect to %s as user %s\n", $gusconfig->getDbiDsn(), $gusconfig->getDatabaseLogin()) unless $dbh;

my $SCHEMA = 'EDA'; # TO DO: needs generalizing for DIY?
my $species_variable_iri = 'EUPATH_0043194';
my $reconciled_species_variable_iri = 'OBI_0001909'; # 'conclusion based on data' placeholder term
my $qualifier_variable_iri = 'IAO_0000078'; # 'curation status specification' placeholder
# TO DO: get correct IRIs from
# NTR: https://github.com/VEuPathDB-ontology/VEuPathDB-ontology/issues/489
# and make sure this is in eupath.owl (requires a release cycle???)
# it should be OK if it's just in popbio.owl (these placeholders have been added as "Species" and "Species qualifier")

die "FATAL ERROR: couldn't get a database handle - do you have a config/gus.config file in your \$GUS_HOME? (or use the command line option --gusConfigFile)\n" unless ($dbh);

die "FATAL ERROR: Must provide --extDbRlsSpec <RSRC|VERSION>\n" unless (defined $extDbRlsSpec);

die "FATAL ERROR: Must provide --veupathOntologySpec <RSRC|VERSION>\n" unless (defined $veupathOntologySpec);

my $extDbRlsId = externalDbReleaseSpecToId($extDbRlsSpec);

my $veupathOntologyId;
if ($veupathOntologySpec) {
  $veupathOntologyId = externalDbReleaseSpecToId($veupathOntologySpec);
}

# now let's get the study id (and internal abbreviation, for use in table names, may not be needed)
my $sa_stmt = $dbh->prepare("
 SELECT study_id, internal_abbrev
 FROM $SCHEMA.study
 WHERE external_database_release_id = ?
");
$sa_stmt->execute($extDbRlsId);
my ($study_id, $studyInternalAbbrev) = $sa_stmt->fetchrow_array();
$sa_stmt->finish();
die "FATAL ERROR: unexpected problem" unless (defined $study_id && defined $studyInternalAbbrev);
# print "yay $extDbRlsSpec has study_id $study_id and internal abbrev $studyInternalAbbrev\n";

if ($testFunctions) {
  printf "'Anopheles arabiensis' is a child of 'gambiae species complex' %s (should be yes)\n",
    isAchildofB(termNameToId('Anopheles arabiensis'), termNameToId('gambiae species complex'), $veupathOntologyId) ? 'yes' : 'no';

  printf "'gambiae species complex' is not a child of 'Anopheles arabiensis' %s (should be no)\n",
    isAchildofB(termNameToId('gambiae species complex'), termNameToId('Anopheles arabiensis'), $veupathOntologyId) ? 'yes' : 'no';

  printf "Common ancestor of 'Anopheles arabiensis' and 'Anopheles funestus' is '%s' (should be 'Cellia')\n",
    termIdToName(commonAncestor(termNameToId('Anopheles arabiensis'), termNameToId('Anopheles funestus'), $veupathOntologyId));

  printf "Common ancestor of 'Anopheles merus' and 'Anopheles melas' is '%s' (should be 'gambiae species complex')\n",
    termIdToName(commonAncestor(termNameToId('Anopheles merus'), termNameToId('Anopheles melas'), $veupathOntologyId));

  printf "And in the opposite direction is also '%s'\n",
    termIdToName(commonAncestor(termNameToId('Anopheles melas'), termNameToId('Anopheles merus'), $veupathOntologyId));

  # two that are EUPATH not NCBITaxon: 'Anopheles perplexens' and 'Culex chorleyi'
  # not sure why 'culicidae' is lowercase, while other terms such as 'Culicinae' is capitalised
  # 'Culicidae' is capitalised in eupath_dev.owl, for example.
  printf "Common ancestor of 'Anopheles perplexens' and 'Culex chorleyi' is '%s' (should be 'culicidae')\n",
    termIdToName(commonAncestor(termNameToId('Anopheles perplexens'), termNameToId('Culex chorleyi'), $veupathOntologyId));


  die "finished tests, quitting...\n";
}


my $sample_and_organism_id_assays_sql = <<FOO;
select
  ea.entity_attributes_id as sample_entity_attributes_id,
  ea.stable_id as sample_stable_id, 
  ea.atts as sample_atts, 
  ea2.entity_attributes_id as assay_entity_attributes_id,
  ea2.stable_id as assay_stable_id,
  ea2.atts as assay_atts
from
  EDA.entityattributes ea,
  EDA.entitytype et,
  EDA.processattributes pa,
  EDA.entityattributes ea2,
  EDA.entitytype et2
where
  ea.entity_type_id = et.entity_type_id and
  et.name = 'sample' and
  et.study_id = ? and
  pa.in_entity_id = ea.entity_attributes_id and
  pa.out_entity_id = ea2.entity_attributes_id and
  ea2.entity_type_id = et2.entity_type_id and
  et2.name = 'organism identification assay'
order by
  ea.stable_id
FOO

my $sample_and_organism_id_assays_stmt = $dbh->prepare($sample_and_organism_id_assays_sql, { ora_auto_lob => 0 });
$sample_and_organism_id_assays_stmt->execute($study_id);

# we need to read the relevant data from the whole study into memory because
# the SQL above returns multiple rows of assay data per sample
# build some hashes
my %sample2atts_json;    # sample_id => atts (raw JSON string)
my %sample2sample_name;  # sample_id => sample_name (just in case we need it)
my %sample2species; # sample_id => species_name => count

while (my ($sample_id, $sample_name, $sample_atts_loc, $assay_id, $assay_name, $assay_atts_loc) = $sample_and_organism_id_assays_stmt->fetchrow_array()) {

  $sample2atts_json{$sample_id} //= readLob($sample_atts_loc, $dbh);
  $sample2sample_name{$sample_id} = $sample_name;

  my $assay_atts_json = readLob($assay_atts_loc, $dbh);
  my $assay_atts = decode_json($assay_atts_json);
  my $species_name = $assay_atts->{$species_variable_iri};
  if ($species_name) {
    if (ref($species_name)) {
      if (ref($species_name) eq 'ARRAY') {
	map { $sample2species{$sample_id}{$_}++ } @{$species_name};
      } else {
	die "FATAL ERROR: we got something that wasn't a scalar or array ref in species assay result JSON for sample $sample_name\n";
      }
    } else {
      $sample2species{$sample_id}{$species_name}++;
    }
  } else {
    warn "sample $sample_name had no species assay result!\n";
  }
}

$sample_and_organism_id_assays_stmt->finish();



foreach my $sample_id (keys %sample2atts_json) {
  my $result; # id of computed reconciled species term
  my $qualifier = 'unambiguous'; # what type of result was computed
  my $internalResult; # Boolean flag

  foreach my $species_name (keys %{$sample2species{$sample_id}}) {

    my $speciesTermId = termNameToId($species_name);

    if (!defined $result) {
      $result = $speciesTermId;
    } elsif (isAchildofB($speciesTermId, $result)) {
      # return the leaf-wards term unless we already chose an internal node
      $result = $speciesTermId unless ($internalResult);
    } elsif ($speciesTermId == $result || isAchildofB($result, $speciesTermId)) {
      # that's fine - stick with the leaf term
    } else {
      # we need to return a common 'ancestral' internal node
      $result = commonAncestor($result, $speciesTermId, $veupathOntologyId);
      $internalResult = 1;
      $qualifier = 'ambiguous';
    }
  }

  $qualifier = 'fallback' unless defined $result;
  my $reconciled_species_name =
    defined $result
      ? termIdToName($result)
      : $fallbackSpecies;

  if (!defined $reconciled_species_name) {
    die "FATAL ERROR: No species reconciliation result and no --fallbackSpecies option provided";
  }

  printf "Sample $sample_id reconciled $reconciled_species_name from [ %s ] ($qualifier)\n",
    join ', ', sort keys %{$sample2species{$sample_id}} if $verbose;

  # now add or replace the new reconciled species in the sample attributes JSON

  my $sample_atts = decode_json($sample2atts_json{$sample_id});
  $sample_atts->{$reconciled_species_variable_iri} = [ $reconciled_species_name ];
  $sample_atts->{$qualifier_variable_iri} = [ $qualifier ];

  # and write it back to the database
  # by default decode_json/encode_json should use utf-8
  my $sample_atts_json = encode_json($sample_atts);

  # is this all we need to do?  No messing about with lobLocators and chunks?
  my $update_stmt = $dbh->prepare('
    UPDATE EDA.entityattributes
    SET atts = ?
    WHERE entity_attributes_id = ?
   ');

  ### will uncomment nearer to proper testing! ###
  $update_stmt->execute($sample_atts_json, $sample_id);
  $update_stmt->finish();
}


#
# warning, Oracle specific code!
#
sub readLob {
  my ($lobLocator, $dbh, $chunkSize) = @_;
  my $offset = 1;   # Offsets start at 1, not 0
  $chunkSize //= 65536;
  my $output;

  while(1) {
    my $data = $dbh->ora_lob_read($lobLocator, $offset, $chunkSize );
    last unless length $data;
    $output .= $data;
    $offset += $chunkSize;
  }

  return $output;
}


#
# externalDbReleaseSpecToId
#
# splits the spec on '|' and returns the external_database_release_id
# after looking up the externaldatabase and externaldatabaserelease tables
#
# warning: global $dbh handle used
sub externalDbReleaseSpecToId {
  my ($extDbRlsSpec) = @_;

  my ($externalDatabase, $externalDatabaseRelease) = split /\|/, $extDbRlsSpec;
  die "FATAL ERROR: Poorly formated value for --extDbRlsSpec <RSRC|VERSION>\n"
    unless (defined $externalDatabase && defined $externalDatabaseRelease);

  # first just get the external database release ID
  my $edr_stmt = $dbh->prepare("SELECT dbr.external_database_release_id
    FROM sres.externaldatabaserelease dbr, sres.externaldatabase db
    WHERE db.name = ?
    AND db.external_database_id = dbr.external_database_id
    AND dbr.version = ?");
  $edr_stmt->execute($externalDatabase, $externalDatabaseRelease);
  my ($extDbRlsId) = $edr_stmt->fetchrow_array();
  $edr_stmt->finish();

  # and complain if we don't
  die "FATAL ERROR: Could not find row for $extDbRlsSpec in Sres tables\n" unless (defined $extDbRlsId);

  return $extDbRlsId;
}


#
# termNameToId
#
# looks up on name returns the ontology_term_id
#
# warning: global $dbh used (won't be memoized unless we provide it as an argument)
#
sub termNameToId {
  my ($term_name) = @_;

  my $stmt = $dbh->prepare("
    SELECT ontology_term_id
    FROM sres.ontologyterm
    WHERE
      name = ?
  ");
  $stmt->execute($term_name);
  my ($term_id) = $stmt->fetchrow_array();
  $stmt->finish();
  die "FATAL ERROR: Could not find term named '$term_name' in sres.ontologyterm\n"
    unless (defined $term_id);

  return $term_id;
}

#
# termIdToName (the inverse of the above)
#
sub termIdToName {
  my ($term_id) = @_;

  my $stmt = $dbh->prepare("
    SELECT name
    FROM sres.ontologyterm
    WHERE
      ontology_term_id = ?
  ");
  $stmt->execute($term_id);
  my ($name) = $stmt->fetchrow_array();
  $stmt->finish();
  die "FATAL ERROR: Could not find term with id '$term_id' in sres.ontologyterm\n"
    unless (defined $name);

  return $name;
}

#
# isAchildofB
#
# contains Oracle-specific SQL
#
sub isAchildofB {
  my ($termA_id, $termB_id, $external_database_release_id) = @_;

  my $sql = << 'EOT';
with r1(subject_term_id, object_term_id) as (
  select subject_term_id, object_term_id
  from sres.ontologyrelationship r
  where object_term_id = ?
    and external_database_release_id = ?
  union all
  select r2.subject_term_id, r2.object_term_id
  from sres.ontologyrelationship r2, r1
  where r2.object_term_id = r1.subject_term_id
)
select * from r1 where subject_term_id = ?
EOT

  my $isChild = $dbh->prepare($sql);
  $isChild->execute($termB_id, $external_database_release_id, $termA_id);

  my ($retval) = $isChild->fetchrow_array();
  $isChild->finish();
  return $retval ? 1 : 0;
}


sub commonAncestor {
  my ($termA_id, $termB_id, $external_database_release_id) = @_;

#
# find common ancestor (first row contains it)
#

  my $sql = << 'EOT';
with r1(subject_term_id, object_term_id, query_term_id, lvl, external_database_release_id) as (
  select subject_term_id, object_term_id, subject_term_id as query_term_id, 1 as lvl, external_database_release_id
  from sres.ontologyrelationship r
  where subject_term_id in (?, ?) and external_database_release_id = ?
  union all
  select r2.subject_term_id, r2.object_term_id, query_term_id, lvl+1, r2.external_database_release_id
  from sres.ontologyrelationship r2, r1
  where r2.subject_term_id = r1.object_term_id
    and r2.subject_term_id != r2.object_term_id -- prevents circular issues
    and r2.external_database_release_id = r1.external_database_release_id
)
select object_term_id
from r1
group by object_term_id
having count(distinct query_term_id) = 2
order by avg(lvl)
EOT

  my $commonAncestor = $dbh->prepare($sql);
  $commonAncestor->execute($termA_id, $termB_id, $external_database_release_id);

  my ($term_id) = $commonAncestor->fetchrow_array();
  $commonAncestor->finish();
  return $term_id;
}
