package ApiCommonData::Load::Plugin::Test::TestInsertSequenceFeatures;
use base qw(GUS::PluginMgr::PluginTestCase);

use strict;

use Error qw(:try);

#--------------------------------------------------------------------------------
my $plugin; # InsertSequenceFeatures

my $sqlStatements;

#--------------------------------------------------------------------------------

sub set_up {
  my ($self) = @_;

  # Avoid using the $$row_alg_invoation_id$$ param... (it is just to get you started)
  $sqlStatements = 
    [ ['externalNaSequenceId', 'select na_sequence_id from dots.EXTERNALNASEQUENCE where row_alg_invocation_id = $$row_alg_invocation_id$$'],
      ['geneFeatureCount', 'select count(*) from dots.GENEFEATURE where na_sequence_id = $$externalNaSequenceId$$'],
      ['geneFeatureIds', 'select na_feature_id from dots.GeneFeature where na_sequence_id = $$externalNaSequenceId$$'],
      ['transriptCount', 'select count(*) from dots.TRANSCRIPT where parent_id in ($$geneFeatureIds$$)'],
      ['transcriptIds', 'select na_feature_id from dots.Transcript where parent_id in ($$geneFeatureIds$$)'],
      ['exonFeatureCount', 'select count(*) from dots.EXONFEATURE where parent_id in ($$geneFeatureIds$$)'],
      ['exonFeatureIds', 'select na_feature_id from dots.EXONFEATURE where parent_id in ($$geneFeatureIds$$)'],
      ['splicedNaSequenceIds', 'select na_sequence_id from Dots.Transcript where parent_id in ($$geneFeatureIds$$)'],
      ['splicedNaSequenceCount', 'select count(*) from dots.SPLICEDNASEQUENCE where na_sequence_id in ($$splicedNaSequenceIds$$)'],
      ['rnaFeatureExonCount', 'select count(*) from dots.RNAFEATUREEXON where rna_feature_id in ($$transcriptIds$$)'],
      ['translatedAaFeatureCount', 'select count(*) from Dots.TRANSLATEDAAFEATURE where na_feature_id in ($$transcriptIds$$)'],
      ['translatedAaSequenceIds', 'select aa_sequence_id from Dots.TRANSLATEDAAFEATURE where na_feature_id in ($$transcriptIds$$)'],
      ['translatedAaSequenceCount','select count(*) from Dots.TRANSLATEDAASEQUENCE where aa_sequence_id in ($$translatedAaSequenceIds$$)'],
      ['exonNaLocationCount', 'select count(*) from Dots.NALOCATION where na_feature_id in ($$exonFeatureIds$$)'],
      ['transcriptNaLocationCount', 'select count(*) from Dots.NALOCATION where na_feature_id in ($$transcriptIds$$)'],
      ['geneFeatureNaLocationCount', 'select count(*) from Dots.NALOCATION where na_feature_id in ($$geneFeatureIds$$)'],
    ];



  my $pluginArgs = { extDbName => '',
                     extDbRlsVer =>  '',
                     mapFile => '',
                     inputFileOrDir => '', 
                     fileFormat => '',
                     soCvsVersion => '1.37',
                     organism => "Plasmodium falciparum 3D7",
                     seqSoTerm => "supercontig",
                     handlerExternalDbs => ['enzyme:enzymeDB:2005-11-07'],
                     debug => 0,
                   };

  $self->SUPER::set_up('GUS::Supported::Plugin::InsertSequenceFeatures', $pluginArgs);

  $plugin = $self->getPlugin();
}

# TESTS
#--------------------------------------------------------------------------------

sub test_mitoplay {
  my $self = shift;

  $plugin->setArg('extDbName', "P. falciparum mitochondrial genome");
  $plugin->setArg('extDbRlsVer', '1');
  $plugin->setArg('mapFile', 'mitoplayConfig.xml');
  $plugin->setArg('inputFileOrDir', 'mitoplayISF');
  $plugin->setArg('fileFormat', 'genbank');
  $plugin->run();

  # These are more specific to mitoplay...
 &addStatement('geneFeatureId', 'select na_feature_id from dots.geneFeature where source_id = \'coxI\' and row_alg_invocation_id = $$row_alg_invocation_id$$');
  &addStatement('transcriptId', 'select na_feature_id from dots.transcript where parent_id = $$geneFeatureId$$');
  &addStatement('transcriptProduct', 'select product from dots.transcript where na_feature_id = $$transcriptId$$');
  &addStatement('splicedNaSequenceId', 'select na_sequence_id from dots.transcript where na_feature_id = $$transcriptId$$');
  &addStatement('transcriptSequence', 'select sequence from dots.splicedNaSequence where na_sequence_id = $$splicedNaSequenceId$$');

  # All results
  my %expectedSqlResults = 
    ( externalNaSequenceId => '\d+',
      splicedNaSequenceIds => '.+',
      translatedAaSequenceIds => '.+',
      exonFeatureIds => '.+',
      geneFeatureIds => '.+',
      transcriptIds => '.+',

      geneFeatureCount => 3,
      transriptCount => 3,
      exonFeatureCount => 4,
      splicedNaSequenceCount => 3,
      rnaFeatureExonCount => 4,
      translatedAaFeatureCount => 3,
      translatedAaSequenceCount => 3,
      exonNaLocationCount => 4,
      transcriptNaLocationCount => 3,
      geneFeatureNaLocationCount => 3,

      geneFeatureId => '\d+',
      transcriptId => '\d+',
      transcriptProduct => 'putative cytochrome oxidase I',
      splicedNaSequenceId => '\d+',
      transcriptSequence => '[actgACTG]+', 
    );

  $self->doSqlCheckFromList(\%expectedSqlResults);
}

# UTILS
#--------------------------------------------------------------------------------

sub addStatement {
  my ($key, $sql) = @_;

  push(@$sqlStatements, [$key, $sql]);
}

#--------------------------------------------------------------------------------

sub doSqlCheckFromList {
  my ($self, $expected) = shift;

  my $lines = [];

  foreach(@$sqlStatements) {
    my ($param, $sql) = @$_;

    my $expected = $expected->{$param};
    my $line = [$expected, $sql, $param];

    push(@$lines, $line);
  }

  # This is the method in the superclass which runs the sql tests...
  $self->sqlStatementsTest($lines);
}






1;
