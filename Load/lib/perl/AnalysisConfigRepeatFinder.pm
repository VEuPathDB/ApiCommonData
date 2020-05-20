package ApiCommonData::Load::AnalysisConfigRepeatFinder;
use strict;
use warnings;

use CBIL::TranscriptExpression::XmlParser;

use Data::Dumper;

use Tie::IxHash;

use Exporter qw(import);
our @EXPORT_OK = qw(displayAndBaseName);


# JB: Changed this method to return a hash of all samples.  Can distinguish between groups w/ reps by the length of the array
sub displayAndBaseName {
  my ($analysisConfig) = @_;

  my $xmlParser = CBIL::TranscriptExpression::XmlParser->new($analysisConfig);
  my $nodes = $xmlParser->parse();

  my $order = "000";

  my $nodeCount = 1;

  my %rv;
  tie %rv, "Tie::IxHash";

  foreach my $node (@$nodes) {
    my $class = $node->{class};

    next unless($class eq 'ApiCommonData::Load::RnaSeqAnalysis' || $class eq 'ApiCommonData::Load::SpliceSiteAnalysis');

    my $args = $node->{arguments};

    my $samples = $args->{samples};
    my $profileSetName = $args->{profileSetName};

    my ($suffix) = $profileSetName =~ /( - .+)$/;

    next unless($samples);

    my $sampleCount = 1;
    foreach my $groupSample(@$samples) {
      my ($group, $sample) = split(/\|/, $groupSample);

      $sample = $group if (! $sample);  # if group name is not specified; can be used when group has just 1 sample
      my $key = "${nodeCount}_${group}";
      $key =~ s/\s/_/g;
      $key =~ s/;/_/g;

      $order++ unless($rv{$key});

      $rv{$key}->{displayName} = $group . $suffix;

      $rv{$key}->{orderNum} = $order;

      push @{$rv{$key}->{samples}}, $sample;

      $sampleCount++;
    }
    $nodeCount++;
  }

  return \%rv;
}


1;
