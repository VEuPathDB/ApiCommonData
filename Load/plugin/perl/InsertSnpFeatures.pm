package ApiCommonData::Load::Plugin::InsertSnpFeatures;

@ISA = qw(GUS::PluginMgr::Plugin);

# ----------------------------------------------------------------------

use strict;

use Data::Dumper;

use GUS::PluginMgr::Plugin;
use GUS::PluginMgr::PluginUtilities;
use GUS::PluginMgr::PluginUtilities::ConstraintFunction;

use ApiCommonData::Load::VariationFileReader;
use ApiCommonData::Load::SnpUtils  qw(snpFileColumnNames);

use GUS::Model::SRes::OntologyTerm;

use GUS::Model::DoTS::NALocation;
use GUS::Model::DoTS::SnpFeature;
use GUS::Model::Results::SeqVariation;
use GUS::Model::Study::Study;
use GUS::Model::Study::StudyLink;
use GUS::Model::Study::ProtocolAppNode;

my $argsDeclaration =
[

 fileArg({name           => 'variationFile',
	  descr          => 'tab file of variations (sqlldr format for loading into Apidb SNP tables',
	  reqd           => 1,
	  mustExist      => 1,
	  format         => 'tab del',
	  constraintFunc => undef,
	  isList         => 0, 
	 }),

 fileArg({name           => 'snpFile',
	  descr          => 'tab file of snps (sqlldr format for loading into Apidb SNP tables',
	  reqd           => 1,
	  mustExist      => 1,
	  format         => 'tab del',
	  constraintFunc => undef,
	  isList         => 0, 
	 }),


 stringArg({ name => 'snpExtDbRlsSpec',
	     descr => 'Extenral Database Release Name|Version for the Study',
	     isList    => 0,
	     reqd  => 1,
	     constraintFunc => undef,
	   }),


 stringArg({ name => 'soExtDbSpec',
	     descr => 'SequenceOntology ExternalDatabase Release Spec for SRes.OntologyTerm Table',
	     isList    => 0,
	     reqd  => 1,
	     constraintFunc => undef,
	   }),

 stringArg({ name => 'ontologyTerm',
	     descr => 'SequenceOntology ExternalDatabase Release Spec for SRes.OntologyTerm Table',
	     isList    => 0,
	     reqd  => 1,
	     constraintFunc => undef,
	   }),


];

my $purpose = <<PURPOSE;
Load SNPs and Variations into DoTS tables
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Load SNPs and Variations into DoTS tables
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
DoTS::SnpFeature, Results::SeqVariation
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
SRes::ExternalDatabase, SRes::ExternalDatabaseRelease, DoTS::NASequence, SRes::OntologyTerm
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
No Restart utilities for this plugin.
RESTART

my $failureCases = <<FAIL_CASES;
FAIL_CASES

my $documentation = { purpose          => $purpose,
		      purposeBrief     => $purposeBrief,
		      notes            => $notes,
		      tablesAffected   => $tablesAffected,
		      tablesDependedOn => $tablesDependedOn,
		      howToRestart     => $howToRestart,
		      failureCases     => $failureCases };

my $featuresLoaded = 0;

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 4.0,
		      cvsRevision       => '$Revision$',
		      name              => ref($self),
		      argsDeclaration   => $argsDeclaration,
		      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
  my ($self) = @_;


  my $snpExtDbRlsSpec = $self->getArg('snpExtDbRlsSpec');
  my $snpExtDbRlsId = $self->getExtDbRlsId($snpExtDbRlsSpec);

  $self->{_study} = GUS::Model::Study::Study->new({name => $snpExtDbRlsSpec,
                                                   external_database_release_id => $snpExtDbRlsId
                                                  });

  my $soExtDbRlsId = $self->getExtDbRlsId($self->getArg('soExtDbSpec'));
  my $ontologyTerm = GUS::Model::SRes::OntologyTerm->new({name => $self->getArg('ontologyTerm'),
                                                          external_database_release_id => $soExtDbRlsId
                                                         });

  unless($ontologyTerm->retrieveFromDB()) {
    $self->userError("OntologyTerm ($ontologyTerm) not found");
  }

  my $ontologyTermId = $ontologyTerm->getId();


  my $variationOntologyTerm = GUS::Model::SRes::OntologyTerm->new({name => 'substitution',
                                                                   external_database_release_id => $soExtDbRlsId
                                                                  });

  unless($variationOntologyTerm->retrieveFromDB()) {
    $self->userError("OntologyTerm (substitution) not found");
  }

  my $variationOntologyTermId = $variationOntologyTerm->getId();

  my $variationFile = $self->getArg('variationFile');
  my $snpFile = $self->getArg('snpFile');

  my $variationFileReader = ApiCommonData::Load::VariationFileReader->new($variationFile, undef, "\t");

  open(SNP, $snpFile) or die "Cannot open snp file $snpFile for reading: $!";

  my $snpColumnNames = &snpFileColumnNames();

  my ($snpCount, $variationCount);

  while(<SNP>) {
    chomp;

    my @a = split(/\t/, $_, -1);

    unless(scalar @a == scalar @$snpColumnNames) {
      $self->error("Expected number of columns in snpFeature file differes from found");
    }

    my %snpAttributes;

    for(my $i = 0; $i < scalar @a; $i++) {
      $snpAttributes{$snpColumnNames->[$i]} = $a[$i];
    }

    my $variations = $variationFileReader->nextSNP();

    $self->load(\%snpAttributes, $variations, $ontologyTermId, $variationOntologyTermId);

    $variationCount += scalar @$variations;
    if($snpCount++ % 1000 == 0) {
      $self->log("Inserted $snpCount SNP Features and $variationCount variations...");
    }


    $self->undefPointerCache();
  }

  return("Inserted $snpCount SNPs and $variationCount variations");
}

