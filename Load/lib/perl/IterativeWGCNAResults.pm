package ApiCommonData::Load::IterativeWGCNAResults;
use base qw(CBIL::TranscriptExpression::DataMunger::Loadable);

use strict;
use CBIL::TranscriptExpression::Error;
use Data::Dumper;
use Exporter;
use File::Basename;

use DBI;
use DBD::Oracle;
use File::Temp qw/ tempfile /;
use Data::Dumper;

use lib "$ENV{GUS_HOME}/lib/perl";
use warnings;
use GUS::ObjRelP::DbiDatabase;

use DBI;
use DBD::Oracle;

sub getStrandness        { $_[0]->{strandness} }
sub getPower        { $_[0]->{softThresholdPower} }
sub getOrganism        { $_[0]->{organismAbbre} }
sub getInputSuffix              { $_[0]->{inputSuffix} }
sub getInputFile              { $_[0]->{inputFile} }

my $PROTOCOL_NAME = 'WGCNA';

#-------------------------------------------------------------------------------
sub new {
  my ($class, $args) = @_; 

  my $mainDirectory = $args->{mainDirectory};
  my $inputfile = $mainDirectory. "/" . $args->{inputFile};
  my $strandness = $args->{strandness};
  my $power = $args->{softThresholdPower};
  my $organism = $args->{organismAbbre};

  $args->{sourceIdType} = "gene";
  my $self = $class->SUPER::new($args) ;          
  
  return $self;
}


sub munge {
    my ($self) = @_;
    my $strandness = $self->getStrandness();
    my $mainDirectory = $self->getMainDirectory();
    my $inputFile = $self->getInputFile();

    #---- FIRST STRAND BEGINS -----------------------------
    if($strandness eq 'firststrand'){

	my $outputDir = "$mainDirectory/FirstStrandResultsForLoading/";
	mkdir($outputDir, 0777) unless(-d $outputDir );

	my %hash;
        open(IN, $inputFile) or die $!;
        while (my $line = <IN>) {
            if ($. == 1){
                next;
            }else{
                chomp($line);
                $line =~ s/\r//g;
                my @all = split/\t/,$line;
		push @{$hash{$all[1]}}, "$all[0]\t$all[2]\n";
            }
        }
        close IN;

	my @files;
        my @modules;
	my @allKeys = keys %hash;
	my @ModuleNames = grep { $_ ne 'UNCLASSIFIED' } @allKeys; 
        for my $i(@ModuleNames){
            push @modules,$i . " " . $self->getInputSuffix();
            push @files,"$i\.txt";
            open(OUT, ">$outputDir/$i\.txt") or die $!;
            print OUT "geneID\tcorrelation_coefficient\n";
            for my $ii(@{$hash{$i}}){
                print OUT $ii;
            }
            close OUT;
        }
    #--------------below--- prepare first strand  %inputProtocolAppNodesHash for loading -----------------------------
	open(DATA, "<", "../Preprocessed_profiles.genes.htseq-union.firststrand.tpm") or die "Couldn't open file for reading, $!";
	my %inputs;
	while (my $line = <DATA>){
            if ($. == 1){
                my @all = split/\t/,$line;
		@all = grep {s/^\s+|\s+$//g; $_ } @all;
                foreach(@all[1 .. $#all]){
                    $inputs{$_} = 1;
                }
            }
        }
        close(DATA);

	my %inputProtocolAppNodesHash;
        foreach my $m (@modules) {
            foreach my $key (keys %inputs)
            {
		my $str = $key . " " . $self->getInputSuffix();
                push @{$inputProtocolAppNodesHash{$m}},  $str;
            }
        }
    #--------------above --- prepare first strand  %inputProtocolAppNodesHash for loading -----------------------------

	$self->setInputProtocolAppNodesHash(\%inputProtocolAppNodesHash);
	$self->setNames(\@modules);                                                                                           
	$self->setFileNames(\@files);
	$self->setProtocolName($PROTOCOL_NAME);
	$self->setSourceIdType("gene");
	$self->createConfigFile();

    }

    #---- SECOND STRAND BEGINS -----------------------------

    if($strandness eq 'secondstrand'){

	my $outputDir = "$mainDirectory/SecondStrandResultsForLoading/";
	mkdir($outputDir, 0777) unless(-d $outputDir );

	my %hash;
        open(IN, $inputFile) or die $!;
        while (my $line = <IN>) {
            if ($. == 1){
                next;
            }else{
                chomp($line);
                $line =~ s/\r//g;
                my @all = split/\t/,$line;
		push @{$hash{$all[1]}}, "$all[0]\t$all[2]\n";
            }
        }
        close IN;

	my @files;
        my @modules;
	my @allKeys = keys %hash;
	my @ModuleNames = grep { $_ ne 'UNCLASSIFIED' } @allKeys; 
        for my $i(@ModuleNames){
            push @modules,$i . " " . $self->getInputSuffix();
            push @files,"$i\.txt";
            open(OUT, ">$outputDir/$i\.txt") or die $!;
            print OUT "geneID\tcorrelation_coefficient\n";
            for my $ii(@{$hash{$i}}){
                print OUT $ii;
            }
            close OUT;
        }
    #--------------below--- prepare second strand  %inputProtocolAppNodesHash for loading -----------------------------
	open(DATA, "<", "../Preprocessed_profiles.genes.htseq-union.secondstrand.tpm") or die "Couldn't open file for reading, $!";
	my %inputs;
	while (my $line = <DATA>){
            if ($. == 1){
                my @all = split/\t/,$line;
		@all = grep {s/^\s+|\s+$//g; $_ } @all;
                foreach(@all[1 .. $#all]){
                    $inputs{$_} = 1;
                }
            }
        }
        close(DATA);

	my %inputProtocolAppNodesHash;
        foreach my $m (@modules) {
            foreach my $key (keys %inputs)
            {
		my $str = $key . " " . $self->getInputSuffix();
                push @{$inputProtocolAppNodesHash{$m}},  $str;
            }
        }
    #--------------above --- prepare second strand  %inputProtocolAppNodesHash for loading -----------------------------

	$self->setInputProtocolAppNodesHash(\%inputProtocolAppNodesHash);
	$self->setNames(\@modules);                                                                                           
	$self->setFileNames(\@files);
	$self->setProtocolName($PROTOCOL_NAME);
	$self->setSourceIdType("gene");
	$self->createConfigFile();

    }

}



1;

