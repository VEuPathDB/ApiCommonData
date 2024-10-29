package ApiCommonData::Load::Plugin::InsertExportPredFeature;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use Bio::Tools::GFF;

use GUS::Model::DoTS::DomainFeature;
use GUS::Model::DoTS::AALocation;

my $argsDeclaration = 
  [
   fileArg({ name           => 'inputFile',
	     descr          => 'exportpred output in gff format',
	     reqd           => 1,
	     mustExist      => 1,
	     format         => 'custom',
	     constraintFunc => undef,
	     isList         => 0,
	   }),

   stringArg({name => 'seqTable',
	      descr => 'where do we find the proteins',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),

   stringArg({name => 'seqExtDbRlsSpec',
	      descr => 'where do we find source_id\'s for the proteins',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),
 
   stringArg({name => 'extDbRlsSpec',
	      descr => 'External database release specification for this dataset',
	      constraintFunc => undef,
	      reqd => 1,
	      isList => 0
	     }),
 
  ];

my $purposeBrief = <<PURPOSEBRIEF;
PURPOSEBRIEF
    
my $purpose = <<PLUGIN_PURPOSE;
PLUGIN_PURPOSE

my $tablesAffected = <<TABLES_AFFECTED;
TABLES_AFFECTED

my $tablesDependedOn = [];

my $howToRestart = <<PLUGIN_RESTART;
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
PLUGIN_NOTES

my $documentation = { purpose=>$purpose,
		      purposeBrief=>$purposeBrief,
		      tablesAffected=>$tablesAffected,
		      tablesDependedOn=>$tablesDependedOn,
		      howToRestart=>$howToRestart,
		      failureCases=>$failureCases,
		      notes=>$notes
		    };

sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);

    $self->initialize({requiredDbVersion => 4.0,
		       cvsRevision => '$Revision$', # cvs fills this in!
		       name => ref($self),
		       argsDeclaration => $argsDeclaration,
		       documentation => $documentation
		      });

    return $self;
}

sub run {

  my ($self) = @_;

  my $file = $self->getArg('inputFile');

  open(my $fh, "gzip -dc $file |") or die "Could not open '$file': $!";
  my $gffIo = Bio::Tools::GFF->new(-fh => $fh, -gff_version => 3);

  my $extDbRlsId = $self->getExtDbRlsId($self->getArg('extDbRlsSpec'));
  my $seqExtDbRlsId = $self->getExtDbRlsId($self->getArg('seqExtDbRlsSpec'));

  my $seqTable = $self->getArg('seqTable');
  my $seqTableId = $self->className2TableId($seqTable);
  $seqTable = "GUS::Model::$seqTable";

  open(IN, "<$file") or $self->error("Couldn't open file '$file': $!\n");

  my $count = 0;
  while (my $feature = $gffIo->next_feature()) {
    my $primaryTag = $feature->primary_tag();

    # only load the top features
    next unless($primaryTag eq 'RLE' || $primaryTag eq 'KLD');

    my $proteinSourceId = $feature->seq_id();
    my $score = $feature->score();

    my ($aaSeqId, $length) = $self->_getSeqInfo($proteinSourceId, $seqTable, $seqExtDbRlsId);

    my $domain =
        GUS::Model::DoTS::DomainFeature->new({ aa_sequence_id               => $aaSeqId,
                                               is_predicted                 => 1,
                                               external_database_release_id => $extDbRlsId,
                                               name                         => "exported protein $primaryTag",
                                               algorithm_name               => "exportpred",
                                               score                        => $score,
                                             });

    my $location = GUS::Model::DoTS::AALocation->new({ start_min => 1,
                                                       start_max => 1,
                                                       end_min   => $length,
                                                       end_max   => $length,
                                                     });
    $domain->addChild($location);

    $domain->submit();

    $self->undefPointerCache();
    
    $count++;
  }
  close(IN);

  return "done (inserted $count exportpred predictions)";
}

sub _getSeqInfo {

  my ($self, $sourceId, $tableName, $extDbRlsId) = @_;

  return @{ $self->{_seqIdCache}->{$tableName}->{$extDbRlsId}->{$sourceId}
            ||= do {
              eval "require $tableName"; $self->error($@) if $@;

              my $seq = $tableName->new({ source_id => $sourceId,
                                          external_database_release_id => $extDbRlsId,
                                        });
              unless ($seq->retrieveFromDB()) {
                $self->error("Couldn't find a $tableName with id of $sourceId");
              }
              [$seq->getId(), $seq->getLength()];
            }
      };
}

sub undoTables {
  return qw( DoTS.AALocation
             DoTS.DomainFeature
      );
}

1;
