#!/usr/bin/perl
#  -*- mode: cperl -*-

use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use GUS::Supported::GusConfig;
use GUS::ObjRelP::DbiDatabase;
use JSON;
# use utf8::all; # TO DO: sort out utf-8 if needed

my ($gusConfigFile, $extDbRlsSpec, $verbose);

&GetOptions("gusConfigFile=s"         => \$gusConfigFile,
	    "extDbRlsSpec=s"          => \$extDbRlsSpec,
            "verbose!"                => \$verbose );

my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        $verbose,0,1,
                                        $gusconfig->getCoreSchemaName());

my $SCHEMA = 'EDA'; # TO DO: needs generalizing for DIY?
my $species_variable_iri = 'EUPATH_0043194';

my $dbh = $db->getQueryHandle(0);

die "FATAL ERROR: couldn't get a database handle - do you have a config/gus.config file in your \$GUS_HOME? (or use the command line option --gusConfigFile)\n" unless ($dbh);

die "Must provide --extDbRlsSpec <RSRC|VERSION>\n" unless (defined $extDbRlsSpec);

my ($externalDatabase, $externalDatabaseRelease) = split /\|/, $extDbRlsSpec;
die "Poorly formated value for --extDbRlsSpec <RSRC|VERSION>\n"
  unless (defined $externalDatabase && defined $externalDatabaseRelease);

# first just get the external database release ID
my $edr_stmt = $dbh->prepare("SELECT dbr.external_database_release_id
 FROM sres.externaldatabaserelease dbr, sres.externaldatabase db
 WHERE db.name = ?
 AND db.external_database_id = dbr.external_database_id
 AND dbr.version = ?");
$edr_stmt->execute($externalDatabase, $externalDatabaseRelease);
my ($extDbRlsId) = $edr_stmt->fetchrow_array();

# and complain if we don't
die "Could not find row for $extDbRlsSpec in Sres tables\n" unless (defined $extDbRlsId);


# now let's get the study's internal abbreviation, for use in table names
my $sa_stmt = $dbh->prepare("
 SELECT study_id, internal_abbrev
 FROM $SCHEMA.study
 WHERE external_database_release_id = ?
");
$sa_stmt->execute($extDbRlsId);
my ($study_id, $studyInternalAbbrev) = $sa_stmt->fetchrow_array();
die "unexpected problem" unless (defined $study_id && defined $studyInternalAbbrev);
# print "yay $extDbRlsSpec has study_id $study_id and internal abbrev $studyInternalAbbrev\n";


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

# we need to read in the whole lot because there can be multiple assays/rows of data per sample
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

foreach my $sample_id (keys %sample2atts_json) {
  printf "$sample2sample_name{$sample_id} => %s\n", join ";", keys %{$sample2species{$sample_id}};
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
