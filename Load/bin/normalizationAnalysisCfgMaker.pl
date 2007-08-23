#!/usr/bin/perl

use strict;

use RAD::MR_T::MageImport::ServiceFactory;

use Error qw(:try);

use Data::Dumper;

use XML::Simple;
use Getopt::Long;

my ($help, $mageTabFile, $logicalGroupQuantUriMap, $directory, $fileTranslator);

my $RESULT_TABLE = 'RAD::DataTransformationResult';

&GetOptions('help|h' => \$help,
            'mageTab=s' => \$mageTabFile,
            'lg_quant_map=s' => \$logicalGroupQuantUriMap,
            'directory_prefix=s' => \$directory,
            'file_translator=s' => \$fileTranslator,
            );

&usage() if($help);
&usage() unless(-e $mageTabFile && -e $logicalGroupQuantUriMap && -e $fileTranslator);

$directory = "." unless($directory);

my $config = {'service' => {
                            'reader' => {
                                         'class' => 'RAD::MR_T::MageImport::Service::Reader::MageTabReader',
                                         'property' => {
                                                        'mageTabFile' => {
                                                                          'value' => $mageTabFile
                                                                         }
                                                       }
                                        },
                            'processor' => {
                                            'decorProperties' => {
                                                                  'modules' => {
                                                                                'value' => 'NamingAcqAndQuan'
                                                                               }
                                                                 },
                                            'baseClass' => 'RAD::MR_T::MageImport::Service::Processor'
                                           },
                            'translator' => {
                                             'class' => 'ApiCommonData::Load::MageToRadAnalysisTranslator',
                                             'property' => {}
                                            },
                            'validator' => {
                                            'decorProperties' => {
                                                                  'rules' => {
                                                                              'value' => 'AssayHasContact.pm,AssayHasLexAndNoHangingLex.pm,NoHangingBioMaterials.pm,ProtocolHasMgedType.pm,StudyHasContactAndNameAndDescription.pm'
                                                                             }
                                                                 },
                                            'baseClass' => 'RAD::MR_T::MageImport::Service::Validator'
                                           }
                           }
             };


try {
  my $serviceFactory = RAD::MR_T::MageImport::ServiceFactory->new($config);
  my $reader =  $serviceFactory->getServiceByName('reader');

  my $docRoot = $reader->parse();

  if(my $processor = $serviceFactory->getServiceByName('processor')) {
    $processor->process($docRoot);
  }

  my $translator = $serviceFactory->getServiceByName('translator');

  my $quantHash = $translator->mapAll($docRoot);

  my $lgUriHash = &readLogicalGroupMap($logicalGroupQuantUriMap);

  &printXml($quantHash, $lgUriHash);

} catch Error with {
  my $e = shift;
  print $e->stacktrace();
  $e->throw();
};

#--------------------------------------------------------------------------------

sub printXml {
  my ($quantHash, $lgUriHash) = @_;

  my $uriCount = scalar keys %$quantHash;
  my $lgUriCount = scalar keys %$lgUriHash;

  unless($uriCount == $lgUriCount) {
    die "Norm File Count from MageTab [$uriCount] does NOT equal user provided mapping file count [$lgUriCount]\n";
  }

  my $xml = "<plugin>\n";

  foreach my $uri (keys %$quantHash) {
    my $arrayDesign = $quantHash->{$uri}->{array_design};
    my $studyName = $quantHash->{$uri}->{study_name};
    my $protocolName = $quantHash->{$uri}->{protocol_name};
    my $parameterValues = $quantHash->{$uri}->{parameter_values};
    my $quantificationNames = $quantHash->{$uri}->{quantification_names};

    my $name = $lgUriHash->{$uri};
    my $lgName = $name ." quantifications";

    $xml .=  "  <process class=\"GUS::Community::RadAnalysis::Processor::GenericAnalysis\">
    <property name=\"dataFile\" value=\"$directory/$uri\"/>
    <property name=\"fileTranslatorName\" value=\"$directory/$fileTranslator\"/>

    <property name=\"arrayDesignName\" value=\"$arrayDesign\"/>
    <property name=\"studyName\" value=\"$studyName\"/>
    <property name=\"resultView\" value=\"$RESULT_TABLE\"/>
    <property name=\"protocolName\" value=\"$protocolName\"/>     

    <property name=\"paramValues\">
";

    foreach my $parameterValue (@$parameterValues) {
      my $parameterName = $parameterValue->getParameterName();
      my $value = $parameterValue->getValue();

      $xml .= "      <value>$parameterName|$value</value>\n";
    }

    $xml .= "      <value>Analysis Name|$name</value>
    </property>
";

    $xml .= "    <property name=\"quantificationInputs\">\n";

    foreach my $quantName (@$quantificationNames) {
      $xml .= "      <value>$lgName|$quantName</value>\n";
    }

    $xml .= "    </property>
  </process>\n\n";

  }

  $xml .= "</plugin>\n";

  print STDOUT $xml;
}


#--------------------------------------------------------------------------------

sub readLogicalGroupMap {
  my ($fn) = @_;

  my %rv;

  open(FILE, $fn) or die "Cannot open file $fn for reading: $!";

  while(<FILE>) {
    chomp;

    my ($quantUri, $lgName) = split(/\t/, $_);
    $rv{$quantUri} = $lgName;
  }
  close FILE;
  return \%rv;
}

#--------------------------------------------------------------------------------

sub usage {
  my ($e) = @_;

  print STDERR "ERROR:  $e\n" if($e);
  print STDERR "usage:  perl normalizationAnalysisCfgMaker.pl --mageTab <FILE> --lg_quant_map <FILE>\n";
  exit;
}

1;
