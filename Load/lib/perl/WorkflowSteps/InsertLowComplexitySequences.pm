package ApiCommonData::Load::WorkflowSteps::LoadLowComplexitySequences;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
  my ($self, $test) = @_;

  my $inputFile = $self->getParamValue('inputFile');

  my $genomeExtDbRlsSpec = $self->getParamValue('genomeExtDbRlsSpec'); 

  my ($extDbName,$extDbRlsVer);

  if ($genomeExtDbRlsSpec =~ /(.+)\|(.+)/) {

      $extDbName = $1;

      $extDbRlsVer = $2

    } else {

      die "Database specifier '$genomeExtDbRlsSpec' is not in 'name|version' format";
  }
  
  my $seqType = $self->getParamValue('seqType'); 

  my $mask = $self->getParamValue('mask');

  my $options = $self->getParamValue('options');

  my $args = "--seqFile $inputFile --fileFormat 'fasta' --extDbName '$extDbName' --extDbVersion '$extDbRlsVer' --seqType $seqType --maskChar $mask $options";
   
  $self->runPlugin("ApiCommonData::Load::Plugin::InsertLowComplexityFeature", $args);
}

sub restart {
}

sub undo {

}

sub getConfigDeclaration {
  my @properties = 
    (
     # [name, default, description]
    );
  return @properties;
}

sub getParamDeclaration {
  my @properties = 
    (
     ['inputFile'],
     ['genomeExtDbRlsSpec'],
     ['mask'],
     ['seqType'],
     ['options'],
    );
  return @properties;
}

sub getDocumentation {
}
1
