package ApiCommonData::Load::Plugin::InsertNAFeaturePhenotype;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

use GUS::Model::ApiDB::NAFeaturePhenotype;

use GUS::Model::Study::ProtocolAppNode;
use GUS::Model::Study::StudyLink;
use GUS::Model::Study::Study;

use GUS::Model::SRes::OntologyTerm;

use GUS::Supported::Util;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     fileArg({ name => 'file',
         descr => 'tab delimited file',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0,
         mustExist => 1,
         format => 'PAN_NAME,PAN_URI,GENE_SOURCE_ID,[characteristic1, ...]',
       }),
     stringArg({ name => 'extDbName',
         descr => 'externaldatabase name that this dataset references',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0
       }),
     stringArg({ name => 'extDbVer',
         descr => 'externaldatabaserelease version of the extDb that this dataset references',
         constraintFunc=> undef,
         reqd  => 1,
         isList => 0
       }),

    ];

  return $argsDeclaration;
}

# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

  my $description = <<DESCR;
DESCR

  my $purpose = <<PURPOSE;
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB.NAFeaturePhenotype,Study.Study,Study.ProtocolAppNode
AFFECT

  my $tablesDependedOn = <<TABD;
DoTS.NAFeature,SRes.ExternalDatabaseRelease,Sres.OntologyTerm
TABD

  my $howToRestart = <<RESTART;
No restart provided. Must undo and reload.
RESTART

  my $failureCases = <<FAIL;
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

  my $configuration = { requiredDbVersion => 4.0,
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

  my $extDbName = $self->getArg('extDbName');

  my $extDbReleaseId = $self->getExtDbRlsId($extDbName, $self->getArg('extDbVer')) || $self->error("Can't find external_database_release_id for this data");

  my $orderNum = 1;

  my $fn =  $self->getArg('file');

  open(FILE, $fn) or die "Cannot open file $fn for reading: $!" ;

  my $header = <FILE>;
  chomp $header;

  my ($h1, $h2, $h3, @properties) = split(/\t/, $header);

  my $study = GUS::Model::Study::Study->new({name => $extDbName, 
                                            external_database_release_id => $extDbReleaseId
                                            });


  $study->submit();

  my $panType = GUS::Model::SRes::OntologyTerm->new({source_id => 'EFO_0000651'});
  unless($panType->retrieveFromDB()) {
    $self->error("Could not retrieve ontologyterm:  source_id EFO_0000651");
  }

  while(<FILE>) {
    chomp;

    my($panName, $panUri, $sourceId, @values) = split /\t/, $_;

    my %hash;
    for(my $i = 0; $i < scalar @properties; $i++) {
      my $key = $properties[$i];
      my $value = $values[$i];

      $hash{$key} = $value if(defined $value);
    }

    my $naFeatureId = GUS::Supported::Util::getNaFeatureIdsFromSourceId($self, $sourceId, "Transcript");

    unless($naFeatureId) {
      $naFeatureId = GUS::Supported::Util::getGeneFeatureId($self, $sourceId);
    }

    print "could not find $sourceId\n" and next unless $naFeatureId;


    my $pan = GUS::Model::Study::ProtocolAppNode->new({name => $panName,
                                                       uri => $panUri,
                                                       type_id => $panType->getId(),
                                                       'external_database_release_id' => $extDbReleaseId,
                                                       'NODE_ORDER_NUM' => $orderNum,
                                                      });

    my $sl = GUS::Model::Study::StudyLink->new({});
    $sl->setParent($pan);
    $sl->setParent($study);

    foreach my $property (keys %hash) {
      # TODO:  add function to check if property and value are ontologyterms; cache results

      my @values = split(/\|/, $hash{$property});

      foreach my $value (@values) {
        my $naFeaturePhenotype = GUS::Model::ApiDB::NAFeaturePhenotype->new({property => $property, 
                                                                             na_feature_id => $naFeatureId,
                                                                             value => $value,
                                                                            });

        # TODO:  deal with very large > 4000 char phenotype descriptions??

        $naFeaturePhenotype->setParent($pan);
      }
    }

    $pan->submit();
    $self->undefPointerCache();
    $orderNum++;
  }

  return "$orderNum data lines parsed and loaded";
}

sub undoTables {
  return('ApiDB.NAFeaturePhenotype',
         'Study.STUDYLINK',
         'Study.ProtocolAppNode',
         'Study.Study'
      );
}

1;
