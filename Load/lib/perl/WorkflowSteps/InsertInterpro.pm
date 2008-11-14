package ApiCommonData::Load::WorkflowSteps::InsertInterpro;

@ISA = (ApiCommonData::Load::WorkflowSteps::WorkflowStep);

use strict;
use ApiCommonData::Load::WorkflowSteps::WorkflowStep;


sub run {
    my ($self, $test) = @_;

    my $proteinsFile = $self->getParamValue('proteinsFile');
    my $interproExtDbRlsSpec = $self->getParamValue('interproExtDbRlsSpec');
    my $configFileRelativeToDownloadDir = $self->getParamValue('configFileRelativeToDownloadDir');
    
    my ($extDbName,$extDbRlsVer) = $self->getExtDbInfo($interproExtDbRlsSpec);
    my $goVersion = $self->getParamValue('iprscan.goversion');

    my $localDataDir = $self->getLocalDataDir();

    my $resultFileDir = "$localDataDir/$proteinsFile/master/mainresult/";

    my $args = <<"EOF";
--resultFileDir=$resultFileDir \\
--confFile=$configFileRelativeToDownloadDir \\
--extDbName='$extDbName' \\
--extDbRlsVer='$extDbRlsVer' \\
--goVersion=\'$goVersion\' \\
EOF

    $self->runPlugin($test, "ApiCommonData::Load::Plugin::InsertInterproscanResults", $args);
  
}


sub getParamsDeclaration {
    return ('proteinsFile',
            'interproExtDbRlsSpec',
            'configFileRelativeToDownloadDir'
           );
}


sub getConfigDeclaration {
    return (
            # [name, default, description]
           );
}

sub getDocumentation {
}

sub restart {
}

sub undo {
}

