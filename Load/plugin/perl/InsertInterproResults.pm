package ApiCommonData::Load::Plugin::InsertInterproResults;

@ISA = qw(GUS::PluginMgr::Plugin);

use GUS::Model::ApiDB::InterproResults;
use GUS::PluginMgr::Plugin;
use strict;
# ----------------------------------------------------------------------
my $argsDeclaration =
  [
   fileArg({name           => 'resultsFile',
            descr          => 'file for the sample data',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
            constraintFunc => undef,
            isList         => 0, }),

   stringArg({name           => 'ncbiTaxId',
            descr          => 'NCBI Taxon Id of Organism',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),

  ];

my $documentation = { purpose          => "",
                      purposeBrief     => "",
                      notes            => "",
                      tablesAffected   => "",
                      tablesDependedOn => "",
                      howToRestart     => "",
                      failureCases     => "" };

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

 my $fileName = $self->getArg('resultsFile');
 my $rowCount = 0;

 my $dbh = $self->getQueryHandle();
 my $ncbiTaxId = $self->getArg('ncbiTaxId');

 open(my $data, '<', $fileName) || die "Could not open file $fileName: $!";
 while (my $line = <$data>) {
     my $rowCount++;
     chomp $line;
     my ($proteinSourceId, $seqMd5Digest, $seqLen, $interproDbName, $interproPrimaryId, $analysisDesc, $interproStartMin, $interproEndMin, $interproEValue, $status, $date, $interproFamilyId, $interproDescription) = split(/\t/, $line);
     my $naFeatureId = &getNaFeatureId($proteinSourceId,$dbh);
     my $transcriptSourceId = &getTranscript($naFeatureId,$dbh);
     my $geneSourceId = &getGene($naFeatureId,$dbh);
     my $row = GUS::Model::ApiDB::InterproResults->new({TRANSCRIPT_SOURCE_ID => $transcriptSourceId,
						  PROTEIN_SOURCE_ID => $proteinSourceId,
						  GENE_SOURCE_ID => $geneSourceId,
						  NCBI_TAX_ID => $ncbiTaxId,
						  INTERPRO_DB_NAME => $interproDbName,
						  INTERPRO_PRIMARY_ID => $interproPrimaryId,
# TODO: add back if we get the short name						  INTERPRO_SECONDARY_ID => $interproPrimaryId,
						  INTERPRO_DESC => $analysisDesc,
						  INTERPRO_START_MIN => $interproStartMin,
						  INTERPRO_END_MIN => $interproEndMin,
						  INTERPRO_E_VALUE => $interproEValue,
						  INTERPRO_FAMILY_ID => $interproFamilyId
					     });
         $row->submit();
         $self->undefPointerCache();
 }
 print "$rowCount rows added.\n"
}

sub getNaFeatureId {
  my ($proteinSourceId,$dbh) = @_;
  my $sql = "SELECT na_feature_id FROM dots.translatedaafeature WHERE source_id = '$proteinSourceId'";
  my $stmt = $dbh->prepareAndExecute($sql);
  my @naFeatureIdArray = $stmt->fetchrow_array();
  return $naFeatureIdArray[0];
}

sub getTranscript {
  my ($naFeatureId,$dbh) = @_;
  my $sql = "select source_id from dots.transcript where na_feature_id = $naFeatureId";
  my $stmt = $dbh->prepareAndExecute($sql);
  my @transcriptArray = $stmt->fetchrow_array();
  return $transcriptArray[0];
}
 
sub getGene {
  my ($naFeatureId,$dbh) = @_;
  my $sql = "select source_id from dots.genefeature where na_feature_id = $naFeatureId";
  my $stmt = $dbh->prepareAndExecute($sql);
  my @geneArray = $stmt->fetchrow_array();
  return $geneArray[0];
}

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.InterproResults'
     );
}

1;
