package ApiCommonData::Load::Plugin::InsertAntiCodon;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;


use GUS::Model::DoTS::Transcript;
use GUS::Model::DoTS::RNAType;


# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     fileArg({ name => 'data_file',
	       descr => 'text file containing output of tRNAScan',
	       constraintFunc=> undef,
	       reqd  => 1,
	       isList => 0,
	       mustExist => 1,
	       format=>'Text'
	     }),
     stringArg({ name => 'genomeDbName',
		 descr => 'externaldatabase name for genome sequences scanned',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       }),
     stringArg({ name => 'genomeDbVer',
		 descr => 'externaldatabaserelease version used for genome sequences scanned',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0
	       })
    ];

  return $argsDeclaration;
}


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

  my $description = <<DESCR;
Plugin to load anticodon information from a file for tRNA genes existing in the database
DESCR

  my $purpose = <<PURPOSE;
Insert anticodon data from a file to dots.RNAType for tRNA genes already loaded into the database
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Add anticodon data for tRNA genes
PURPOSEBRIEF

  my $notes = <<NOTES;
file of two tab delimited columns, the first column is a source_id and the second column is the anticodon
NOTES

  my $tablesAffected = <<AFFECT;
DoTS.RNAType
AFFECT

  my $tablesDependedOn = <<TABD;
DoTS.Transcript,SRes.ExternalDatabase,SRes.ExternalDatabaseRelease
TABD

  my $howToRestart = <<RESTART;
No restart provided. Undo and re-run.
RESTART

  my $failureCases = <<FAIL;
Will fail if db_id, db_rel_id for the genome scanned is absent 
and when a source_id is not in the DoTS.Transcript table
FAIL

  my $documentation = { purpose          => $purpose,
			purposeBrief     => $purposeBrief,
			tablesAffected   => $tablesAffected,
			tablesDependedOn => $tablesDependedOn,
			howToRestart     => $howToRestart,
			failureCases     => $failureCases,
			notes            => $notes
		      };

  return ($documentation);

}


sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  my $configuration = { requiredDbVersion => 3.5,
			cvsRevision => '$Revision$',
			name => ref($self),
			argsDeclaration => $args,
			documentation => $documentation
		      };

  $self->initialize($configuration);

  return $self;
}

sub run {
  my $self = shift;

  my $genomeReleaseId = $self->getExtDbRlsId($self->getArg('genomeDbName'),$self->getArg('genomeDbVer')) || $self->error("Can't find db_rel_id for genome");

  my $tRNAs = $self->parseFile();

  my $result = $self->insertAnticodon($genomeReleaseId,$tRNAs);

  return "$result anticodons added to dots.RNAType";
}

sub parseFile {
  my ($self) = @_;

  my $dataFile = $self->getArg('data_file');

  open(FILE,$dataFile) || $self->error("$dataFile can't be opened for reading");

  my %tRNAs;

  while(<FILE>){
    chomp;

    next if $_ =~ /^\s+$/;

    my @line = split(/\t/,$_);

    my $transcriptSourceId = $line[0] || $self->error("File is missing a source_id or is not formatted properly");

    my $anticodon = $line[1] || $self->error("File is missing an anticodon for $transcriptSourceId or is not formatted properly");

    $tRNAs{$transcriptSourceId} = $anticodon;
  }

  return \%tRNAs;
}

sub  insertAnticodon {
  my ($self,$genomeReleaseId,$tRNAs) = @_;

  my $processed;

  foreach my $transcriptSourceId (keys %{$tRNAs}) {
    my $transcript = $self->getTranscript($genomeReleaseId,$transcriptSourceId);

    next if (!$transcript);

    my $rnaType = $self->getTranscript($tRNAs->{$transcriptSourceId});

    $transcript->addChild($rnaType);

    $transcript->submit();

    $self->undefPointerCache();

    $processed++;
  }

  return $processed;
}

sub getTranscript {
  my ($self,$genomeReleaseId,$transcriptSourceId) = @_;

  my $transcript =  GUS::Model::DoTS::Transcript->new({'external_database_release_id' => $genomeReleaseId,
					     'source_id' => $transcriptSourceId });
  my $exist = $transcript->retrieveFromDB() || $self->log("No transcript row exists for $transcriptSourceId and db_rel_id = $genomeReleaseId");

  return $transcript if ($exist);
}

sub getRNAType {
  my ($self,$anticodon) = @_;

  my $rnaType = GUS::Model::DoTS::RNAType->new({'anticodon' => $anticodon,
						'name' => "auxiliary info"});

  return $rnaType;
}

sub undoTables {
  return qw(DoTS.RNAType
           );
}
