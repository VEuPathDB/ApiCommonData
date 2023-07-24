package ApiCommonData::Load::Plugin::InsertOrganism;
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | absent
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use lib "$ENV{GUS_HOME}/lib/perl";

use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::Organism;




# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

  my $argsDeclaration  =
    [
     stringArg({ name => 'fullName',
		 descr => 'organism full name (must match',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),
     stringArg({ name => 'ncbiTaxonId',
		 descr => '',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),
     stringArg({ name => 'projectName',
		 descr => '',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),
     stringArg({ name => 'abbrev',
		 descr => 'eg tgonME49',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),
     stringArg({ name => 'publicAbbrev',
		 descr => 'eg tgME49',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),
     stringArg({ name => 'nameForFilenames',
		 descr => 'eg TgondiiME49',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),
     stringArg({ name => 'genomeSource',
		 descr => 'eg GeneDB',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),
     stringArg({ name => 'orthomclAbbrev',
		 descr => 'eg tgon',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),
     stringArg({ name => 'strainAbbrev',
		 descr => 'eg ME49',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),
     stringArg({ name => 'refStrainAbbrev',
		 descr => 'the reference strains abbrev eg tgonME49',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),
     booleanArg({ name => 'isReferenceStrain',
		 descr => '',
		 reqd  => 0,
		 isList => 0,
	       }),
     booleanArg({ name => 'isAnnotatedGenome',
		 descr => '',
		 reqd  => 0,
		 isList => 0,
	       }),
     booleanArg({ name => 'hasTemporaryNcbiTaxonId',
		 descr => '',
		 reqd  => 0,
		 isList => 0,
	       }),
     booleanArg({ name => 'isFamilyRepresentative',
		 descr => '',
		 reqd  => 0,
		 isList => 0,
	       }),
     stringArg({ name => 'familyRepOrganismAbbrev',
		 descr => '',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),
     stringArg({ name => 'familyNcbiTaxonIds',
		 descr => '',
		 constraintFunc=> undef,
		 reqd  => 0,
		 isList => 0,
	       }),
     stringArg({ name => 'familyNameForFiles',
		 descr => '',
		 constraintFunc=> undef,
		 reqd  => 0,
		 isList => 0,
	       }),

    ];


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

  my $description = <<DESCR;
Load organism names and project mappings.  Validate organism full name and species ncbi taxon id against ncbi taxon id.
DESCR

  my $purpose = <<PURPOSE;
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Add project organism name mappings
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.OrganismProject
AFFECT

  my $tablesDependedOn = <<TABD;
TABD

  my $howToRestart = <<RESTART;
No restart provided. Undo and re-run.
RESTART

  my $failureCases = <<FAIL;
FAIL

  my $documentation = { purpose          => $purpose,
			purposeBrief     => $purposeBrief,
			tablesAffected   => $tablesAffected,
			tablesDependedOn => $tablesDependedOn,
			howToRestart     => $howToRestart,
			failureCases     => $failureCases,
			notes            => $notes
		      };


sub new {
  my ($class) = @_;
  my $self = {};
  bless($self, $class);

  $self->initialize ({ requiredDbVersion => 4.0,
			cvsRevision => '$Revision$',
			name => ref($self),
			argsDeclaration => $argsDeclaration,
			documentation => $documentation
		      });

  return $self;
}

sub run {
  my ($self) = @_;

  my $fullName = $self->getArg('fullName');
  my $ncbiTaxonId = $self->getArg('ncbiTaxonId');
  my $abbrev = $self->getArg('abbrev');
  my $abbrevPublic = $self->getArg('publicAbbrev');
  my $nameForFilenames = $self->getArg('nameForFilenames');
  my $genomeSource = $self->getArg('genomeSource');
  my $abbrevOrthomcl = $self->getArg('orthomclAbbrev');
  my $abbrevStrain = $self->getArg('strainAbbrev');
  my $abbrevRefStrain = $self->getArg('refStrainAbbrev');
  my $isReferenceStrain = $self->getArg('isReferenceStrain');
  my $isAnnotatedGenome = $self->getArg('isAnnotatedGenome');
  my $hasTemporaryNcbiTaxonId = $self->getArg('hasTemporaryNcbiTaxonId');
  my $isFamilyRepresentative = $self->getArg('isFamilyRepresentative');
  my $familyRepOrganismAbbrev = $self->getArg('familyRepOrganismAbbrev');
  my $familyNcbiTaxonIds = $self->getArg('familyNcbiTaxonIds');
  my $familyNameForFiles = $self->getArg('familyNameForFiles');
  my $projectName = $self->getArg('projectName');

  # validate full name against ncbi taxon id
  my $sql = "select t.taxon_id, t.ncbi_tax_id 
             from sres.taxonname tn, sres.taxon t
             where tn.name = '$fullName'
             and tn.name_class = 'scientific name'
             and t.taxon_id = tn.taxon_id";
  my $sth = $self->prepareAndExecute($sql);
  my ($taxon_id, $ncbi_tax_id) = $sth->fetchrow_array();
  
  $self->error("Could not find a row in sres.taxonname with scientific name '$fullName'") unless $ncbi_tax_id;

  $self->error("fullName '$fullName' and ncbiTaxonId '$ncbiTaxonId' do not match, according to SRes.TaxonName") unless $ncbi_tax_id eq $ncbiTaxonId;
  
  # validate temp ncbi taxon id
  if ($hasTemporaryNcbiTaxonId && $ncbiTaxonId < 9000000000) {
      $self->error("hasTemporaryNcbiTaxonId is true but the provided ncbi taxon ID does not look like a temporary one.  (It must be greater than 9000000000 to be a temp ID)");
  }
  if (!$hasTemporaryNcbiTaxonId && $ncbiTaxonId >= 9000000000) {
      $self->error("hasTemporaryNcbiTaxonId is false but the provided ncbi taxon ID looks like a temporary one.  (It must be greater than 9000000000 to be a temp ID)");
  }

  my $organism =  GUS::Model::ApiDB::Organism->new({'taxon_id' => $taxon_id,
						    'project_name' => $projectName,
						    'abbrev' => $abbrev,
						    'public_abbrev' => $abbrevPublic,
						    'name_for_filenames' => $nameForFilenames,
						    'genome_source' => $genomeSource,
						    'orthomcl_abbrev' => $abbrevOrthomcl,
						    'strain_abbrev' => $abbrevStrain,
						    'ref_strain_abbrev' => $abbrevRefStrain,
						    'is_reference_strain' => $isReferenceStrain,
						    'is_annotated_genome' => $isAnnotatedGenome,
						    'has_temporary_ncbi_taxon_id' => $hasTemporaryNcbiTaxonId,
						    'is_family_representative' => $isFamilyRepresentative,
						    'family_representative_abbrev' => $familyRepOrganismAbbrev,
						    'family_ncbi_taxon_ids' => $familyNcbiTaxonIds,
						    'family_name_for_files' => $familyNameForFiles,
						   });

  $organism->submit() unless $organism->retrieveFromDB();

  my $msg = "$fullName added to apidb.Organism.";

  $self->log("$msg \n");

  return $msg;
}



sub undoTables {
  return qw(ApiDB.Organism
           );
}
