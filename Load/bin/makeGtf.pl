#!/usr/bin/perl

use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use GUS::ObjRelP::DbiDatabase;
use CBIL::Util::PropertySet;
use GUS::Community::GeneModelLocations;

use Data::Dumper;

my ($gusConfigFile,$verbose,$outFile,$project,$genomeExtDbRlsId);
&GetOptions("verbose!"=> \$verbose,
            "outputFile=s" => \$outFile,
            "gusConfigFile=s" => \$gusConfigFile,
            "project=s" => \$project,
            "genomeExtDbRlsId=i" => \$genomeExtDbRlsId); 

if(!$outFile || !$project){
	die "usage: makeGtf.pl --outputFile <outfile> --verbose --gusConfigFile [\$GUS_CONFIG_FILE] --project 'TriTrypDB, PlasmoDB etc to show origin of data in gtf' -- genomeExtDbRlsId genomeExtDbRlsId\n";
}

##Create db handle
if(!$gusConfigFile) {
  $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";
  
}

my @properties = ();

print STDERR "Establishing dbi login\n" if $verbose;
die "Config file $gusConfigFile does not exist." unless -e $gusConfigFile;

my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->{props}->{dbiDsn},
                                        $gusconfig->{props}->{databaseLogin},
                                        $gusconfig->{props}->{databasePassword},
					$verbose,0,1,
					$gusconfig->{props}->{coreSchemaName},
				       );

my $dbh = $db->getQueryHandle();

open(OUT,">$outFile");

my $geneModelLocations = GUS::Community::GeneModelLocations->new($dbh, $genomeExtDbRlsId, 1);
my @geneSourceIds = sort @{$geneModelLocations->getAllGeneIds()};

foreach my $geneSourceId (@geneSourceIds) {
    my $cdsHash = {};
    my $feature = $geneModelLocations->bioperlFeaturesFromGeneSourceId($geneSourceId);

    foreach my $subFeature (@{$feature}) {
        # Of bioperl features from GeneModelLocation, only CDS and exon are valid for gtf files
        if ($subFeature->primary_tag() eq 'exon') {

            # If an exon belongs to 2 transcripts, we need to write it twice...
            my @parents = $subFeature->get_tag_values('PARENT');
            die "A feature belonging to gene $geneSourceId has more than one parent" unless (scalar @parents == 1);
               
            foreach my $parent (@parents) { 
                my @transcriptIds = sort (split (',', $parent));
                foreach my $transcriptId (@transcriptIds) {
                    $subFeature->remove_tag('PARENT');
                    $subFeature->add_tag_value('PARENT', $transcriptId);
                    writeGtfRow($subFeature, $project, $geneSourceId, 'exon');
                }
            }
        }

        elsif ($subFeature->primary_tag() eq 'CDS') {
            # Separate CDS features by parent
            my @parents = $subFeature->get_tag_values('PARENT');
            die "A feature belonging to gene $geneSourceId has more than one parent" unless (scalar @parents == 1);
            foreach my $parent (@parents) { 
                push (@{$cdsHash->{$parent}}, $subFeature);
            }
        }
    }
    
    #Calculate phase for CDS features.  Store in frame attribute of BioPerl object as this is not used in objects obtained from GeneModelLocations
    foreach my $key (sort (keys %{$cdsHash})){
        my $cdsList = $cdsHash->{$key};

    #CDS on + strand
        if (getStrand($cdsList->[0]) eq '+') { # assume that all cds regions belonging to a gene are on the same strand
            for (my $cdsCount = 0; $cdsCount < @{$cdsList}; $cdsCount ++) {   
                my $cds = $cdsList->[$cdsCount];
                if ($cdsCount == 0) {
                    $cds->frame(0);
                }
                else {
                    my $previous = $cdsList->[$cdsCount -1];
                    getPhase ($cds, $previous);
                }
            }
        }
        #CDS on - strand
        elsif (getStrand($cdsList->[0]) eq '-'){
            for (my $cdsCount = @{$cdsList}; $cdsCount > 0; $cdsCount --) {
                my $cds = $cdsList->[$cdsCount -1];
                if ($cdsCount == @{$cdsList}) {
                    $cds->frame(0);
                }
                else {
                    my $previous = $cdsList->[$cdsCount];
                    getPhase ($cds, $previous);
                }
            }
        }
        #Now write CDS features with phase
        foreach my $cds (@{$cdsList}) {
            writeGtfRow($cds, $project, $geneSourceId, 'CDS');
        }
    }
    
}
##subroutines
sub getStrand {
    my ($subFeature) = @_;
    my $strand = $subFeature->strand();
    if ($strand > 0) {
        $strand = '+';
    } 
    elsif ($strand < 0) {
        $strand = '-';
    }
    else {
        die "Strand $strand cannot be 0";
    }
    return $strand;
}

sub getPhase {
    my ($currentCDS, $previousCDS) = @_;
    my $length = ($previousCDS->end() - $previousCDS->start()) +1;
    my $previousPhase = $previousCDS->frame();
    my $currentPhase = (3 - (($length-$previousPhase) % 3)) % 3;
    $currentCDS->frame($currentPhase);
}
    
sub writeGtfRow {
    my ($subFeature, $project, $geneId, $type) = @_;
    my $seqid = $subFeature->seq_id();
    my $start = $subFeature->start();
    my $end = $subFeature->end();
    my $strand = getStrand($subFeature);
    my $phase = $subFeature->frame();
    if (!defined($phase)){
        $phase = '.';
    }
    my $transcriptId;
    my @values;
    foreach my $value ($subFeature->get_tag_values('PARENT')) {
        push (@values, $value);
    }
    if (scalar @values != 1) {
        die "Feature belonging to gene $geneId has more than one parent\n";
    }
    else {
        $transcriptId = $values[0];
    }
    printf OUT ("%s\t%s\t%s\t%d\t%d\t.\t%s\t%s\ttranscript_id \"rna_%s\"; gene_id \"%s\"; gene_name \"%s\";\n", $seqid,$project,$type,$start,$end,$strand,$phase,$transcriptId,$geneId,$geneId);
}
    
close (OUT);
exit;
