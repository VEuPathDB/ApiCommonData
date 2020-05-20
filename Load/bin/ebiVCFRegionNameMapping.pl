#!/usr/bin/perl

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";
use Getopt::Long;
use ApiCommonData::Load::EBIUtils;
use CBIL::Util::Utils;

use File::Temp qw/ tempfile /;
use CBIL::Util::PropertySet;
use File::Copy;

my ($help, $vcf, $samplesDirectory, $gusConfigFile, $organismAbbrev);

&GetOptions('help|h' => \$help,
            'VCF_file=s' => \$vcf,
            'gusConfigFile=s' => \$gusConfigFile,
            'organism_abbrev=s' => \$organismAbbrev,
            );
      
if(!$gusConfigFile) {
  $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";
}

&usage("Config file $gusConfigFile does not exist.") unless -e $gusConfigFile;
#&usage("Sample directory does not exist") unless -d $samplesDirectory;
&usage("organismAbbrev not defined") unless $organismAbbrev;

chomp $organismAbbrev;

my $map = ApiCommonData::Load::EBIUtils::getGenomicSequenceIdMapSql($organismAbbrev);


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
my $zip_cmd = "bgzip ".$vcf;
&runCmd($zip_cmd);
my $index_cmd = "tabix -p vcf ".$vcf."\.gz";
&runCmd($index_cmd);

sub usage {
  die "ebiVCFRegionNameMapping.pl --VCF_File=FILE --organism_abbrev=s\n";
}

1;

