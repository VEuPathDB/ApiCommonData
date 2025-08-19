#!/usr/bin/perl

use warnings;
use strict;
use Data::Dumper;
use lib "$ENV{GUS_HOME}/lib/perl";
use GUS::Supported::GusConfig;
use GUS::ObjRelP::DbiDatabase;
use CBIL::Util::PropertySet;
use DBI;

my $outputFile = $ARGV[0];
my $gusConfigFile = $ARGV[1];

$gusConfigFile = "$ENV{GUS_HOME}/config/gus.config" unless ($gusConfigFile);
my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $verbose;
my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
                                        $gusconfig->getDatabaseLogin(),
                                        $gusconfig->getDatabasePassword(),
                                        $verbose,0,1,
                                        $gusconfig->getCoreSchemaName()
                                       );

my $dbh = $db->getQueryHandle();

open (OUT, ">$outputFile") || die "can not open $outputFile to write\n";

# Get all groups
my @groups = @{ &getGroups($dbh) };

my $counter = 0;

# For every group
foreach my $groupId (@groups) {
    
    $counter += 1;

    if ($counter % 1000 == 0) {
        print "$counter groups processed...\n";
    }

    # Get all proteins from that group with an EC assignment
    my %proteinToEc = %{ &getProteinToEC($dbh,$groupId) };

    # Get all proteins that have a significant hit to the group centroid. Note, this is stored as the absolute log of the evalue.
    my %proteinToEValue = %{ &getProteinToEValue($dbh,$groupId) };

    my %ecBestEvalue;
    my %processedProteins;

    # For every EC assignment in this group, record the best blast evalue to the centroid
    # For each protein  
    foreach my $protein (keys %proteinToEc) {
        # This protein gets a score of 4, as it is assigned this EC
        print OUT "$protein\t$proteinToEc{$protein}\t4\n";
        # If we already have an protein with this EC, and it has a significant blast to the centroid
        if ($ecBestEvalue{$proteinToEc{$protein}} && $proteinToEValue{$protein}) {
            if ($ecBestEvalue{$proteinToEc{$protein}} < $proteinToEValue{$protein}) {
                $ecBestEvalue{$proteinToEc{$protein}} = $proteinToEValue{$protein};
            }
        }
        # Another protein assigned this EC, but doesn't have a significant blast hit with the centroid
        elsif ($ecBestEvalue{$proteinToEc{$protein}} && !$proteinToEValue{$protein}) {
            next;
        }
        # First protein with this EC, and it has a significant blast value to the centroid
        elsif (!$ecBestEvalue{$proteinToEc{$protein}} && $proteinToEValue{$protein}) {
            $ecBestEvalue{$proteinToEc{$protein}} = $proteinToEValue{$protein};
        }
        # First protein with this EC, and it does not have a significant blast value to the centroid
        else {
            $ecBestEvalue{$proteinToEc{$protein}} = 5;
        }
        # Keeps track of which proteins we have already scored (4 as they have this EC assigned)
	$processedProteins{$protein} = 1;
    }

    # For every protein in the group that has a significant blast hit to the centroid, we assign a score (if it had an EC assignment, it already got a 4)
    foreach my $protein (keys %proteinToEValue) {
        # We have already assigned this a 4
        next if ($processedProteins{$protein});
        # It already cannot get a score of 1
        next if (!$proteinToEValue{$protein});
        next if ($proteinToEValue{$protein} < 10);
        # For every EC
        foreach my $ec (keys %ecBestEvalue) {        
            # If the protein to centroid blast was > 100
            if ($proteinToEValue{$protein} > 100) {
                # And the best blast to the centroid for all proteins with this EC was > 100
                if ($ecBestEvalue{$ec} > 100) {
                    # This protein EC combo scores a 3
                    print OUT "$protein\t$ec\t3\n";
                }
                # If the the best blast to the centroid for all proteins with this EC was > 50
                elsif ($ecBestEvalue{$ec} > 50) {
                    # This protein EC combo scores a 2
                    print OUT "$protein\t$ec\t2\n";
                }
                # If the the best blast to the centroid for all proteins with this EC was > 10
                elsif ($ecBestEvalue{$ec} >= 10) {
                    # This protein EC combo scores a 1
                    print OUT "$protein\t$ec\t1\n";
                }
            }
            # Same process for this but this protein EC combo can only score a max of a 2
            elsif ($proteinToEValue{$protein} > 50) {
                if ($ecBestEvalue{$ec} > 50) {
                    print OUT "$protein\t$ec\t2\n";
                }
                elsif ($ecBestEvalue{$ec} >= 10) {
                    print OUT "$protein\t$ec\t1\n";
                }
            }
            # Same process for this but this protein EC combo can only score a max of a 1
            elsif ($proteinToEValue{$protein} >= 10) {
                if ($ecBestEvalue{$ec} >= 10) {
                    print OUT "$protein\t$ec\t1\n";
                }
            }
        }
    }
}

close OUT;

sub getGroups {
    my ($dbh) = @_;
    my $sql = "SELECT DISTINCT(group_name) FROM webready.proteinsequencegroup";
    my $sh = $dbh->prepare($sql);
    $sh->execute();
    while(my ($groupId) = $sh->fetchrow_array()) {
        push(@groups,$groupId);
    }
    $sh->finish();
    return \@groups;
}

sub getProteinToEValue {
    my ($dbh,$groupId) = @_;
    my $sql = "SELECT qseq,evalue FROM apidb.orthogroupblastvalue
               WHERE group_id = '$groupId'";
    my $sh = $dbh->prepare($sql);
    $sh->execute();

    my %proteinToEValue;
    while(my ($protein,$evalue) = $sh->fetchrow_array()) {
        if ($evalue eq '0.0') {
            $evalue = 1.0e-300;
        }
	$proteinToEValue{$protein} = abs_log10($evalue);
    }
    $sh->finish();

    return \%proteinToEValue;
}

sub getProteinToDomain {
    my ($dbh,$groupId) = @_;
    my $sql = "SELECT full_id,accession FROM webready.ProteinDomainAssignment
               WHERE group_name = '$groupId'";
    my $sh = $dbh->prepare($sql);
    $sh->execute();

    my %proteinToDomain;
    while(my ($protein,$domain) = $sh->fetchrow_array()) {
	$proteinToDomain{$protein} = $domain;
    }
    $sh->finish();

    return \%proteinToDomain;
}

sub getProteinToEC {
    my ($dbh,$groupId) = @_;
    my $sql = "SELECT pda.full_id,ec.ec_number
               FROM SRes.EnzymeClass ec, DoTS.AASequenceEnzymeClass aaec, webready.ProteinDomainAssignment pda
               WHERE ec.enzyme_class_id = aaec.enzyme_class_id 
               AND aaec.aa_sequence_id = pda.aa_sequence_id
               AND pda.group_name = '$groupId'";
    my $sh = $dbh->prepare($sql);
    $sh->execute();

    my %proteinToEC;
    while(my ($protein,$ec) = $sh->fetchrow_array()) {
	$proteinToEC{$protein} = $ec;
    }
    $sh->finish();

    return \%proteinToEC;
}

sub abs_log10 {
    my ($num) = @_;

    # Handle zero or negative input
    return undef if $num <= 0;

    # Take the log base 10 and return absolute value, rounded
    return int(abs(log($num) / log(10)) + 0.5);  # round to nearest int
}
