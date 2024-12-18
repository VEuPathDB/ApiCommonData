package ApiCommonData::Load::MappingStatsEbi;
use base qw(CBIL::TranscriptExpression::DataMunger::Loadable);

use strict;
use Data::Dumper;

sub getSampleName {$_[0]->{sampleName}}

sub getInputs {$_[0]->{inputs}}
sub getSuffix {$_[0]->{suffix}}
sub getSourceIdPrefix {$_[0]->{sourceIdPrefix}}

sub new {
  my ($class, $args) = @_;

  my $requiredParams = [
                          'sampleName',
                          'inputs',
                          'suffix'
                         ];
  my $self = $class->SUPER::new($args, $requiredParams);


  my $cleanSampleName = $self->getSampleName();
  $cleanSampleName =~ s/\s/_/g;
  $cleanSampleName=~ s/[\(\)]//g;

  $self->setOutputFile($cleanSampleName . "_results_" . $self->getSuffix());

  # Nothing to load for this one
  $self->{doNotLoad} = 1;

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

  my %data;

  open(OUT, "> $outputFile") or die "Cannot open output file $outputFile for writing:$!";

  my $header;

  foreach my $input (@$inputs) {
    my $inputFile = "$input/$suffix";

    open(INPUT, $inputFile) or die "Cannot open input file $inputFile for reading:$!";

    $header = <INPUT>;

    while(<INPUT>) {
      chomp;
      my ($file, @a) = split(/\t/, $_);

      push @{$data{$file}}, \@a;
    }

    close INPUT;
  }

  print OUT $header;
  foreach my $file (keys %data) {

      my @array = @{$data{$file}};

      my @sums = ();
      my $num_rows = scalar @array;

      foreach my $row (@array) {
          for my $col_index (0 .. $#$row) {
              $sums[$col_index] += $row->[$col_index];
          }
      }

      # Compute the average for each column
      my @averages = map { $_ / $num_rows } @sums;

      print OUT "$file\t" . join("\t", @averages) . "\n";
  }

  close OUT;
}


1;
