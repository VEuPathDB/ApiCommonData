package ApiCommonData::Load::AlphaDiversityStats;
use base qw(CBIL::TranscriptExpression::DataMunger::Loadable);

use strict;

use List::Util qw/sum /;

sub getSampleName {$_[0]->{sampleName}}

sub getInputs             {$_[0]->{inputs}}
sub getSuffix              {$_[0]->{suffix}}
sub getDataHash        {$_[0]->{dataHash}}
sub getRawCount       {$_[0]->{rawCount}}

sub new {
  my ($class, $args) = @_;

  my $requiredParams = [
                        'sampleName',
                        'inputs',
                        'suffix',
                        'dataHash',
                        'rawCount'
                       ];
  my $self = $class->SUPER::new($args, $requiredParams);

  my $cleanSampleName = $self->getSampleName();
  my $mainDirectory = $self->getMainDirectory();
  my $outputFileBase = $self->getOutputFile();
  mkdir("$mainDirectory/.diversity_stats") unless -d $mainDirectory."/.diversity_stats";
  my $cleanFilePath = ".diversity_stats/".$cleanSampleName . $self->getSuffix();
  $cleanFilePath =~ s/\s/_/;
  $cleanFilePath =~ s/[\(\)]//g;
  $cleanFilePath =~ s/\/\//\//g;

  $self->setOutputFile($cleanFilePath);


  return $self;
}

sub munge {
  my ($self) = @_;
  
  my $inputs = $self->getInputs();
  my $suffix = $self->getSuffix();
  my $sampleName = $self->getSampleName();
  
  my $outputFile = $self->getOutputFile();

  $self->setNames([$sampleName]);
  $self->setFileNames([$outputFile]);
  
  my $dataHash = $self->getDataHash();
  my $rawCount = $self->getRawCount();
  
  my $observed_otus = 0;
  
  print stderr $sampleName."\n";
  print Dumper $dataHash;
  
  my %counts;
  $counts{int (0+$_)}++ for values (%{$dataHash});
  my $singletons = $counts{1};
  my $doubletons = $counts{2};
  my @relativeAbundances = map{ $dataHash->{$_}/$rawCount } keys (%{$dataHash}); 
  
  my $observed_otus = scalar (@relativeAbundances);
  my $chao_1 = $observed_otus + ( ($singletons *($singletons-1))/( 2 * ($doubletons + 1)));
  my $shannon = -1 * sum( map { $_ * (log($_)/log(2))} @relativeAbundances);
  my $simpson = 1 - sum( map { $_ * $_ }  @relativeAbundances);
  
  open(OUT, ">$outputFile") or die "Cannot open output file $outputFile for writing:$!";
  print OUT "ID\tObserved_OTUs\tChao_1\tShannon\tSimpson\n";
  print OUT "$sampleName\t$observed_otus\t$chao_1\t$shannon\t$simpson\n";
  
  close OUT;
  
  $self->setSourceIdType('16s_rrna');
  $self->setInputProtocolAppNodesHash({$sampleName => $inputs});

  $self->createConfigFile();
}

1;
