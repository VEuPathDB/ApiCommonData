package ApiCommonData::Load::Plugin::InsertExprProfileFromProcessedResult;
@ISA = qw( GUS::PluginMgr::Plugin);

use strict;

use GUS::PluginMgr::Plugin;
use lib "$ENV{GUS_HOME}/lib/perl";
use ApiCommonData::Load::ExpressionProfileInsertion;
use Data::Dumper;

my $purposeBrief = <<PURPOSEBRIEF;
Insert a processed result from RAD into the easy-to-query Profile tables
PURPOSEBRIEF

my $purpose = <<PLUGIN_PURPOSE;
Insert a processed result from RAD into the easy-to-query Profile tables
PLUGIN_PURPOSE
 
my $tablesAffected =
	[['ApiDB.ProfileSet', ''],
        ['ApiDB.Profile', '']];


my $tablesDependedOn = [['RAD.ShortOligo', '']];


my $howToRestart = <<PLUGIN_RESTART;
There is currently no restart method.
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
There are no known failure cases.
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


my $argsDeclaration = 
  [
   stringArg({name => 'extDbName',
	      descr => 'the external database name with which to find the Study in RAD',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
   stringArg({name => 'extDbRlsVer',
	      descr => 'the version of the external database with which to find the Study in RAD',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
   stringArg({name => 'studyDescrip',
	      descr => 'Displayable description of study (not too long)',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
   stringArg({name => 'arrayDesignName',
	      descr => 'Name of array design as found in RAD.ArrayDesign.name',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
   stringArg({name => 'protocolName',
	      descr => 'Name of protocol as found in RAD.Protocol.name',
	      reqd => 1,
	      constraintFunc => undef,
	      isList => 0,
	     }),
   enumArg({name => 'processingType',
	    descr => 'the type of processing used',
	    reqd => 1,
	    constraintFunc => undef,
	    enum => "RMAExpress, AffymetrixMas5, MOID, DataTransformationResult",
	    isList => 0,
	   }),
   booleanArg({name => 'loadProfileElement',
	       descr => 'load the result values into separate rows in the ProfileElement table',
	       reqd => 0,
	       default => 0
	   }),
   booleanArg({name => 'tolerateMissingIds',
	       descr => "don't fail if an input sourceId is not found in database",
	       reqd => 0,
	       default => 0
	   }),
   booleanArg({name => 'averageReplicates',
	       descr => 'if there are replicate source IDs, average the values',
	       reqd => 0,
	       default => 0
	   }),
   integerArg({ descr          => 'used if the data is logged and you want to UNLOG it.  ex. log2, log10, ...',
                name           => 'baseX',
                isList         => 0,
                reqd           => 0,
                constraintFunc => undef,
              }),
   integerArg({ descr          => '1 or 2 channel data',
                name           => 'numberOfChannels',
                isList         => 0,
                reqd           => 1,
                constraintFunc => undef,
              }),
  ];

sub new {
    my ($class) = @_;
    my $self = {};
    bless($self,$class);

    $self->initialize({requiredDbVersion => 3.5,
		       cvsRevision => '$Revision$', # cvs fills this in!
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

  my $protocolName = $self->getArg('protocolName');
  my $studyDescrip = $self->getArg('studyDescrip');  # hard code for now
  my $arrayDesignName = $self->getArg('arrayDesignName');
  my $loadProfileElement = $self->getArg('loadProfileElement');
  my $tolerateMissingIds = $self->getArg('tolerateMissingIds');
  my $averageReplicates = $self->getArg('averageReplicates');

  my ($studyName, $header) = $self->makeHeader($extDbRlsId, $protocolName);

  my $profileRows = $self->getProfileRows($studyName,$protocolName,
					  $arrayDesignName, $header,
					  $extDbRlsId);

  my $msg = &processInputProfileSet($self, $extDbRlsId, $header, $profileRows,
				    $studyName, $studyDescrip, 'gene',
				    $loadProfileElement, $tolerateMissingIds,
				    $averageReplicates);

  return $msg;

}

sub makeHeader {
  my ($self, $extDbRlsId, $protocolName) = @_;

 # sort by quantification_id to retain the desired order of quants
  my %sqlHash = (
                 '1' => <<Sql,
SELECT s.name, a.name, q.quantification_id
FROM Study.Study s, RAD.Protocol p,
     RAD.StudyAssay sa, RAD.Acquisition ac, 
     Rad.Assay a, RAD.Quantification q
WHERE s.external_database_release_id = ?
  AND p.name = ?
  AND sa.study_id = s.study_id
  AND a.assay_id = sa.assay_id
  AND ac.assay_id = a.assay_id
  AND q.acquisition_id = ac.acquisition_id
  AND q.protocol_id = p.protocol_id
ORDER BY s.name, a.name
Sql
                 '2' => <<Sql,
select distinct s.name, ap.value
from SRes.EXTERNALDATABASERELEASE r, study.STUDY s, Rad.STUDYASSAY sa, Rad.ACQUISITION a,
     Rad.QUANTIFICATION q, Core.TABLEINFO t, Rad.LogicalGroupLink ll,
     Rad.ANALYSISINPUT ai, Rad.ANALYSIS an, Rad.PROTOCOLPARAM pp, 
     Core.DATABASEINFO d, Rad.ANALYSISPARAM ap, Rad.Protocol p
where r.external_database_release_id = ?
 and p.name = ?
 and d.name = 'RAD'
 and t.name = 'Quantification'
 and pp.name = 'Analysis Name'
 and r.external_database_release_id = s.external_database_release_id
 and s.study_id = sa.study_id
 and sa.assay_id = a.assay_id
 and a.acquisition_id = q.acquisition_id
 and q.quantification_id = ll.row_id
 and d.database_id = t.database_id
 and t.table_id = ll.table_id
 and ll.logical_group_id = ai.logical_group_id
 and ai.analysis_id = an.analysis_id
 and an.protocol_id = p.protocol_id
 and p.protocol_id = pp.protocol_id
 and pp.protocol_param_id = ap.protocol_param_id
 and ap.analysis_id = an.analysis_id
ORDER BY s.name, ap.value
Sql
                );

  my $numberOfChannels = $self->getArg('numberOfChannels');
  my $sql = $sqlHash{$numberOfChannels};

  my $dbh = $self->getQueryHandle();
  my $stmt = $dbh->prepare($sql);
  $stmt->execute($extDbRlsId, $protocolName);
  my $studyCount = 0;
  my $prevStudyName = 'pooh';
  my $header = [];
  my ($studyName, $elementName, $dontcare);
  while(($studyName, $elementName, $dontcare) = $stmt->fetchrow_array()) {
    if ($studyName ne $prevStudyName) {
      $studyCount++;
      $self->error("found more than one study: '$prevStudyName' and '$studyName'")
	if $studyCount > 1;
      $prevStudyName = $studyName;
    }
    push(@$header, $elementName);
  }
  $self->error("Couldn't find study for extDbRlsId: $extDbRlsId and protocolName: $protocolName") unless ($studyCount);

  return ($prevStudyName, $header);
}


sub getProfileRows {
  my ($self, $studyName,$protocolName,$arrayDesignName,$header, $extDbRlsId) = @_;

  $self->log("Getting the profile data from database");

  my $resultViewName = $self->getArg('processingType');
  my $resultColumnHash = { RMAExpress => 'RMA_EXPRESSION_MEASURE',
			   AffymetrixMas5 => 'SIGNAL',
                           MOID => '',
                           DataTransformationResult => 'FLOAT_VALUE',
                         };
  my $resultColumn = $resultColumnHash->{$resultViewName};
  $self->error("can't find resultColumn") unless $resultColumn;

  my %sqlHash = (
                 '1' => <<Sql,
SELECT g.source_id, a.name, cer.$resultColumn
FROM Study.Study s, RAD.ArrayDesign ad, RAD.Protocol p,
     RAD.StudyAssay sa, RAD.Assay a, RAD.Acquisition ac, RAD.Quantification q,
     RAD.ShortOligoFamily  ce, RAD.$resultViewName cer,
     DoTS.GeneFeature g, RAD.CompositeElementNaSequence ces,
     DoTS.Transcript t
WHERE s.external_database_release_id = ?
  AND ad.name = ?
  AND p.name = ?
  AND sa.study_id = s.study_id
  AND a.assay_id = sa.assay_id
  AND ac.assay_id = a.assay_id
  AND q.acquisition_id = ac.acquisition_id
  AND q.protocol_id = p.protocol_id
  AND ce.array_design_id = ad.array_design_id
  AND cer.composite_element_id = ce.composite_element_id
  AND cer.quantification_id = q.quantification_id
  AND ce.composite_element_id = ces.composite_element_id
  AND ces.na_sequence_id = t.na_sequence_id
  AND g.na_feature_id = t.parent_id
  ORDER BY g.source_id
Sql
                 '2' => <<Sql,
SELECT distinct gf.source_id, ap.value, cer.$resultColumn
FROM Study.Study s, RAD.StudyAssay sa, RAD.ACQUISITION ac, 
     RAD.QUANTIFICATION q, Core.TABLEINFO ti, Rad.LogicalGroupLink lgl,
     Rad.ANALYSISINPUT ai, Rad.ANALYSIS a, Rad.PROTOCOLPARAM pp, 
     Core.DATABASEINFO di, Rad.ANALYSISPARAM ap, Rad.Protocol p,
     RAD.ArrayDesign ad, RAD.ShortOligoFamily  ce, RAD.$resultViewName cer,
     DoTS.GeneFeature gf, RAD.CompositeElementNaSequence ces, DoTS.Transcript t
WHERE s.external_database_release_id = ?
  AND ad.name = ?
  AND p.name = ?
  and di.name = 'RAD'
  and ti.name = 'Quantification'
  and pp.name = 'Analysis Name'
  and s.study_id = sa.study_id
  and sa.assay_id = ac.assay_id
  and ac.acquisition_id = q.acquisition_id
  and q.quantification_id = lgl.row_id
  and lgl.table_id = ti.table_id
  and ti.database_id = di.database_id
  and lgl.logical_group_id = ai.logical_group_id
  and ai.analysis_id = a.analysis_id
  and a.protocol_id = p.protocol_id
  and p.protocol_id = pp.protocol_id
  and pp.protocol_param_id = ap.protocol_param_id
  and ap.analysis_id = a.analysis_id
  and a.analysis_id = cer.analysis_id
  and ad.array_design_id = ce.array_design_id
  and ce.composite_element_id = cer.row_id
  AND ce.composite_element_id = ces.composite_element_id
  AND ces.na_sequence_id = t.na_sequence_id
  AND gf.na_feature_id = t.parent_id
order by gf.source_id
Sql
                );

  my $numberOfChannels = $self->getArg('numberOfChannels');
  my $sql = $sqlHash{$numberOfChannels};

  my $dbh = $self->getQueryHandle();
  my $stmt = $dbh->prepare($sql);

  $stmt->execute($extDbRlsId, $arrayDesignName, $protocolName);

  # transform individual result rows to a single row with all results for a
  # sourceId
  my $rows = [];
  my $sourceIdRowHash = {};
  my $count = 0;
  my $prevSourceId = "first";

  while(my ($sourceId, $quantName, $result) = $stmt->fetchrow_array()) {
    if ($sourceId ne $prevSourceId && $prevSourceId ne 'first') {
      if ($count++ != 0) {
	my $row = $self->makeSourceIdRow($prevSourceId, $sourceIdRowHash,
					 $header);
	push(@$rows, $row);
      }
      $sourceIdRowHash = {};
    }

    $prevSourceId = $sourceId;
    push(@{$sourceIdRowHash->{$quantName}}, $result);
  }
  my $row = $self->makeSourceIdRow($prevSourceId, $sourceIdRowHash, $header);
  push(@$rows, $row);

  return $rows;
}

sub makeSourceIdRow {
  my ($self, $sourceId, $sourceIdRowHash, $header) = @_;

  my $baseX = $self->getArg('baseX');

  my $row = [$sourceId];
  foreach my $quantName (@$header) {
    my $count = scalar(@{$sourceIdRowHash->{$quantName}});
    my $avg;
    foreach my $val (@{$sourceIdRowHash->{$quantName}}) {

      # Unlog it if the user set the baseX arg
      my $finalValue = $baseX ? $val = $baseX ** $val : $val;

      $avg += $finalValue/$count;
    }
    push(@$row, $avg);
  }
  return $row;
}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.ProfileElement',
	  'ApiDB.Profile',
	  'ApiDB.ProfileElementName',
	  'ApiDB.ProfileSet',
	 );
}


1;
