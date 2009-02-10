package ApiCommonData::Load::WorkflowSteps::InsertInterpro;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
    my ($self, $test, $undo) = @_;

    my $inputDir = $self->getParamValue('inputDir');
    my $interproExtDbRlsSpec = $self->getParamValue('interproExtDbRlsSpec');
    my $configFileRelativeToDownloadDir = $self->getParamValue('configFileRelativeToDownloadDir');
    my $goVersion = $self->getParamValue('goVersion');
    my ($extDbName,$extDbRlsVer) = $self->getExtDbInfo($test,$interproExtDbRlsSpec);
    my $aaSeqTable = 'TranslatedAASequence';

    my $localDataDir = $self->getLocalDataDir();
    my $downloadDir = $self->getGlobalConfig('downloadDir');
  
    my $args = <<"EOF";
--resultFileDir=$localDataDir/$inputDir \\
--confFile=$downloadDir/$configFileRelativeToDownloadDir \\
--aaSeqTable=$aaSeqTable \\
--extDbName='$extDbName' \\
--extDbRlsVer='$extDbRlsVer' \\
--goVersion=\'$goVersion\' \\
EOF

  if ($test) {
    $self->testInputFile('inputDir', "$localDataDir/$inputDir");
  }

    $self->runPlugin($test, $undo, "ApiCommonData::Load::Plugin::InsertInterproscanResults", $args);

}


sub getParamsDeclaration {
    return ('inputDir',
            'interproExtDbRlsSpec',
            'configFileRelativeToDownloadDir'
           );
}


sub getConfigDeclaration {
    return (
            # [name, default, description]
           );
}


