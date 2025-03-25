package ApiCommonData::Load::Plugin::InsertInterproResults;

@ISA = qw(GUS::PluginMgr::Plugin);

use GUS::Model::ApiDB::InterproResults;
use GUS::PluginMgr::Plugin;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
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

   stringArg({ name => 'extDbRlsSpec',
                 descr => 'externaldatabase spec to use',
                 constraintFunc => undef,
                 reqd => 1,
                 isList => 0,
               })
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

 my $externalDatabaseSpec = $self->getArg('extDbRlsSpec');
 my $dbRlsId = $self->getExtDbRlsId("$externalDatabaseSpec");

 my %proteinToTranscript;
 my %proteinToGene;

 my $sourceSql = "select gf.source_id as geneId, t.source_id as transcriptId, aas.source_id as proteinId from dots.genefeature gf, dots.transcript t, dots.translatedaafeature taf, dots.translatedaasequence aas where t.parent_id = gf.na_feature_id and t.na_feature_id = taf.na_feature_id and gf.external_database_release_id = '$dbRlsId' and taf.aa_sequence_id = aas.aa_sequence_id";
 my $stmt = $dbh->prepareAndExecute($sourceSql);
 while(my ($geneId, $transcriptId, $proteinId) = $stmt->fetchrow_array()) {
     $proteinToTranscript{$proteinId} = $transcriptId;
     $proteinToGene{$proteinId} = $geneId;
 }

 open(my $data, '<', $fileName) || die "Could not open file $fileName: $!";
 while (my $line = <$data>) {
     my $rowCount++;
     chomp $line;
     my ($proteinSourceId, $seqMd5Digest, $seqLen, $interproDbName, $interproPrimaryId, $analysisDesc, $interproStartMin, $interproEndMin, $interproEValue, $status, $date, $interproFamilyId, $interproDescription) = split(/\t/, $line);

     next if ($interproEValue eq "-");  ##temporarily fix in order to let the plugin run

     my $transcriptSourceId = $proteinToTranscript{$proteinSourceId};
     my $geneSourceId = $proteinToGene{$proteinSourceId};
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

sub undoTables {
  my ($self) = @_;

  return ('ApiDB.InterproResults'
     );
}

1;
