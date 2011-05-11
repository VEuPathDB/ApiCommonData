package ApiCommonData::Load::Plugin::InsertOrganism;
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
     stringArg({ name => 'speciesNcbiTaxonId',
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
     stringArg({ name => 'abbrevPublic',
		 descr => 'eg tgME49',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),
     stringArg({ name => 'abbrevForFilenames',
		 descr => 'eg TgondiiME49',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),
     stringArg({ name => 'abbrevOrthomcl',
		 descr => 'eg tgon',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),
     stringArg({ name => 'abbrevStrain',
		 descr => 'eg ME49',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),
     intArg({ name => 'isReferenceGenome',
		 descr => '',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
	       }),
     intArg({ name => 'isDraftGenome',
		 descr => '',
		 constraintFunc=> undef,
		 reqd  => 1,
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

  $self->initialize ({ requiredDbVersion => 3.5,
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
  my $speciesNcbiTaxonId = $self->getArg('speciesNcbiTaxonId');
  my $abbrev = $self->getArg('abbrev');
  my $abbrevPublic = $self->getArg('abbrevPublic');
  my $abbrevForFilenames = $self->getArg('abbrevForFilenames');
  my $abbrevOrthomcl = $self->getArg('abbrevOrthomcl');
  my $abbrevStrain = $self->getArg('abbrevStrain');
  my $isReferenceGenome = $self->getArg('isReferenceGenome');
  my $isDraftGenome = $self->getArg('isDraftGenome');
  my $projectName = $self->getArg('projectName');

  # validate full name against ncbi taxon id
  my $sql = "select t.taxon_id, t.ncbi_tax_id 
             from sres.taxonname tn, sres.taxon t
             where tn.name = '$fullName'
             and tn.name_class = 'scientific name'
             and t.taxon_id = tn.taxon_id";
  my $sth = $self->prepareAndExecute($sql);
  my ($taxon_id, $ncbi_tax_id) = $sth->fetchrow_array();
  
  $self->error("fullName '$fullName' and ncbiTaxonId '$ncbiTaxonId' do not match, according to SRes.TaxonName") unless $ncbi_tax_id eq $ncbiTaxonId;
  
  # validate species ncbi taxon id against ncbi taxon id

  my $organism =  GUS::Model::ApiDB::Organism->new({'taxon_id' => $taxon_id,
						    'project_name' => $projectName,
						    'abbrev' => $abbrev,
						    'abbrev_public' => $abbrevPublic,
						    'abbrev_for_filenames' => $abbrevForFilenames,
						    'abbrev_orthomcl' => $abbrevOrthomcl,
						    'abbrev_strain' => $abbrevStrain,
						    'is_reference_genome' => $isReferenceGenome,
						    'is_draft_genome' => $isDraftGenome,
						    '' => $,
						   });

  $organismProject->submit() unless $organismProject->retrieveFromDB();

  my $msg = "$fullName added to apidb.Organism.";

  $self->log("$msg \n");

  return $msg;
}



sub undoTables {
  return qw(ApiDB.Organism
           );
}
