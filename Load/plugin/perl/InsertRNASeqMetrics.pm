package ApiCommonData::Load::Plugin::InsertRNASeqMetrics;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;
use GUS::PluginMgr::Plugin;
use GUS::Supported::Util;

use GUS::Model::Study::Characteristic;
use GUS::Model::SRes::OntologyTerm;
use GUS::Model::Study::ProtocolAppNode;

use Data::Dumper;

my $argsDeclaration = [
    
    fileArg({name   => 'rnaseqExperimentDirectory',
        descr    => 'rnaseq experiment directory containing analysis directories for each sample file',
        reqd    => 1,
        mustExist   => 1,
        format  =>  'Path to dir',
        constraintFunc  => undef,
        isList  => 0,
        }),

    stringArg({name => 'studyExtDbRlsSpec',
          descr => 'External Database Release Spec for the study',
          constraintFunc=> undef,
          reqd  => 1,
          isList => 0
         }),

];

my $purpose = <<PURPOSE;
Insert quality metrics (average coverage and percentage mapped reads) from RNAseq datasets
PURPOSE

my $purposeBrief = <<PURPOSE_BRIEF;
Insert quality metrics from RNAseq datasets
PURPOSE_BRIEF

my $notes = <<NOTES;
NOTES

my $tablesAffected = <<TABLES_AFFECTED;
Study.Characteristic
TABLES_AFFECTED

my $tablesDependedOn = <<TABLES_DEPENDED_ON;
Study.Study
TABLES_DEPENDED_ON

my $howToRestart = <<RESTART;
This plugin cannot be restarted
RESTART

my $failureCases = <<FAIL_CASES;
FAIL_CASES

my $documentation = { purpose          => $purpose,
		      purposeBrief     => $purposeBrief,
		      notes            => $notes,
		      tablesAffected   => $tablesAffected,
		      tablesDependedOn => $tablesDependedOn,
		      howToRestart     => $howToRestart,
		      failureCases     => $failureCases };

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

