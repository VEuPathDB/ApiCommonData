#!/usr/bin/perl

use strict;

use lib $ENV{GUS_HOME} . "/lib/perl";
use Getopt::Long;
use ApiCommonData::Load::EBIUtils;
use CBIL::Util::Utils;
use IO::Zlib;
use File::Temp qw/ tempfile /;
use File::Copy;

my ($help, $gff3, $samplesDirectory, $organismAbbrev);

&GetOptions('help|h' => \$help,
            'GFF3File=s' => \$gff3,
            'organism_abbrev=s' => \$organismAbbrev,
            );
      
&usage("organismAbbrev not defined") unless $organismAbbrev;

chomp $organismAbbrev;

my $map = getGenomicSequenceIdMapSql($organismAbbrev);


#  my $oldGff3 = "$gff3.old";

#  move($gff3, $oldGff3);
  ### Remove .gz suffix ###
#  $gff3 = substr($gff3, 0, -3);
#  open(OLD,  $oldVcf) or die "Cannot open file $oldVcf for reading: $!";
  tie (*OLD, 'IO::Zlib', $gff3, "rb") or die "Cannot open file $gff3 for reading: $!";
   $gff3 = substr($gff3, 0, -3);
   $gff3 =~ s/final\///;
  open(GFF, ">$gff3") or die "Cannot open file $gff3 for writing: $!";

  while(<OLD>) {
    chomp;

                my @a = split(/\t/, $_);
		### Ignore lines beginning with a hash character ###
                unless ( /^#+/ ){
                                        if($map->{$a[0]}) {
                                        $a[0] = $map->{$a[0]};
                                        }
                                }

    print GFF join("\t", @a) . "\n";
  }

  close GFF;
  close OLD;

### bzip vcf and create index ###

#if ( -e "$gff3.gz") {
#    die "Zipped gff3 file $gff3.gz already exists.\n";
#} else {
    my $sort_cmd = "(grep ^\"\#\" ".$gff3."; grep -v ^\"\#\" ".$gff3." | sort -k1,1 -k4,4n) > ".$gff3."\.sorted";
    &runCmd($sort_cmd);
    my $rm_cmd = "rm -f ".$gff3;
    &runCmd($rm_cmd);  
    my $replace_cmd = "mv ".$gff3."\.sorted ".$gff3;    
    &runCmd($replace_cmd);
    my $zip_cmd = "bgzip -f ".$gff3;
    &runCmd($zip_cmd);
    my $index_cmd = "tabix -p gff ".$gff3."\.gz";
    &runCmd($index_cmd);

#}

sub usage {
  die "ebiGFF3RegionNameMapping.pl --GFF3File=FILE --organism_abbrev=s\n";
}

1;

