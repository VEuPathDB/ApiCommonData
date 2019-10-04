package ApiCommonData::Load::CalculationsForCNVs;

use lib "$ENV{GUS_HOME}/lib/perl";
use strict;
use warnings;
use Statistics::Descriptive;
use CBIL::Util::PropertySet;
use GUS::ObjRelP::DbiDatabase;
use Data::Dumper;

# Common subroutines used by CNV scripts

sub getChrsForCalcs {
    my $taxonId = shift;
    my $chrs = {};
    #get chrs from db
    my $gusConfigFile = $ENV{GUS_HOME}."/config/gus.config";
    die "GUS config file $gusConfigFile does not exist" unless -e $gusConfigFile;
    my @properties = ();
    my $gusConfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);
    my $db = GUS::ObjRelP::DbiDatabase->new($gusConfig->{props}->{dbiDsn},
                                            $gusConfig->{props}->{databaseLogin},
                                            $gusConfig->{props}->{databasePassword},
                                            0,0,1, #verbose, no insert, default
                                            $gusConfig->{props}->{coreSchemaName},
                                            );

    my $dbh = $db->getQueryHandle();
    my $stmt = $dbh->prepare("select ns.source_id
                              from dots.nasequence ns,
                              sres.ontologyterm ot
                              where ot.name = 'chromosome'
                              and ot.ontology_term_id = ns.sequence_ontology_id
                              and ns.taxon_id = $taxonId");
    $stmt->execute();

    while (my @row = $stmt->fetchrow_array()) {
        #use hashref for faster lookup
        $chrs->{$row[0]} = 0;
    }
    $dbh->disconnect();
    return $chrs;
}

sub getGeneInfo  {
    my ($geneFootprintFile, $chrHash) = @_;
    open (FOOTPRINT, $geneFootprintFile) or die "Cannot read file of gene footprints\n$!\n";
    my $chrData = {};
    while (<FOOTPRINT>) {
        my $line = $_;
        chomp ($line);
        next if ($line=~/^PROJECT\t/);
        my @data = split(/\t/, $line);
        die "Bad line count [$geneFootprintFile line $. ".scalar(@data)."\n" unless (scalar(@data)) == 5;
        my ($gene, $length, $chr) = ($data[1], $data[2], $data[3]);
        die "Cannot extract data from $geneFootprintFile line $. \n" unless (defined($gene) && defined($length) && defined($chr));
        if (exists $chrHash->{$chr}) {
            $chrData->{$gene}->{'length'} = $length;
            $chrData->{$gene}->{'chr'} = $chr;
        }
    }
    close FOOTPRINT;
    return $chrData;
}

sub getChrFPKMVals {
    my ($fpkmFile, $chrHash, $geneData) = @_;
    my $chrValues = {};
    open (FPKM, $fpkmFile) or die "Cannot read file of FPKM values $fpkmFile\n$!\n";
    while (<FPKM>) {
        my $line = $_;
        chomp($line);
        next if ($line=~/^tracking_id\t/);
        my @data = split(/\t/, $line);
        my ($gene, $fpkmVal) = ($data[0], $data[1]);
        die "Cannot extract chromosome and FPKM values from $fpkmFile line $.\n" unless (defined($gene) && defined($fpkmVal));
        my $chr;
        if (exists $geneData->{$gene}) {
            $chr = $geneData->{$gene}->{'chr'};
            if (exists $chrHash->{$chr}) {
                push @{$chrValues->{$chr}},$fpkmVal;
            }
        }
    }
    close FPKM;
    return $chrValues;
}

sub getChrMedians {
    my ($chrValues, $chrHash) = @_;
    my $chrMedians = {};
    my $stat = Statistics::Descriptive::Full->new();
    foreach my $chr (keys %{$chrValues}){
        if (exists $chrHash->{$chr}) {
            $stat->clear;
            $stat->add_data(@{$chrValues->{$chr}});
            $chrMedians->{$chr} = $stat->median();
        }
    }
    return $chrMedians;
}

sub getMedianAcrossChrs {
    my ($chrValues, $chrHash) = @_;
    my @medians;
    my $stat = Statistics::Descriptive::Full->new();
    foreach my $chr (keys %{$chrValues}){
        if (exists $chrHash->{$chr}) {
            $stat->clear();
            $stat->add_data(@{$chrValues->{$chr}});
            push @medians, $stat->median();
        }
    }
    $stat->clear();
    $stat->add_data(@medians);
    my $allChrMedian = $stat->median();
    return $allChrMedian;
}

sub getChrPloidies {
    my ($chrMedians, $allChrMedian, $ploidy, $chrHash) = @_;
    my $chrPloidies = {};
    foreach my $chr (keys %{$chrMedians}){
        if (exists $chrHash->{$chr}) {
            if ($allChrMedian == 0){
                print STDERR "Error:Division by 0 - no overall median from chromosom $chr\n";
                $chrPloidies->{$chr} = 0;
                next;
            }
            $chrPloidies->{$chr} = int(($chrMedians->{$chr}/($allChrMedian/$ploidy))+0.5);
            if ($chrPloidies->{$chr} eq 0){
                print STDERR "Error: Chromosome $chr has a predicted ploidy of 0\n";
            }
        }
    }
    return $chrPloidies;
}
1;
