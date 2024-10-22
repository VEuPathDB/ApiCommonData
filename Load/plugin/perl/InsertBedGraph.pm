package ApiCommonData::Load::Plugin::InsertBedGraph;

@ISA = qw(GUS::PluginMgr::Plugin);

use GUS::Model::ApiDB::GenomeBedGraph;
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

    my $fileName = $self->getArg('bedFile');
    my $algorithm = $self->getArg('algorithm');
    my $genomeExternalDatabaseSpec = $self->getArg('extDbRlsSpec');
    my $dbRlsId = $self->getExtDbRlsId("$genomeExternalDatabaseSpec");

    my $rowCount = 0;

    open(my $data, "gzip -dc $fileName |") or die "Can't open file $fileName: $!";

    while (my $line = <$data>) {
	my $rowCount++;
	chomp $line;
	my ($sourceId, $start, $end, $value) = split(/\t/, $line);

	my $row = GUS::Model::ApiDB::GenomeBedGraph->new({SEQUENCE_SOURCE_ID => $sourceId,
							     START_LOCATION => $start,
							     END_LOCATION => $end,
						             VALUE => $value,
                                                             ALGORITHM => $algorithm,
                                                             EXTERNAL_DB_RELEASE_ID => $dbRlsId
						   });
	$row->submit();
	$self->undefPointerCache();
    }

  print "$rowCount rows added.\n";
  close($data);
}

sub undoTables {
    my ($self) = @_;

  return ('ApiDB.GenomeBedGraph'
      );
}

1;
