package ApiCommonData::Load::Plugin::InsertProductionDatasets;
use LWP::UserAgent;
use Data::Dumper;
use JSON; 

@ISA = qw(GUS::PluginMgr::Plugin);

use GUS::Model::ApiDB::ProductionDataset;

# ----------------------------------------------------------------------

use strict;
use GUS::PluginMgr::Plugin;

my $argsDeclaration =
  [
   stringArg({name           => 'projectName',
            descr          => 'file for the sample data',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
            constraintFunc => undef,
            isList         => 0, }),
   
   stringArg({name           => 'extDbRlsSpec',
            descr          => 'External Database Spec for this study',
            reqd           => 1,
            constraintFunc => undef,
            isList         => 0, }),

  ];


my $documentation = { purpose          => "",
                      purposeBrief     => "",
                      notes            => "Make sure to enter the projectName argument how it appears on the project homepage:  TriTrypDB or VectorBase, for example.",
                      tablesAffected   => "ApiDB.ProductionDatasets",
                      tablesDependedOn => "",
                      howToRestart     => "",
                      failureCases     => "" };

# ----------------------------------------------------------------------

sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);

    $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision       => '1',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
			documentation     => $documentation});

    return $self;
}

# ======================================================================

sub run {
    my ($self) = @_;

    my $extDbRlsSpec = $self->getArg('extDbRlsSpec');
 
    my $extDbRlsId = $self->getExtDbRlsId($extDbRlsSpec);
 
    my $projectName = $self->getArg('projectName');
    my $ua = LWP::UserAgent->new;
    my $request = $ua->get("https://$projectName.org/a/service/record-types/dataset/searches/AllDatasets/reports/standard?reportConfig=%7B%22attributes%22%3A%5B%22primary_key%22%5D%2C%22tables%22%3A%5B%22Version%22%5D%7D%22", Accept => "application/json" );
    my $data = decode_json($request->content);
    my $rowCount = 0;
    foreach my $record (@{ $data->{records}}){
	my @references = (@{ $record->{tables}->{Version}});
	foreach my $reference (@references){
	    my $datasetName = $reference->{'dataset_name'};
	    if ($datasetName ne undef) {
		my $row = GUS::Model::ApiDB::ProductionDataset->new({dataset_name => $datasetName,
                                                              project_name => $projectName,
                                               external_database_release_id => $extDbRlsId,
								});
		$row->submit();
		$rowCount++; 
	    }
	}
    }
    return ("Added $rowCount rows.");
} 
# unless($study->retrieveFromDB()) {
#   $study->submit();
#   return("Loaded 1 file. File with name $fileName.")
# }
#
# return("Study.Study with name $fileName and extDbRlsSpec $extDbRlsSpec already exists. Nothing was loaded");

sub undoTables {
    my ($self) = @_;

  return ('ApiDB.ProductionDataset'
      );
}

1;