sub run {
    my ($self) = @_;

    my $charCount=0;

    my $studyExtDbRlsSpec = $self->getArg('studyExtDbRlsSpec');
    my $studyExtDbRlsId = $self->getExtDbRlsId($studyExtDbRlsSpec);

    my $panSql = "select pan.name, pan.protocol_app_node_id 
                  from study.protocolappnode pan, study.studylink sl, study.study s 
                  where pan.protocol_app_node_id = sl.protocol_app_node_id 
                  and sl.study_id = s.study_id
                  and s.external_database_release_id = $studyExtDbRlsId";

    my $dbh = $self->getQueryHandle();
    my $sh = $dbh->prepare($panSql);
    $sh->execute();

    my %protocolAppNodes;
    while(my ($panName, $panId) = $sh->fetchrow_array()) {
      my $pan = GUS::Model::Study::ProtocolAppNode->new({protocol_app_node_id => $panId});
      $pan->retrieveFromDB();

      $protocolAppNodes{$panName} = $pan;
      $self->undefPointerCache();
    }


    my @userDefinedOntologyTerms = (
      ['average mapping coverage', 'EUPATH_0000454'],
      ['proportion mapped reads', 'EUPATH_0000455'],
      ['number mapped reads', 'EUPATH_0000456'],
      ['average read length', 'EUPATH_0000457'],
      ['unstranded unique average mapping coverage', 'EUPATH_0000458'],
      ['unstranded unique proportion mapped reads', 'EUPATH_0000459'],
      ['unstranded unique number mapped reads', 'EUPATH_0000460'],
      ['unstranded unique average read length', 'EUPATH_0000461'],
      ['unstranded non unique average mapping coverage', 'EUPATH_0000462'],
      ['unstranded non unique proportion mapped reads', 'EUPATH_0000463'],
      ['unstranded non unique number mapped reads', 'EUPATH_0000464'],
      ['unstranded non unique average read length', 'EUPATH_0000465'],
      ['first strand unique average mapping coverage', 'EUPATH_0000466'],
      ['first strand unique proportion mapped reads', 'EUPATH_0000467'],
      ['first strand unique number mapped reads', 'EUPATH_0000468'],
      ['first strand unique average read length', 'EUPATH_0000469'],
      ['first strand non unique average mapping coverage', 'EuPathUserDefined_00517'],
      ['first strand non unique proportion mapped reads', 'EuPathUserDefined_00518'],
      ['first strand non unique number mapped reads', 'EuPathUserDefined_00519'],
      ['first strand non unique average read length', 'EuPathUserDefined_00520'],
      ['second strand unique average mapping coverage', 'EuPathUserDefined_00521'],
      ['second strand unique proportion mapped reads', 'EuPathUserDefined_00522'],
      ['second strand unique number mapped reads', 'EuPathUserDefined_00523'],
      ['second strand unique average read length', 'EuPathUserDefined_00524'],
      ['second strand non unique average mapping coverage', 'EuPathUserDefined_00525'],
      ['second strand non unique proportion mapped reads', 'EuPathUserDefined_00526'],
      ['second strand non unique number mapped reads', 'EuPathUserDefined_00527'],
      ['second strand non unique average read length', 'EuPathUserDefined_00528']
        );

    my %ontologyTerms;
    foreach my $a (@userDefinedOntologyTerms) {
      my $termName = $a->[0];
      my $termSourceId = $a->[1];

      my $ontologyTerm = GUS::Model::SRes::OntologyTerm->new({source_id => $termSourceId});
      unless($ontologyTerm->retrieveFromDB()) {
        $self->error("Ontology Term $termName (source ID $termSourceId) not found in database");
      }

      $ontologyTerms{$termName} = $ontologyTerm;
    }

    my @mappingStatsFiles = glob $self->getArg('rnaseqExperimentDirectory') .  "/analyze*/master/mainresult/mappingStats.txt";

    #if no files, check dir structure for EBI RNAseq
    @mappingStatsFiles = scalar @mappingStatsFiles == 0 ? glob $self->getArg('rnaseqExperimentDirectory') . "/*RR*/mappingStats.txt" : @mappingStatsFiles;

    foreach my $mappingStats (@mappingStatsFiles) {
      my ($internalSampleName) = $mappingStats =~ /analyze_(.+)\/master\/mainresult/;
      ($internalSampleName) = defined $internalSampleName ? $internalSampleName : $mappingStats =~ /([D|E|S]RR.+)\//;


      my $protocolAppNodeName;
      if(my ($combinedInternalName) = $internalSampleName =~ /(.+)_combined/) {
        next;
      }

      $protocolAppNodeName = "$internalSampleName (RNASeq)";


      my $protocolAppNode = $protocolAppNodes{$protocolAppNodeName};
      if (! defined $protocolAppNode) {
        $protocolAppNodeName = "$internalSampleName (RNASeqEbi)";
        $protocolAppNode = $protocolAppNodes{$protocolAppNodeName};
      }
      $self->error("Could not find protocolappnode row for name:  $protocolAppNodeName") unless($protocolAppNode);


      open(FILE, $mappingStats) or $self->error("could not open file $mappingStats for reading:  $!");

      <FILE>;
      while(<FILE>) {
        chomp;
        my @v = split(/\t/, $_);

        my $bamFile = shift @v;

        my ($alignerType, $strandType);

        if($bamFile =~ /unique/) {

          if($bamFile =~ /non_unique/) {
            $alignerType = 'non unique';
          }
          else {
            $alignerType = 'unique';
          }


          if($bamFile =~ /firststrand/) {
            $strandType = 'first strand';
          }
          elsif($bamFile =~ /secondstrand/) {
            $strandType = 'second strand';
          }
          else {
            $strandType = 'unstranded';
          }
        }

        #coverage     mapped      number_reads_mapped      avg_read_length
        my @charTypes = ('average mapping coverage',
                         'proportion mapped reads', 
                         'number mapped reads',
                         'average read length'
            );

        for(my $i = 0; $i < scalar @charTypes; $i++) {
          my $charType = $charTypes[$i];
          $charType = "$alignerType $charType" if($alignerType);
          $charType = "$strandType $charType" if($strandType);


          my $qualifierOntologyTerm = $ontologyTerms{$charType};
          $self->error("No OntologyTerm object found for term $charType") unless($qualifierOntologyTerm);


          my $charValue = $v[$i];

          next unless($charValue);

          my $char = GUS::Model::Study::Characteristic->new({value => $charValue,
                                                             qualifier_id => $qualifierOntologyTerm->getId()});
          $char->setParent($protocolAppNode);
          $char->submit();
          $charCount++;
        }
      }
      
      close FILE;

      $self->undefPointerCache();
    }


    return "Added $charCount Characteristics";
}


sub undoTables {
  my ($self) = @_;

  return ( 
    'Study.Characteristic',
     );
}


1;
