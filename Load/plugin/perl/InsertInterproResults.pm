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

   stringArg({name           => 'transcriptSourceId',
            descr          => 'Transcript Source ID',
            reqd           => 0,
            constraintFunc => undef,
            isList         => 0, }),

   stringArg({name           => 'geneSourceId',
            descr          => 'Gene Source ID',
            reqd           => 0,
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

 my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
 my $genomeExtDbRlsSpec = $self->getArg('genomeExtDbRlsSpec');
 
 my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);
 my $genomeExtDbRlsId = $self->getExtDbRlsId($genomeExtDbRlsSpec);

 my $fileName = $self->getArg('resultsFile');
 my $rowCount = 0;

 my $dbh = $self->getQueryHandle();

 my $transcriptSourceId = $self->getArg('transcriptSourceId');
 my $geneSourceId = $self->getArg('geneSourceId');
 my $ncbiTaxId = $self->getArg('ncbiTaxId');

 open(my $data, '<', $fileName) || die "Could not open file $fileName: $!";
 while (my $line = <$data>) {
     my $rowCount++;
     chomp $line;
     my ($proteinSourceId, $seqMd5Digest, $seqLen, $interproDbName, $interproFamilyId, $analysisDesc, $interproStartMin, $interproEndMin, $interproEValue, $status, $date, $interproPrimaryId, $interproDescription) = split(/\t/, $line);
     my $row = GUS::Model::ApiDB::Indel->new({	  TRANSCRIPT_SOURCE_ID => $transcriptSourceId,
						  PROTEIN_SOURCE_ID => $proteinSourceId,
						  GENE_SOURCE_ID => $geneSourceId,
						  NCBI_TAX_ID => $ncbiTaxId,
						  INTERPRO_DB_NAME => $interproDbName,
						  INTERPRO_PRIMARY_ID => $interproPrimaryId,
						  INTERPRO_SECONDARY_ID => ,
						  INTERPRO_DESC => $interproDescription,
						  INTERPRO_START_MIN => $interproStartMin,
						  INTERPRO_END_MIN => $interproEndMin,
						  INTERPRO_E_VALUE => $interproEValue,
						  INTERPRO_FAMILY_ID => $interproFamilyId
					     });
     $row->submit();
 }
 print "$rowCount rows added.\n"
}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.InterproResults'
     );
}

1;
