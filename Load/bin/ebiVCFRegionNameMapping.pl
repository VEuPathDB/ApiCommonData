#!/usr/bin/perl

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";
use Getopt::Long;
use ApiCommonData::Load::EBIUtils;
use CBIL::Util::Utils;

use File::Temp qw/ tempfile /;
use File::Copy;

my ($help, $vcf, $samplesDirectory, $organismAbbrev);

&GetOptions('help|h' => \$help,
            'VCF_file=s' => \$vcf,
            'organism_abbrev=s' => \$organismAbbrev,
            );
      
&usage("organismAbbrev not defined") unless $organismAbbrev;

chomp $organismAbbrev;

my $map = getGenomicSequenceIdMapSql($organismAbbrev);


  my $oldVcf = "$vcf.old";

  move($vcf, $oldVcf);

  open(OLD, $oldVcf) or die "Cannot open file $oldVcf for reading: $!";
  open(VCF, ">$vcf") or die "Cannot open file $vcf for writing: $!";

  while(<OLD>) {
    chomp;

                my @a = split(/\t/, $_);
		### Ignore lines beginning with a hash character ###
                unless ( /^#/ ){
                                        if($map->{$a[0]}) {
                                        $a[0] = $map->{$a[0]};
                                        }
                                }

    print VCF join("\t", @a) . "\n";
  }

  close VCF;
  close OLD;

### bzip vcf and create index ###

if ( -e "$vcf.gz") {
    die "Zipped vcf file $vcf.gz already exists.\n";
} else {
    my $zip_cmd = "bgzip ".$vcf;
    &runCmd($zip_cmd);
    my $index_cmd = "tabix -p vcf ".$vcf."\.gz";
    &runCmd($index_cmd);
}

sub usage {
  die "ebiVCFRegionNameMapping.pl --VCF_File=FILE --organism_abbrev=s\n";
}

1;

