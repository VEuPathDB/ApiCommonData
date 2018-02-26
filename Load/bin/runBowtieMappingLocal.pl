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
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;
use Getopt::Long;
use lib "$ENV{GUS_HOME}/lib/perl";
use CBIL::Util::Utils;

my($mateA,$mateB,$sampleName,$delIntFiles,$bowtieIndex,$isColorspace,$removePCRDuplicates,$bowtie2,$extraBowtieParams);
my $workingDir = ".";

&GetOptions( 
            "mateA|ma=s"=> \$mateA,
            "mateB|mb=s" => \$mateB,
            "bowtie2=s" => \$bowtie2,
            "bowtieIndex|x=s" => \$bowtieIndex,
            "sampleName|s=s" => \$sampleName,
            "workingDir|w=s" => \$workingDir,
            "extraBowtieParams|e:s" => \$extraBowtieParams,
            "deleteIntermediateFiles!" => \$delIntFiles,
            "isColorspace!" => \$isColorspace,
            "removePCRDuplicates!" => \$removePCRDuplicates,
            );

die "mateA file not found\n".&getParams() unless -e "$mateA";
die "mateB file not found\n".&getParams() if ($mateB && !-e "$mateB");
die "bowtie index must be specified\n".&getParams() unless (-e "$bowtieIndex.1.bt2" || ($isColorspace && -e "$bowtieIndex.1.ebwt")); 
die "you must provide a sample name\n".&getParams() unless $sampleName;
##should add in usage
$bowtie2 = (! defined($bowtie2) ? 'bowtie2' : $bowtie2);  ##if not specified then bowtie2 must be in path.

#change bowtie params back to corret form
$extraBowtieParams =~ s/_/-/g;
$extraBowtieParams =~ s/#/ /g;

open(L,">>$workingDir/runBowtieMapping.log");

select L;
$| = 1;

print L "runBowtieMappingLocal.pl run starting ".&getDate()."\n\n";

my $out = $sampleName;
my $tmpOut = $out . "_tmp";

my $cmd;


### aligning with bowtie 1 if colorspace
if($isColorspace && -e "$bowtieIndex.1.ebwt"){  
  die "if isColorspace=true you must provide qual files that are named exactly like the reads files but with .qual appended to the read file name" unless -e "$mateA.qual";
  if(-e "$mateB"){  ## pairedEnd
    $cmd = "(bowtie -f -C -a -S -n 3 --best --strata --sam-RG 'ID:EuP' --sam-RG 'SM:TU114' --sam-RG 'PL:Illumina' ";
    if ($extraBowtieParams) {$cmd = $cmd.$extraBowtieParams;}
    $cmd = $cmd." $bowtieIndex -1 $mateA --Q1 $mateA.qual -2 $mateB --Q2 $mateB.qual > $workingDir/$tmpOut.sam) >& $workingDir/$tmpOut.bowtie.log"; 
  }else{  ##single end
    $cmd = "(bowtie -f -C -a -S -n 3 --best --strata --sam-RG 'ID:EuP' --sam-RG 'SM:TU114' --sam-RG 'PL:Illumina' ";
    if ($extraBowtieParams) {$cmd = $cmd.$extraBowtieParams;}
    $cmd = $cmd." $bowtieIndex $mateA -Q $mateA.qual > $workingDir/$tmpOut.sam) >& $workingDir/bowtie.log";
  }
  print L &getDate().": $cmd\n";
  if(-e "$workingDir/complete" || -e "$workingDir/$out.bam"){ print L "  succeeded in previous run\n\n";
  }else{ &runCmd($cmd); print L "\n"; }

##aligning with Bowtie2 if not colorspace
}elsif( -e "$bowtieIndex.1.bt2"){  
  $cmd = "($bowtie2 --rg-id EuP --rg 'SM:TU114' --rg 'PL:Illumina' ";
  if ($extraBowtieParams){$cmd = $cmd.$extraBowtieParams;}
  $cmd = $cmd." -x $bowtieIndex ".(-e "$mateB" ? "-1 $mateA -2 $mateB " : "-U $mateA ")." | samtools view -buS - | samtools sort -o $workingDir/$tmpOut.bam) >& $workingDir/bowtie.log";
  
  print L &getDate().": $cmd\n";
  if(-e "$workingDir/complete" || -e "$workingDir/$out.bam"){ print L "  succeeded in previous run\n\n";
  }else{ &runCmd($cmd); print L "\n"; }
}else{
  die "ERROR: indices for short read aligner (bowtie2 / bowtie) not found\n";
}

# Remove PCR duplicates if flagged
if ($removePCRDuplicates) {
    if (-e "$mateB"){ #paired end
        $cmd = "samtools rmdup $workingDir/$tmpOut.bam $workingDir/$out.bam";
    }else{ #single end
        $cmd = "samtools rmdup -S $workingDir/$tmpOut.bam $workingDir/$out.bam";
    }
    print L &getDate().": $cmd\n";
    if (-e "$workingDir/$out.bam") { print L " succeeded in previous run\n\n";
    }else{ &runCmd($cmd); print L "\n"; }

# If duplicates not removed, move sorted bam file out of tmp
}else{
    $cmd = "mv $workingDir/$tmpOut.bam $workingDir/$out.bam";
    print L &getDate().": $cmd\n";
    if (-e "$workingDir/$out.bam") { print L " succeeded in previous run\n\n";
    }else{ &runCmd($cmd); print L "\n"; }
}


##should cleanup unneeded files before exiting so don't transfer too much back
## can delete all $tmpOut* and .err files for starters.

if($delIntFiles){
  print L "deleting extra files\n";
  system("/bin/rm $workingDir/$tmpOut.*");
  system("/bin/rm $workingDir/*.err");
}

close L;

sub getParams {
  return &getDate().": runBowtieMappingLocal.pl ... parameter values:\n\tOR\n\tbowtieIndex=$bowtieIndex\n\tmateA=$mateA\n\tmateB=$mateB\n\toutputPrefix=$out\n\tsampleName=$sampleName\n\tworkingDir=$workingDir\n\n";
}

sub getDate {
  my $date = `date`;
  chomp $date;
  return $date;
}
