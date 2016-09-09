
package ApiCommonData::Load::Plugin::InsertPhenotype;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use GUS::PluginMgr::Plugin;
use GUS::Supported::Util;
use GUS::Model::ApiDB::PhenotypeModel;
use GUS::Model::ApiDB::PhenotypeResult;
use GUS::Model::SRes::OntologyTerm;
sub getArgsDeclaration {
my $argsDeclaration  =
[

     stringArg({ name => 'inputFile',
		 descr => 'TAB file that the plugin has to be run on',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
		 mustExist => 1,
	       }),
     stringArg({ name => 'extDbName',
		 descr => 'externaldatabase name',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       }),
     stringArg({ name => 'extDbVer',
		 descr => 'externaldatabaserelease version',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       }),

   stringArg({name => 'organismAbbrev',
	      descr => 'if supplied, use a prefix to use for tuning manager tables',
	      reqd => 0,
	      constraintFunc => undef,
	      isList => 0,
	     }),

];

return $argsDeclaration;
}


sub getDocumentation {

  my $description = <<NOTES;
NOTES

  my $purpose = <<PURPOSE;
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
PURPOSEBRIEF

  my $syntax = <<SYNTAX;
SYNTAX

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
AFFECT

  my $tablesDependedOn = <<TABD;
TABD

  my $howToRestart = <<RESTART;
RESTART

  my $failureCases = <<FAIL;
FAIL

  my $documentation = {purpose=>$purpose, purposeBrief=>$purposeBrief,tablesAffected=>$tablesAffected,tablesDependedOn=>$tablesDependedOn,howToRestart=>$howToRestart,failureCases=>$failureCases,notes=>$notes};

  return ($documentation);
}



sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  $self->initialize({requiredDbVersion => 4.0,
		     cvsRevision => '$Revision$',
		      name => ref($self),
		     argsDeclaration   => $args,
		     documentation     => $documentation
		    });
  return $self;
}

