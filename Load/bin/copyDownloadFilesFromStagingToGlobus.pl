#!/usr/bin/perl

use strict;

# copy updated files from apiSiteFilesStaging to /eupath/data/apiSiteFiles/globusGenomesShare 

while(<DATA>) {
  chomp;
  next if /^#/;

  my($projectName, $workflowVersion, $organism, $buildNumber) = split /\|/, $_;

  # remove old files if exist
  my @oldfiles = glob("/eupath/data/apiSiteFiles/globusGenomesShare/$projectName-*\_$organism\_Genome.fasta");

  foreach (@oldfiles) {
     print "rm $_\n\n";
     system("rm $_");
  }

  @oldfiles = glob("/eupath/data/apiSiteFiles/globusGenomesShare/$projectName-*\_$organism.gff");

  foreach (@oldfiles) {
     print "rm $_\n\n";
     system("rm $_");
  }

  my $src = "/eupath/data/apiSiteFilesStaging/$projectName/$workflowVersion/real/downloadSite/$projectName/release-CURRENT/$organism/fasta/data/$projectName-CURRENT\_$organism\_Genome.fasta";

  my $tgt = "/eupath/data/apiSiteFiles/globusGenomesShare/$projectName-$buildNumber\_$organism\_Genome.fasta";

  print "cp $src $tgt\n\n"; 
  system ("cp $src $tgt"); 

  $src = "/eupath/data/apiSiteFilesStaging/$projectName/$workflowVersion/real/downloadSite/$projectName/release-CURRENT/$organism/gff/data/$projectName-CURRENT\_$organism.gff";

  $tgt = "/eupath/data/apiSiteFiles/globusGenomesShare/$projectName-$buildNumber\_$organism.gff";

  print "cp $src $tgt\n\n"; 
  system ("cp $src $tgt"); 
}

#data format projectName|workflowVersion|organism|buildNumber

__DATA__
FungiDB|29|FgraminearumPH-1|30
ToxoDB|27|CcayetanensisCHN_HEN01|30
TriTrypDB|29|TbruceiTREU927|30
#
# CryptoDB|29|ChominisUdeA01|30
# PlasmoDB|26|PmalariaeUG01|30
# PlasmoDB|26|PovalecurtisiGH01|30
# PlasmoDB|26|PfragileNilgiri|30
# PlasmoDB|26|PinuiSanAntonio1|30
# PlasmoDB|26|Pvinckeivinckeivinckei|30
# PlasmoDB|26|PvinckeipetteriCR|30
# PlasmoDB|26|PcoatneyiHackeri|30
# PlasmoDB|26|Pyoeliiyoelii17X|30
# FungiDB|29|PbrasiliensisPb03|30
# FungiDB|29|PbrasiliensisPb18|30
# FungiDB|29|PlutziiPb01|30
# ToxoDB|27|TgondiiRUB|30
# ToxoDB|27|TgondiiMAS|30
# ToxoDB|27|Tgondiip89|30
# ToxoDB|27|TgondiiVAND|30
# ToxoDB|27|TgondiiARI|30
# ToxoDB|27|TgondiiTgCatPRC2|30
# ToxoDB|27|TgondiiGAB2-2007-GAL-DOM2|30
# ToxoDB|27|TgondiiFOU|30
