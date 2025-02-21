#!/usr/bin/perl

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";
use Getopt::Long;
use ApiCommonData::Load::EBIUtils;
use CBIL::Util::Utils;
use IO::Zlib;
use File::Temp qw/ tempfile /;
use File::Copy;

my ($help, $vcf, $samplesDirectory, $organismAbbrev, $gusConfigFile);

&GetOptions('help|h' => \$help,
            'VCF_file=s' => \$vcf,
            'organism_abbrev=s' => \$organismAbbrev,
            'gusConfigFile=s' => \$gusConfigFile,
            );
      
&usage("organismAbbrev not defined") unless $organismAbbrev;

chomp $organismAbbrev;

my $map = getGenomicSequenceIdMapSql($organismAbbrev,$gusConfigFile);


#  my $oldVcf = "$vcf.old";

#  move($vcf, $oldVcf);
  ### Remove .gz suffix ###
#  open(OLD,  $oldVcf) or die "Cannot open file $oldVcf for reading: $!";
  tie (*OLD, 'IO::Zlib', $vcf, "rb") or die "Cannot open file $vcf for reading: $!";

my $newVcf = substr($vcf, 0, -3);
$newVcf =~ s/final\///; 

open(VCF, "|-", "/usr/bin/bgzip >$newVcf") or die "Cannot open file test.vcf for writing: $!";
  while(<OLD>) {
    chomp;

                my @a = split(/\t/, $_);
		### Ignore lines beginning with a hash character ###
                unless ( /^#+/ ){
                                        if($map->{$a[0]}) {
                                        $a[0] = $map->{$a[0]};
                                        }
                                }

    print VCF join("\t", @a) . "\n";
  }

  close VCF;
  close OLD;

### remove old vcf, bzip new vcf and create index ###

#if ( -e "$vcf.gz") {
#    die "Zipped gff3 file $vcf.gz already exists.\n";
#} else {

    my $remove_cmd = "rm -f ".$vcf;
    &runCmd($remove_cmd);
    my $rename_cmd = "mv $newVcf $vcf";
    &runCmd($rename_cmd);
  #  my $zip_cmd = "bgzip -f ".$newVcf;
  #  &runCmd($zip_cmd);
    my $index_cmd = "tabix -p vcf ".$vcf;
    &runCmd($index_cmd);
#}

sub usage {
  die "ebiGFF3RegionNameMapping.pl --VCF_File=FILE --organism_abbrev=s\n";
}

1;

