package ApiCommonData::Load::WorkflowSteps::LoadOrfFile;

@ISA = (GUS::Workflow::WorkflowStepInvoker);

use strict;
use GUS::Workflow::WorkflowStepInvoker;

##to do
##add orf2gusFile = $ENV{GUS_HOME}/config/orf2gus.xml to step prop file
##add soCvsVersion = 2.3 to global prop file
##add <constant name="Tbrucei">Trypanosoma brucei TREU927</constant>

sub run {
  my ($self, $test) = @_;

  my $orfFile = $self->getParamValue('inputFile');
  
  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec');

  my ($extDbName,$extDbRlsVer);

  if ($genomeExtDbRlsSpec =~ /(.+)\|(.+)/) {

      $extDbName = $1;

      $extDbRlsVer = $2

    } else {

      die "Database specifier '$genomeExtDbRlsSpec' is not in 'name|version' format";
  }

  my $substepClass = $self->getParamValue('substepClass');
  
  my $defaultOrg = $self->getParamValue('defaultOrg');

  my $mapFile = $self->getConfig('orf2gusFile');

  my $soCvsVersion = $self->getGlobalConfig('soCvsVersion');


  my $args = <<"EOF";
--extDbName '$extDbName'  \\
--extDbRlsVer '$extDbRlsVer' \\
--mapFile $mapFile \\
--inputFileOrDir $orfFile \\
--fileFormat gff3   \\
--seqSoTerm ORF  \\
--soCvsVersion $soCvsVersion \\
--naSequenceSubclass $substepClass \\
EOF
 if ($defaultOrg){

      $args .= "--defaultOrganism '$defaultOrg'";

    }

  $self->runPlugin("GUS::Supported::Plugin::InsertSequenceFeatures",$args);
}


sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
     ['inputFile', "", ""],
     ['genomeExtDbRlsSpec', "", ""],
     ['substepClass', "", ""],
     ['defaultOrg',"",""],
    );
  return @properties;
}

sub getDocumentation {
}
