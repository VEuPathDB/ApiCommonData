package ApiCommonData::Load::Plugin::InsertIsolateBarcodeChip;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";
use GUS::PluginMgr::Plugin;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::DoTS::NALocation;
use GUS::Model::DoTS::IsolateSource;
use GUS::Model::DoTS::IsolateFeature;
use GUS::Model::DoTS::SnpFeature;

use Data::Dumper;

my $purposeBrief = <<PURPOSEBRIEF;
Insert Molecular Barcode data from a tab file (converted from Excel format).
PURPOSEBRIEF

my $purpose = <<PURPOSE;
Insert Molecular Barcode data from a tab file (converted from Excel format).
PURPOSE

my $tablesAffected = [
  ['DoTS.IsolateSource', 'One row per barcode - strain, origin, source'],
  ['DoTS.IsolateFeature', 'One row or more per inserted IsolateSource'],
  ['DoTS.NaLocation', 'One row per inserted snp feature'],
  ['DoTS.ExternalNASequence', 'One row inserted per barcode .IsolateSource row'] 
];

my $tablesDependedOn = [
  ['DoTS.SnpFeature', 'Get the na_sequence_id of a chromosome for each snp']
];

my $howToRestart = "There is currently no restart method.";

my $failureCases = "There are no know failure cases.";

my $notes = <<PLUGIN_NOTES;
Here are the tab file columns:
  Strain
  Origin
  Source
  Barcode
  SNPS
  snp_id A T C ...

  Example SNP id: Pf_01_000101502 indicates SNP on contig 1 position 101502.
PLUGIN_NOTES

my $documentation = { purpose          => $purpose,
                      purposeBrief     => $purposeBrief,
                      tablesAffected   => $tablesAffected,
                      tablesDependedOn => $tablesDependedOn,
                      howToRestart     => $howToRestart,
                      failureCases     => $failureCases,
                      notes            => $notes
                    };

my $argsDeclaration = 
  [
    stringArg({name           => 'extDbName',
               descr          => 'the external database name to tag the data with.',
               reqd           => 1,
               constraintFunc => undef,
               isList         => 0,
             }),
    stringArg({name           => 'extDbRlsVer',
               descr          => 'the version of the external database to tag the data with.',
               reqd           => 1,
               constraintFunc => undef,
               isList         => 0,
             }),
    fileArg({ name           => 'inputFile',
              descr          => 'file containing the data',
              constraintFunc => undef,
              reqd           => 1,
              mustExist      => 1,
              isList         => 0,
              format         =>'Tab-delimited.'
           }), 
   ];

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class); 

  $self->initialize({requiredDbVersion => 3.5,
                     cvsRevision => '$Revision: 3 $', # cvs fills this in!
                     name => ref($self),
                     argsDeclaration => $argsDeclaration,
                     documentation => $documentation
                   });
  return $self;
}

