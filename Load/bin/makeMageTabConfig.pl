#!/usr/bin/perl

use XML::Simple;

my $mageTabFile = $ARGV[0];

unless($mageTabFile) {
  print STDERR "usage: makeMageTabConfig.pl <MAGETABFILE>\n";
  exit;
}

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
                                             'class' => 'RAD::MR_T::MageImport::Service::Translator::VoToGusTranslator',
                                             'property' => {
                                                            'allowNewOntologyEntry' => {
                                                                                        'value' => '1'
                                                                                       }
                                                           }
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

print XMLout($config, 'RootName' => 'plugin');

1;
