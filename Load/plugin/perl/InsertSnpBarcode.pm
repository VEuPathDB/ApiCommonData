package ApiCommonData::Load::Plugin::InsertSnpBarcode;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";
use GUS::PluginMgr::Plugin;
use GUS::Model::DoTS::ExternalNASequence;
use GUS::Model::DoTS::NALocation;
use GUS::Model::DoTS::IsolateSource;
use GUS::Model::DoTS::IsolateFeature;

use Data::Dumper;

my $purposeBrief = <<PURPOSEBRIEF;
Insert Molecular Barcode data from a tab file (converted from Excel format).
PURPOSEBRIEF

my $purpose = <<PURPOSE;
Insert Molecular Barcode data from a tab file (converted from Excel format).
PURPOSE

my $tablesAffected = [
  ['DoTS.IsolateSource', 'One row per barcode - strain, origin, source'],
  ['DoTS.NALocation', 'One or more rows inserted per barcode DoTS.IsolateSource row'] 
];

my $tablesDependedOn = [];

my $howToRestart = "There is currently no restart method.";

my $failureCases = "There are no know failure cases.";

my $notes = <<PLUGIN_NOTES;
Here are the tab file columns:
  Strain
  Origin
  Source
  Barcode
  Call  (Optional)
  Match (Optional)
  Barcode Details (SNP ID, Possible Alleles, Major Allele, Minor Allele);

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
    booleanArg({name    => 'tolerateMissingIds',
                descr   => "don't fail if an input sourceId is not found in database",
                reqd    => 0,
                default => 0
              }),
    fileArg({ name           => 'inputFile',
              descr          => 'file containing the data',
              constraintFunc => undef,
              reqd           => 1,
              mustExist      => 1,
              isList         => 0,
              format         =>'Tab-delimited.  See ApiDB.MassSpecSummary for columns'
           }), 
   ];

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class); 

  $self->initialize({requiredDbVersion => 3.5,
                     cvsRevision => '$Revision: 0 $', # cvs fills this in!
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
	my @snpFeats;
	my $flag = 0;

  while(<FILE>) {
    chomp;
    next if /^\s*$/;
    push @snpFeats, $_ and next if /^#/;

		my %alleleHash = $self->processAlleles(@snpFeats) if($flag == 0);

		#print Dumper(%alleleHash);

    my ($strain, $origin, $source, $barcode, $call, $match, @snp) = split /\t/, $_;
    map { s/\s+$// } @snp;  # trim off extra spaces

    my $objArgs = {
                    strain                       => $strain,
                    name                         => $strain,  # name for barcode ?
                    isolate                      => $strain,
                    country                      => $origin,
                    collected_by                 => $source,
                    external_database_release_id => $extDbRlsId,
                  };

    my $isolateSource = GUS::Model::DoTS::IsolateSource->new($objArgs);

		# foreach barcode nucleotide, find SNP ID#, major and minor allele

		my @nuc = split //, $barcode;
		for(my $i=0; $i<24; $i++) {
		  my ($name, $possible_allele, $major_allele, $minor_allele) = split /\s/, $alleleHash{$i};
			my ($species, $chr, $location) = split /_/, $name;

			print "#### $name\n";

      my $featArgs = { allele                       => $nuc[$i],
                       name                         => 'dummy name',
                       map                          => $location,
                       external_database_release_id => $extDbRlsId,
                     };
      my $isolateFeature = GUS::Model::DoTS::IsolateFeature->new($featArgs);
      $isolateSource->addChild($isolateFeature);
		}

    my $extNASeq = $self->buildSequence($barcode, $extDbRlsId);

    $extNASeq->addChild($isolateSource);

    $extNASeq->submit();
    $count++;
    $self->log("processed $count") if ($count % 1000) == 0;

		$flag = 1;
  }

  return "Inserted $count rows.";
}

sub buildSequence {
  my ($self, $seq, $extDbRlsId) = @_;

  my $extNASeq = GUS::Model::DoTS::ExternalNASequence->new();

  $extNASeq->setExternalDatabaseReleaseId($extDbRlsId);
  $extNASeq->setSequence($seq);

  return $extNASeq;
}

sub processAlleles {
  my ($self, @lines) = @_;

	# SNP format: SNP ID#,Possible Allels, Major Allele, Minor Allele
	# e.g. Pf_10_000082376  A/T A  T
	my @snps;
	my %hash;
	foreach(@lines) {
	  push @snps, [split /\t/, $_];
	}

	for(my $i=1; $i<25; $i++) {
	  my $j = $i-1;
	  $hash{$j} = $snps[0]->[$i]. ' '. $snps[1]->[$i]. ' '. $snps[2]->[$i]. ' '. $snps[3]->[$i];
	}

  return %hash;
}

sub undoTables {
  my ($self) = @_;
  return ('ApiDB.IsolateSource');
}

1;