sub load {
  my ($self, $snpAttributes, $variations, $ontologyTermId, $variationOntologyTermId) = @_;

  unless($snpAttributes->{location} == $variations->[0]->{location} && 
         $snpAttributes->{na_sequence_id} == $variations->[0]->{na_sequence_id}) {

    $self->error("snp position doesn't match variations");
  }


  my $snpFeature = GUS::Model::DoTS::SnpFeature->new({na_sequence_id => $snpAttributes->{na_sequence_id},
                                                      name => $self->getArg('ontologyTerm'),
                                                      sequence_ontology_id => $ontologyTermId,
                                                      parent_id => $snpAttributes->{gene_na_feature_id},
                                                      external_database_release_id => $snpAttributes->{external_database_release_id},
                                                      source_id => $snpAttributes->{source_id},
                                                      reference_na => $snpAttributes->{reference_na},
                                                      reference_strain => $snpAttributes->{reference_strain},
                                                      reference_aa => $snpAttributes->{reference_aa},
                                                      major_allele => $snpAttributes->{major_allele},
                                                      major_product => $snpAttributes->{major_product},
                                                      minor_allele => $snpAttributes->{minor_allele},
                                                      minor_product => $snpAttributes->{minor_product},
                                                      is_coding => $snpAttributes->{position_in_cds} ? 1 : 0,
                                                      position_in_cds => $snpAttributes->{position_in_cds},
                                                      position_in_protein => $snpAttributes->{position_in_protein},
                                                      minor_allele_count => $snpAttributes->{minor_allele_count},
                                                      major_allele_count => $snpAttributes->{major_allele_count},
                                                      has_nonsynonymous_allele => $snpAttributes->{has_nonsynonymous_allele},
                                                      is_coding => $snpAttributes->{is_coding},
                                                      positions_in_cds_full => $snpAttributes->{positions_in_cds},
                                                      positions_in_protein_full => $snpAttributes->{positions_in_protein},
                                                      reference_aa_full => $snpAttributes->{reference_aa_full},
                                                     });



  my $naLocation = GUS::Model::DoTS::NALocation->new({start_min => $snpAttributes->{location},
                                                      end_max => $snpAttributes->{location},
                                                      is_reversed => 0
                                                     });

  $naLocation->setParent($snpFeature);

  foreach my $variation (@$variations) {

    my $protocolAppNodeId = $self->getProtocolAppNodeId($variation->{strain});

    my $seqVariation = GUS::Model::Results::SeqVariation->new({
                                                            sequence_ontology_id => $variationOntologyTermId, 
                                                            strain => $variation->{strain},
                                                            product => $variation->{product},
                                                            products_full => $variation->{products},
                                                            allele => $variation->{base},
                                                            matches_reference => $variation->{matches_reference},
                                                            protocol_app_node_id => $protocolAppNodeId,
                                                            diff_from_adjacent_snp => $variation->{diff_from_adjacent},
                                                           });



    $seqVariation->setParent($snpFeature);
  }


  $snpFeature->submit();
}


sub getProtocolAppNodeId {
  my ($self, $strain) = @_;

  if($self->{_protocol_app_node_ids}->{$strain}) {
    return $self->{_protocol_app_node_ids}->{$strain};
  }

  my $study = $self->{_study};
  my $panName = "$strain (Sequence Variations)";

  my $pan = GUS::Model::Study::ProtocolAppNode->new({name => $panName });
  my $link = GUS::Model::Study::StudyLink->new();

  $link->setParent($study);
  $link->setParent($pan);

  $study->submit();

  $self->{_protocol_app_node_ids}->{$strain} = $pan->getId();

  return $pan->getId();
}

sub undoTables {
  my ($self) = @_;

  return ('DoTS.NALocation',
          'Results.SeqVariation',
          'DoTS.SnpFeature',
          'Study.StudyLink',
          'Study.ProtocolAppNode',
          'Study.Study',
      );
}


1;
