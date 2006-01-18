package ApiCommonData::Load::Plugin::InsertVirtualSequenceFromMapping;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use GUS::Model::DoTS::ExternalNASequence;

use GUS::Model::DoTS::VirtualSequence;
use GUS::Model::DoTS::SequencePiece;

use GUS::Model::SRes::SequenceOntology;

use Bio::PrimarySeq;

sub getArgsDeclaration {
my $argsDeclaration  =
[

fileArg({name => 'mappingInput',
         descr => 'text file containing map of scaffolds to chromosomes',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         mustExist => 1,
         format=>'Text'
        }),

stringArg({name => 'sourceExtDbRlsName',
       descr => 'External database from whence the data file you are loading came (original source of data)',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'sourceExtDbRlsVer',
       descr => 'Version of external database from whence the data file you are loading came (original source of data)',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'extDbRlsName',
       descr => 'External database from whence the data file you are loading came (original source of data)',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'extDbRlsVer',
       descr => 'Version of external database from whence the data file you are loading came (original source of data)',
       constraintFunc=> undef,
       reqd  => 1,
       isList => 0
      }),

stringArg({name => 'virtualSeqSOTerm',
       descr => 'SO term describing the newly built virtual sequences',
       constraintFunc=> undef,
       reqd  => 0,
       isList => 0,
       default => "chromosome",
      }),

];

return $argsDeclaration;
}


# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

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

  my $configuration = {requiredDbVersion => 3.5,
		       cvsRevision => '$Revision$',
		       cvsTag => '$Name$',
		       name => ref($self),
		       revisionNotes => '',
		       argsDeclaration => $args,
		       documentation => $documentation
		      };

  $self->initialize($configuration);

  return $self;
}


sub run {
  my $self = shift;

  my $dbh = $self->getDbHandle();
  $dbh->{'LongReadLen'} = 10_000_000;

  $dbh = $self->getQueryHandle();
  $dbh->{'LongReadLen'} = 10_000_000;

  my $sourceDbName = $self->getArg('sourceExtDbRlsName');
  my $sourceDbVer = $self->getArg('sourceExtDbRlsVer');

  my $sourceDbRlsId = $self->getExtDbRlsId($sourceDbName, $sourceDbVer)
    or die "Couldn't find source db: $sourceDbName, $sourceDbVer\n";

  my $extDbName = $self->getArg('extDbRlsName');
  my $extDbVer = $self->getArg('extDbRlsVer');

  my $extDbRlsId = $self->getExtDbRlsId($extDbName, $extDbVer)
    or die "Couldn't find source db: $extDbName, $extDbVer\n";

  my $SOTermArg = $self->getArg("virtualSeqSOTerm");

  my $SOTerm = GUS::Model::SRes::SequenceOntology->new({ term_name => $SOTermArg });
  unless($SOTerm->retrieveFromDB()) {
    die "SO Term $SOTermArg not found in database.\n";
  }
  my $SOTermId = $SOTerm->getId();

  my $file = $self->getArg('mappingInput');

  my %virtuals;

  open(FILE, "<$file") or die "Couldn't open file '$file':\n$@";

  my $taxonId;

  while (<FILE>) {
    next if (m/^#/ || m/^\s*$/);
    my ($target, $sourceId, $orientation, $orderedBy, $orientedBy) = split(" ", $_);

    my $sourceSeq = GUS::Model::DoTS::ExternalNASequence->new({ source_id => $sourceId,
								external_database_release_id => $sourceDbRlsId,
							      });

    unless($sourceSeq->retrieveFromDB()) {
      die "sequence not in Dots.ExternalNASequence: $sourceId";
    }

    $taxonId = $sourceSeq->getTaxonId(); # TODO: implement checking to make sure this is consistent.

    push @{$virtuals{$target}}, [ $sourceSeq, $orientation, $orderedBy, $orientedBy ];
  }
  close(FILE);

my $count = 0;

  while (my ($target, $seqs) = each %virtuals) {
    my $virtualSeq = GUS::Model::DoTS::VirtualSequence->new({ external_database_release_id => $extDbRlsId,
							      sequence_version             => 1,
							      sequence_ontology_id         => $SOTermId,
							      taxon_id => $taxonId,
							      source_id => $target,
							    });
    $virtualSeq->submit();

    my $seq = "";
    my $seqOrder = 0;
    my $offset = 1;

    my $virtSeqId =  $virtualSeq->getId();

    for my $piece (@$seqs) {
      my ($sourceSeq, $orientation, $orderedBy, $orientedBy) = @$piece;
      $seqOrder++;
      my $sourceSeqId = $sourceSeq->getId();
      my $seqPiece = GUS::Model::DoTS::SequencePiece->new({ piece_na_sequence_id   => $sourceSeqId,
							    virtual_na_sequence_id => $virtSeqId,
							    sequence_order         => $seqOrder,
							    strand_orientation     => $orientation,
							    distance_from_left     => 0, # number of N's
							                                 # between this and
							                                 # last piece
							  });
      $seqPiece->submit();

      my $pieceSeq = $sourceSeq->getSequence();

      if ($orientation == -1) {
        $pieceSeq = Bio::PrimarySeq->new(-seq => $pieceSeq)->revcom->seq();
      }

      # TODO: implement option for inserting spacing between elements
      # (e.g. "NNNNN...");

      $seq .= $pieceSeq;
      $offset = $offset + length($pieceSeq);
    }

    $virtualSeq->setSequence($seq);
    $virtualSeq->setLength(length($seq));

    $virtualSeq->submit();


    $count ++;
    $self->log("Processed $count Virtual Sequence(s)");
  }

my $msg = "Successfully created $count virtual sequence(s)\n";

return $msg;
}

sub undoTables {
  my ($self) = @_;

  return ('DoTS.SequencePiece',
	  'DoTS.VirtualSequence'
	 );
}

return 1;

__DATA__
#Example data this plugin parses:

#Chr     Scaff   Orientation     Anchored        Oriented

Ia      994723  +1              G               G
Ia      994726  -1              G               G

Ib      995280  +1              G               G
Ib      995334  -1              G               G

II      994725  0               G               NA
II      995348  +1              B               B
II      995337  -1              B               B
II      994740  -1              G               G
II      995360  -1              G               G

