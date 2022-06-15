package ApiCommonData::Load::Plugin::InsertUserDatasetAttributes;

@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use GUS::Model::ApidbUserDatasets::DatasetAttributes;

use JSON;

use Data::Dumper;

sub getArgsDeclaration {
my $argsDeclaration  =
[


 integerArg({  name           => 'userDatasetId',
	       descr          => 'For use with Schema=ApidbUserDatasets; this is the user_dataset_id',
	       reqd           => 0,
	       constraintFunc => undef,
	       isList         => 0 }),


   fileArg({name           => 'metadataFile',
            descr          => 'json file which has the metadata for this study',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
            constraintFunc => undef,
            isList         => 0, }),

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
  bless($self, $class);

  my $documentation = &getDocumentation();

  my $args = &getArgsDeclaration();

  my $configuration = {requiredDbVersion => 4.0,
		       cvsRevision => '$Revision: 24153 $',
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

  my $userDatasetId = $self->getArg("userDatasetId");

  my @studyStableIds = $self->sqlAsArray(Sql => "select stable_id from ApidbUserDatasets.study where USER_DATASET_ID = $userDatasetId");
  unless(scalar(@studyStableIds) == 1) {
    $self->error("User Dataset $userDatasetId must return exactly one row in ApidbUserDatasets.Study");
  }

  my $metadataFile = $self->getArg('metadataFile');

  my $json = do {
   open(META, $metadataFile) or $self->error("Can't open \"$metadataFile\" for reading: $!");
   local $/;
   <META>
  };


  my $metadata = decode_json($json);

  my $datasetStableId = "EDAUD_${userDatasetId}";

  my $datasetAttributes = GUS::Model::ApidbUserDatasets::DatasetAttributes->new({user_dataset_id => $userDatasetId,
                                                                            study_stable_id => $studyStableIds[0],
                                                                            dataset_stable_id => $datasetStableId,
                                                                            name => $metadata->{name},
                                                                            description => $metadata->{description},
                                                                           });

  $datasetAttributes->submit();


  
  return("Inserted 1 row into ApidbUserDatasets.DatasetAttributes");
}


1;
