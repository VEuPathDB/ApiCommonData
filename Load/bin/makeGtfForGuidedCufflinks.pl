#!/usr/bin/perl

use strict;
use warnings;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use GUS::ObjRelP::DbiDatabase;
use CBIL::Util::PropertySet;

use Data::Dumper;

my ($gusConfigFile,$verbose,$outFile,$SQL,$project);
&GetOptions("verbose!"=> \$verbose,
            "outputFile=s" => \$outFile,"SQL=s" => \$SQL, 
            "gusConfigFile=s" => \$gusConfigFile,
            "project=s" => \$project);

if(!$SQL || !$outFile || !$project){
	die "usage: makeGtfForGuidedCufflinks.pl --outputFile <outfile> --verbose --SQL 'sql stmt that returns chr_id, gene_id, exon_id, transcript_id, exon start and end, coding start and end and strand for exons of interest' --gusConfigFile [\$GUS_CONFIG_FILE] --project 'TriTrypDB, PlasmoDB etc to show origin of data in gtf'\n";
}

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

##want to be able to restart it....figure this out later
my %done;
if(-e $outFile){
	open(F,"$outFile");
	while(<F>){
        my $line = $_;
        my ($chr, $project, $type, $exonStart, $exonEnd, $score, $strand, $frame, $attrs) = split (/\t/, $line);
        if ($type eq 'exon'){
            my $geneId = (split /;/, $attrs)[1];
            $geneId = (split / /, $geneId)[1];
            $done{$geneId} = 1; 
		}
	}
	close F;
	print STDERR "Ignoring ".scalar(keys%done)." entries already dumped\n" if $verbose;
}

open(OUT,">>$outFile");

print STDERR "SQL: $SQL\n" if $verbose;
my $gtfStmt = $dbh->prepare($SQL);
$gtfStmt->execute();
while(my (@row) = $gtfStmt->fetchrow_array()){
    print STDERR "Getting data for gene".$row[1]."\n" if $verbose;
    next if exists $done{$row[1]};
    &writeGtfEntry(@row)
}

sub writeGtfEntry{
    my @gtfRow = @_;
    die "Row returned from SQL is not the correct length\n" unless (scalar(@gtfRow) == 10);
    my ($chr, $geneId, $exonId, $transcriptId, $exonStart, $exonEnd, $strand, $codingStart, $codingEnd, $phase) = @gtfRow;
    my ($cdsStart,$cdsEnd);
    if ($strand eq '+'){
        $cdsStart = $codingStart;
        $cdsEnd = $codingEnd;
    }else {
        die "Strand must be '+' or '-': $strand\n" unless ($strand eq '-');
        $cdsStart = $codingEnd;
        $cdsEnd = $codingStart;
    }

    if ($cdsStart == 0 || $cdsEnd == 0 ) {
        printf OUT ("%s\t%s\texon\t%d\t%d\t.\t%s\t.\ttranscript_id \"rna_%s\"; gene_id \"%s\"; gene_name \"%s\";\n", $chr,$project,$exonStart,$exonEnd,$strand,$transcriptId,$geneId,$geneId);
    }
    
    else { 
        printf OUT ("%s\t%s\texon\t%d\t%d\t.\t%s\t.\ttranscript_id \"rna_%s\"; gene_id \"%s\"; gene_name \"%s\";\n%s\t%s\tCDS\t%d\t%d\t.\t%s\t%d\ttranscript_id \"rna_%s\"; gene_id \"%s\"; gene_name \"%s\";\n", $chr,$project,$exonStart,$exonEnd,$strand,$transcriptId,$geneId,$geneId,$chr,$project,$cdsStart,$cdsEnd,$strand,$phase,$transcriptId,$geneId,$geneId);
    }
}
close (OUT);
exit;
