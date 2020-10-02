#!/usr/bin/perl

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";
use Getopt::Long;
use ApiCommonData::Load::EBIUtils;
use CBIL::Util::Utils;
use IO::Zlib;
use File::Temp qw/ tempfile /;
use File::Copy;

my ($help, $dir, $outdir, $samplesDirectory, $organismAbbrev, $chromSize, $pattern);

&GetOptions('help|h' => \$help,
            'dir=s' => \$dir,
	    'outdir=s' => \$outdir,
            'organism_abbrev=s' => \$organismAbbrev,
	    'chromSize=s' => \$chromSize,
            );
      
&usage("RNAseq samples directory not defined") unless $dir;

chomp $dir;
chomp $outdir;

my @list = glob $dir.'analyze*/normalized/final/*';
@list = grep !/logged/, @list;
foreach (@list){
print $_."\n";
}


if ( grep( /first/, @list ) ) {
  $pattern = "firststrand";
  &convertBigwig($dir, $outdir, $pattern, $chromSize);
}
if ( grep( /second/, @list ) ) {
  $pattern = "secondstrand";
  &convertBigwig($dir, $outdir, $pattern, $chromSize);
}
else{
print "THERES NO STRANDED DATA!!\n";
  $pattern = "";
  &convertBigwig($dir, $outdir, $pattern, $chromSize);
}
#my $pattern = "firststrand";

#&convertBigwig($dir, $outdir, $pattern, $chromSize);

sub convertBigwig {
  my ($dir,$outdir,$pattern,$chromSize) = @_;
  my @files = glob $dir.'analyze*/normalized/final/*results\.'.$pattern.'*'; 
  @files = grep !/logged/, @files;
  my $filenames = join(' ', map { "$_" } @files);
  #Create bigWigMerge command
  my $cmd = "bigWigMerge ".$filenames." ".$outdir."out.bedGraph";
  &runCmd($cmd);
  #Convert out.bedGraph to bigwig format
  my $convert_cmd = "bedGraphToBigWig ".$outdir."out.bedGraph ".$chromSize." merged_".$pattern."_".$organismAbbrev."\.bw";
  #print $convert_cmd."\n";
  &runCmd($convert_cmd);
}

sub usage {
  die "rnaseqMerge.pl --dir=s --organism_abbrev=s  --outdir=s --chromSize=s \n";
}

1;

