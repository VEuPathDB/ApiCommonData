package ApiCommonData::Load::Plugin::InsertBedGraph;

@ISA = qw(GUS::PluginMgr::Plugin);

use GUS::Model::ApiDB::GenomeBedGraph;
use GUS::Model::ApiDB::ProteinBedGraph;
use GUS::PluginMgr::Plugin;
use GUS::Model::SRes::ExternalDatabase;
use GUS::Model::SRes::ExternalDatabaseRelease;
use strict;
# ----------------------------------------------------------------------
my $argsDeclaration =
  [
   fileArg({name           => 'bedFile',
            descr          => 'bed file for the loading',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
            constraintFunc => undef,
            isList         => 0, }),

   stringArg({name           => 'algorithm',
            descr          => 'which software generated the alignments',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),

   stringArg({ name => 'extDbRlsSpec',
                 descr => 'externaldatabase spec to use',
                 constraintFunc => undef,
                 reqd => 1,
                 isList => 0,
               }),

   booleanArg({name => 'isProteinAlignments',
	      descr => 'true if the sequence source_id in the bedgraph file is for proteins',
	      reqd => 0,
	      constraintFunc => undef,
	      isList => 0,
	     }),

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

    my $fileName = $self->getArg('bedFile');
    my $algorithm = $self->getArg('algorithm');
    my $genomeExternalDatabaseSpec = $self->getArg('extDbRlsSpec');
    my $dbRlsId = $self->getExtDbRlsId("$genomeExternalDatabaseSpec");

    my $rowCount = 0;


  my $fh;
  if($fileName =~ /\.gz$/) {
    open($fh, "gzip -dc $fileName |") or die "Can't open file $fileName: $!";
  }
  else {
    open($fh, $fileName) or die "Can't open file $fileName: $!";
  }






    while (my $line = <$fh>) {
	my $rowCount++;
	chomp $line;
	my ($sourceId, $start, $end, $value) = split(/\t/, $line);

  my $row;

  if($self->getArg('isProteinAlignments') {
   $row = GUS::Model::ApiDB::ProteinBedGraph->new({SEQUENCE_SOURCE_ID => $sourceId,
                                                    START_LOCATION => $start,
                                                    END_LOCATION => $end,
                                                    VALUE => $value,
                                                    ALGORITHM => $algorithm,
                                                    EXTERNAL_DB_RELEASE_ID => $dbRlsId
               });
  }
  else {
   $row = GUS::Model::ApiDB::GenomeBedGraph->new({SEQUENCE_SOURCE_ID => $sourceId,
                                                    START_LOCATION => $start,
                                                    END_LOCATION => $end,
                                                    VALUE => $value,
                                                    ALGORITHM => $algorithm,
                                                    EXTERNAL_DB_RELEASE_ID => $dbRlsId
               });
  }

  $row->submit();
	$self->undefPointerCache();
    }

  print "$rowCount rows added.\n";
  close($fh);
}

sub undoTables {
    my ($self) = @_;

  return ('ApiDB.GenomeBedGraph'
      );
}

1;