sub run {
  my ($self) = @_;
  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbName'),
                                        $self->getArg('extDbRlsVer'));

  die "Couldn't find external_database_release_id" unless $extDbRlsId;

  my $inputFile = $self->getArg('inputFile');

  open(FILE, $inputFile) || $self->error("couldn't open file '$inputFile' for reading");

  my $count = 0;
  my $flag = 0;
  my %metaHash;
  my @snps;

  while(<FILE>) {
    chomp;
    next if /^\s*$/;

    $flag = 0 and next if /^#MetaData/i;

    if($flag == 0) {
      $flag = 1 and next if /^#SNPS/i;
      my($k, @others) = split /\t/, $_;
      $metaHash{$k} = \@others;
    } else {
      my @snp = split /\t/, $_;
      map { s/\s+$// } @snp;  # trim off extra end spaces
      push @snps, \@snp;
    }
  } # end file

  my $size = @{$metaHash{Strain}};
  for(my $i = 0; $i < $size; $i++) {
    my $strain = $metaHash{Strain}->[$i];
    my $origin = $metaHash{Origin}->[$i];
    my $source = $metaHash{Source}->[$i];
    my $barcode = $metaHash{Barcode}->[$i];

    my $objArgs = {
                    strain                       => $strain,
                    name                         => $strain,  
                    isolate                      => $strain,
                    country                      => $origin,
                    collected_by                 => $source,
                    external_database_release_id => $extDbRlsId,
                  };

    my $isolateSource = GUS::Model::DoTS::IsolateSource->new($objArgs);

    # foreach barcode nucleotide, find SNP ID#, major and minor allele

    my $isolateFeature = $self->processIsolateFeature(\@snps, $i+1);

    foreach(@$isolateFeature) {
      my ($snp_id, $allele) = @$_;

      # sample snp_id: Pf_02_000842803
      my ($species, $chr, $location) = split /_/, $snp_id;
      $chr =~ s/^0+//;
      $chr = 'MAL' . $chr;
      $location =~ s/^0+//;

      my $chr_na_seq_id = $self->getNaSeqId($snp_id);  #get na_sequence_id of a chromosome

      my $featArgs = { na_sequence_id               => $chr_na_seq_id, 
                       allele                       => $allele,
                       name                         => $snp_id,
                       source_id                    => $snp_id,
                       external_database_release_id => $extDbRlsId,
                     };

      my $isolateFeature = GUS::Model::DoTS::IsolateFeature->new($featArgs);

      my $naLoc = GUS::Model::DoTS::NALocation->new({'start_min'     => $location,
                                                     'start_max'     => $location,
                                                     'end_min'       => $location,
                                                     'end_max'       => $location,
                                                     'location_type' => 'EXACT'  
                                                    });
      $isolateFeature->addChild($naLoc);
      $isolateSource->addChild($isolateFeature);

    }

    my $extNASeq = $self->buildSequence($barcode, $extDbRlsId);

    $extNASeq->addChild($isolateSource);

    $extNASeq->submit();
    $count++;
    $self->log("processed $count") if ($count % 1000) == 0;

  }

  return "Inserted $count rows.";
}

sub buildSequence {
  my ($self, $seq, $extDbRlsId) = @_;

  my $extNASeq = GUS::Model::DoTS::ExternalNASequence->new();

  $extNASeq->setExternalDatabaseReleaseId($extDbRlsId);
  $extNASeq->setSequence($seq);
  $extNASeq->setSequenceVersion(1);

  return $extNASeq;
}

sub getNaSeqId {
  my ($self, $source_id) = @_;

  my $extNASeq = GUS::Model::DoTS::ExternalNASequence->new();
  my $naSeq = GUS::Model::DoTS::SnpFeature->new({'source_id' => $source_id});

  $naSeq->retrieveFromDB() || self->error("$source_id does not exist in GUS::Model::...");

  my $naSeqId = $naSeq->getNaSequenceId();

  return $naSeqId;
}

sub processIsolateFeature {
  my ($self, $snps, $index) = @_;

  my @isolateFeature;

  foreach my $s (@$snps) {
    push @isolateFeature, [$s->[0], $s->[$index]];
  }

  return \@isolateFeature;
}

sub undoTables {
  my ($self) = @_;
  return ( 'DoTS.IsolateSource',
           'DoTS.IsolateFeature',
           'DoTS.ExternalNASequence',
           'DoTS.NALocation'
         );
}

1;

# a sample file, more strains/columns in real isolate data
=cut *****************************************************
#MetaData			
Strain	3D7	HB3	Dd2
Origin	Netherlands	Honduras	Indochina/Laos
Source	MRA-151	MRA-155	MRA-156
Barcode	CGCTCCGGACTGCACCCAAGATTG	TGCCCCAGATCACAACTAAGATTT	TATCCGAATTTATCAATACAACGT
#SNPS			
Pf_01_000130573	C 	T	T
Pf_01_000539044	G	G	A
Pf_02_000842803	C	C	T
Pf_04_000282592	T	C	C
Pf_05_000931601	C	C	C
Pf_06_000145472	C	C	G
Pf_06_000937750	G	A	A
Pf_07_000277104	G	G	A
Pf_07_000490877	A	A	T
Pf_07_000545046	C	T	T
Pf_07_000657939	T	C	T
Pf_07_000671839	G	A	A
||