sub run {
  my $self = shift;

  my $extDbReleaseId = $self->getExtDbRlsId($self->getArg('extDbName'),$self->getArg('extDbVer'))
    || $self->error("Cannot find external_database_release_id for the data source");


  my $file = $self->getArg('inputFile');
  my $notOntologyTerm = GUS::Model::SRes::OntologyTerm->new({name=>'NOT',source_id=>'EuPathUserDefined_NOT'});
  $notOntologyTerm->retrieveFromDB();
  $notOntologyTerm->submit();
  my $ontologyTermIds = $self->queryForOntologyTermIds();
#  my $chebiTermIds = $self->queryForChebiTermIds();
  open(FILE, $file) or die "Cannot open file $file for reading: $!";

  my $count;

  while(<FILE>) {
    chomp;
    my @a = split(/\t/, $_);

    my $geneSourceId = $a[0];
    my $modelSourceId = $a[1];
    my $name = $a[2];
    my $pubmedId = $a[3];
    my $modType = $a[4];

    my $isSuccessful = $a[5] eq 'yes'? 1 : 0;
    my $organism = $a[6];
    my $qualityTerm = $a[7];
    my $entityTerm = $a[8];
    my $timing = $a[9];
    my $lifeCycleTerm = $a[10];
    $lifeCycleTerm =~ s/^\s+//;
    $lifeCycleTerm =~ s/\s+$//;
    my $phenotypeString = $a[11];
    my $evidenceTerm = $a[12];
    my $note = $a[13];
    my $experimentType = $a[14];
    my $allele = $a[15];
    my $chebiAnnotationExtension= $a[16];
    my $proteinAnnotationExtension = $a[17];


    my $naFeatureId =  GUS::Supported::Util::getGeneFeatureId($self, $geneSourceId, 0, $self->getArg('organismAbbrev')) ;
#    my $ontologyProteinExtensionNaFeatureId = GUS::Supported::Util::getGeneFeatureId($self, $proteinAnnotationExtension, 0, $self->getArg('organismAbbrev')) ;
    my $phenotypeModel = $self->lookupModel($modelSourceId, $naFeatureId, $pubmedId);

    unless($phenotypeModel) {
      $phenotypeModel = GUS::Model::ApiDB::PhenotypeModel->new({external_database_release_id => $extDbReleaseId, 
                                                                na_feature_id => $naFeatureId,
                                                                source_id => $modelSourceId,
                                                                name => $name,
                                                                pubmed_id => $pubmedId,
                                                                modification_type => $modType,
                                                                is_successful => $isSuccessful,
                                                                organism => $organism,
								experiment_type => $experimentType,
								allele => $allele,
                                                               });

      push @{$self->{_models}}, $phenotypeModel;
    }

    my ($qualityTermId, $entityTermId, $lifeCycleTermId, $evidenceTermId, $chebiTermId, $proteinTermId);
    if($qualityTerm) {
      $qualityTermId = $ontologyTermIds->{$qualityTerm};
      $self->userError("quality Term ${qualityTerm} specified but not found in database") unless($qualityTermId);
    }
    if($entityTerm) {
      $entityTermId = $ontologyTermIds->{$entityTerm};
      $self->userError("entity Term $entityTerm specified but not found in database") unless($entityTermId);
    }
    if($lifeCycleTerm) {
      $lifeCycleTermId = $ontologyTermIds->{$lifeCycleTerm};
      $self->userError("lifeCycle Term $lifeCycleTerm specified but not found in database") unless($lifeCycleTermId);
    }
    if($evidenceTerm) {
      $evidenceTermId = $ontologyTermIds->{$evidenceTerm};
      $self->userError("evidence Term $evidenceTerm specified but not found in database") unless($evidenceTermId);
    }
#check against chebi table - seperate hash  
 #  if($chebiAnnotationExtension) {
  #    $chebiTermId = $chebiTermIds->{$chebiAnnotationExtension};
   #   $self->userError("chebi annotation extension id  $chebiAnnotationExtension specified but not found in database") unless($chebiTermId);
   # }
    

    my $phenotypeResult = GUS::Model::ApiDB::PhenotypeResult->new({phenotype_quality_term_id => $qualityTermId,
                                                                   phenotype_entity_term_id => $entityTermId,
                                                                   timing => $timing,
                                                                   life_cycle_stage_term_id => $lifeCycleTermId,
                                                                   phenotype_post_composition => $phenotypeString,
                                                                   phenotype_comment => $note,
                                                                   evidence_term_id => $evidenceTermId,
								   chebi_annotation_extension => $chebiAnnotationExtension,
								   protein_annotation_extension => $proteinAnnotationExtension,
                                                                  });

    $phenotypeResult->setParent($phenotypeModel);

    $phenotypeResult->submit();

    $self->undefPointerCache() if $count++ % 500 == 0;
  }

  return "Inserted $count PhenotypeResults";
}


sub lookupModel {
  my ($self, $sourceId, $naFeatureId, $pubmed) = @_;

  foreach my $model(@{$self->{_models}}) {
    if($sourceId && $model->getSourceId() eq $sourceId) {
      return $model;
    }

    if($model->getNaFeatureId() eq $naFeatureId && $model->getPubmedId() eq $pubmed) {
      return $model;
    }
  }

  return undef;
}


 sub queryForOntologyTermIds {
  my ($self) = @_;

  my $dbh = $self->getQueryHandle();
  my $query = "select ontology_term_id, source_id from sres.ontologyterm";

  my $sh = $dbh->prepare($query);
  $sh->execute();

  my %terms;
  while(my ($id, $sourceId) = $sh->fetchrow_array()) {
    $terms{$sourceId} = $id;
  }
  $sh->finish();

  return \%terms;
}
# sub queryForChebiTermIds {
#  my ($self) = @_;

#  my $dbh = $self->getQueryHandle();
#  my $query = "select chebi_accession from chebi.compounds";

#  my $sh = $dbh->prepare($query);
#  $sh->execute();

#  my %terms;
#  while(my ($id) = $sh->fetchrow_array()) {
#      $terms{$id} = $id;
#  }
#  $sh->finish();

#  return \%terms;
#}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.PhenotypeResult','ApiDB.PhenotypeModel');
}

1;
