#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

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
                                                                              'value' => 'AssayHasContact.pm,AssayHasFactorValue.pm,AssayHasLexAndNoHangingLex.pm,NoHangingBioMaterials.pm,StudyHasContactAndNameAndDescription.pm,StudyHasDesignsAndFactors.pm'
                                                                             }
                                                                 },
                                            'baseClass' => 'RAD::MR_T::MageImport::Service::Validator'
                                           }
                           }
             };

print XMLout($config, 'RootName' => 'plugin');

1;
