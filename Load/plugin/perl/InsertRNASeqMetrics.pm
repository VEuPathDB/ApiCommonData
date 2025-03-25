package ApiCommonData::Load::Plugin::InsertRNASeqMetrics;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;
use GUS::PluginMgr::Plugin;
use GUS::Supported::Util;

use GUS::Model::Study::Characteristic;
use GUS::Model::SRes::OntologyTerm;
use GUS::Model::Study::ProtocolAppNode;

use File::Basename;
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
                  from study.protocolappnode pan, study.nodenodeset nns, study.nodeset ns
                  where pan.protocol_app_node_id = nns.protocol_app_node_id
                  and nns.node_set_id = ns.node_set_id
                  and ns.external_database_release_id = $studyExtDbRlsId";

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
      ['average mapping coverage', 'EuPathUserDefined_00501'],
      ['proportion mapped reads', 'EuPathUserDefined_00502'],
      ['number mapped reads', 'EuPathUserDefined_00503'],
      ['average read length', 'EuPathUserDefined_00504'],
      ['unstranded unique average mapping coverage', 'EuPathUserDefined_00505'],
      ['unstranded unique proportion mapped reads', 'EuPathUserDefined_00506'],
      ['unstranded unique number mapped reads', 'EuPathUserDefined_00507'],
      ['unstranded unique average read length', 'EuPathUserDefined_00508'],
      ['unstranded non unique average mapping coverage', 'EuPathUserDefined_00509'],
      ['unstranded non unique proportion mapped reads', 'EuPathUserDefined_00510'],
      ['unstranded non unique number mapped reads', 'EuPathUserDefined_00511'],
      ['unstranded non unique average read length', 'EuPathUserDefined_00512'],
      ['first strand unique average mapping coverage', 'EuPathUserDefined_00513'],
      ['first strand unique proportion mapped reads', 'EuPathUserDefined_00514'],
      ['first strand unique number mapped reads', 'EuPathUserDefined_00515'],
      ['first strand unique average read length', 'EuPathUserDefined_00516'],
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

      my $ontologyTerm = GUS::Model::SRes::OntologyTerm->new({name => $termName,source_id => $termSourceId});
      $ontologyTerm->submit() unless($ontologyTerm->retrieveFromDB());

      $ontologyTerms{$termName} = $ontologyTerm;
    }

#    my @mappingStatsFiles = glob $self->getArg('rnaseqExperimentDirectory') .  "/analyze*/master/mainresult/mappingStats.txt";

    #if no files, check dir structure for EBI RNAseq
    my @mappingStatsFiles = glob $self->getArg('rnaseqExperimentDirectory') . "/results/*/mappingStats.txt";

    $self->error("No mapping stats file found for this dataset\n") unless scalar @mappingStatsFiles > 0;

    foreach my $mappingStats (@mappingStatsFiles) {
      my ($internalSampleName) =  (split "/", dirname($mappingStats))[-1];

      my $protocolAppNodeName;
      if(my ($combinedInternalName) = $internalSampleName =~ /(.+)_combined/) {
        next;
      }

      $protocolAppNodeName = "$internalSampleName (RNASeq)";


      my $protocolAppNode = $protocolAppNodes{$protocolAppNodeName};
      if (! defined $protocolAppNode) {
        $protocolAppNodeName = "$internalSampleName (RNASeq)";
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
