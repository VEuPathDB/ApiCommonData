package ApiCommonData::Load::Plugin::InsertSnpAffyChip3k;
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
  ['DoTS.IsolateSource', 'One row per chip - strain, origin, source, sequence'],
  ['DoTS.IsolateFeature', 'One row or more per IsolateSource'],
  ['DoTS.ExternalNASequence', 'One row inserted per barcode DoTS.IsolateSource row'] 
];

my $tablesDependedOn = [];

my $howToRestart = "There is currently no restart method.";

my $failureCases = "There are no know failure cases.";

my $notes = <<PLUGIN_NOTES;
Here are the tab file columns:
  SNP ID
	SNP
	SNP
	SNP
	...

	Header: SNP ID, affy_strain, affy_strain ...

  Example SNP id: Pf_01_000101502 T T G G ...
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
    fileArg({ name           => 'metaDataFile',
              descr          => 'file containing the meta data',
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
                     cvsRevision => '$Revision: 1 $', # cvs fills this in!
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

  my $metaDataFile = $self->getArg('metaDataFile');

  open(FILE, $metaDataFile) || $self->error("couldn't open file '$metaDataFile' for reading");

  my %metaHash;

  # open snp meta data file - sample_pops-3k.txt

  my $inputFile = $self->getArg('inputFile');
  open(FILE, $metaDataFile) || $self->error("couldn't open file '$metaDataFile' for reading");
  while(<FILE>) {
    chomp;
    next if /^\s*$/;
    next if /^#/;

    my ($strain, $sequencing, $general, $specific, @others) = split /\t/, $_;
    $metaHash{$strain} = "$sequencing|$general|$specific";
	}

	close(FILE);

  # open snp chip data file
  open(FILE, $inputFile) || $self->error("couldn't open file '$inputFile' for reading");

  my $count = 0;
	my $flag = 0;
	my @chips;
	my @header;

	while(<FILE>) {
    chomp;
    next if /^\s*$/;
    next if /^#/;

		@header = split /\t/, $_ and next if ($_ =~ /^\*\*/ and $flag == 0);
		$flag = 1;

    my @chip = split /\t/, $_; # snp id, A, T ....
    map { s/^$/\./g } @chip;  # substitute empty snp with a dot

		push @chips, \@chip;
	}
	
	close(FILE);

	# now we have template and chip array, transpose: row->column
	my (%snp, %position) = $self->processChipData(\@header, \@chips);

  foreach my $k(keys %metaHash) {
	  my($sequencing, $general, $specific) = split /|/, $metaHash{$k};

    my $objArgs = { strain                       => $k,
                    name                         => $k,  
                    isolate                      => $k,
                    country                      => $specific,
                    collected_by                 => $general,
                    external_database_release_id => $extDbRlsId,
                  };

    my $isolateSource = GUS::Model::DoTS::IsolateSource->new($objArgs);

    # foreach affy chip, find SNP ID#, snp and allele

    my @nuc = split //, $snp{$k};
    my $size = @nuc;
    for(my $i = 0; $i < $size; $i++) {
      my ($species, $chr, $location) = split /_/, $position{$i};

      my $featArgs = { allele                       => $nuc[$i],
                       name                         => $k,
                       map                          => $i,
                       product                      => $nuc[$i],
                       product_alias                => $nuc[$i],
                       external_database_release_id => $extDbRlsId,
                     };
      my $isolateFeature = GUS::Model::DoTS::IsolateFeature->new($featArgs);
      $isolateSource->addChild($isolateFeature);
    }

    my $extNASeq = $self->buildSequence($snp{$k}, $extDbRlsId);

    $extNASeq->addChild($isolateSource);

    $extNASeq->submit();
    $count++;
    $self->log("processed $count") if ($count % 1000) == 0;
		$self->undefPointerCache();
	   
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

sub processChipData {
  my ($self, $header, $chips) = @_;

  my %snp;
  my %position;
	my $size = @$header;

	for(my $i = 0; $i < $size; $i++) {

	  my $strain = $header->[$i];
	  my $seq = '';
		$strain =~ s/affy_//ig;

		my $count = @$chips;  # number of snp id

		for(my $j = 0; $j < $count; $j++) {
		  $seq .= $chips->[$j]->[$i];
		}

		$snp{$strain} = $seq;
	}

  my $count = 0;
	foreach(@$chips) {
	  $position{$count} = $_->[0];
		$count++;
	}

	return (%snp, %position);
}

sub undoTables {
  my ($self) = @_;
  return ('ApiDB.IsolateSource');
}

1;
