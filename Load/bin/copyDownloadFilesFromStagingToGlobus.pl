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
#
FungiDB|29|PrubensWisconsin54-1255|36
FungiDB|29|HcapsulatumH88|36
FungiDB|29|HcapsulatumG217B|36
FungiDB|29|Foxysporum54006|36
FungiDB|29|FoxysporumFo47|36
PlasmoDB|26|PcynomolgiM|36
PlasmoDB|26|PadleriG01|36
PlasmoDB|26|PbillcollinsiG01|36
PlasmoDB|26|PreichenowiG01|36
PlasmoDB|26|PblacklockiG01|36
PlasmoDB|26|PgaboniG01|36
PlasmoDB|26|PpraefalciparumG01|36
TriTrypDB|29|TcruzicruziDm28c|36
TriTrypDB|29|TtheileriEdinburgh|36
TriTrypDB|29|TcruziSylvioX10-1-2012|36
MicrosporidiaDB|29|NdisplodereJUm2807|36
CryptoDB|29|Chominis30976|36
CryptoDB|29|CtyzzeriUGA55|36
ToxoDB|27|CsuisWienI|36
PiroplasmaDB|29|BmicrotiRI|36
#
#FungiDB|29|CgattiiCA1873|35
#FungiDB|29|CgattiiIND107|35
#PlasmoDB|26|PknowlesiMalayanPk1A|35
#
#FungiDB|29|MoryzaeBR32|34
#FungiDB|29|ZtriticiIPO323|34
#FungiDB|29|ClusitaniaeATCC42720|34
#FungiDB|29|Ureesii1704|34
#HostDB|29|Mmulatta17573|34
#
#FungiDB|29|AbrasiliensisCBS101740|33
#FungiDB|29|AfumigatusA1163|33
#FungiDB|29|AglaucusCBS516.65|33
#FungiDB|29|AluchuensisCBS106.47|33
#FungiDB|29|AsydowiiCBS593.65|33
#FungiDB|29|AtubingensisCBS134.48|33
#FungiDB|29|AversicolorCBS583.65|33
#FungiDB|29|AwentiiDTO134E9|33
#FungiDB|29|AzonataCBS506.65|33
#MicrosporidiaDB|29|NausubeliERTm2|33
#MicrosporidiaDB|29|NausubeliERTm6|33
#FungiDB|29|AaculeatusATCC16872|33
#FungiDB|29|AcarbonariusITEM5010|33
#
#PlasmoDB|26|PbergheiANKA|32
#PlasmoDB|26|PovalecurtisiGH01|32
#PlasmoDB|26|Pgallinaceum8A|32
#CryptoDB|29|ChominisTU502_2012|32
#PiroplasmaDB|29|BmicrotiRI|32
#TriTrypDB|29|TcruziSylvioX10-1|32
#
#FungiDB|29|FgraminearumPH-1|30
#ToxoDB|27|CcayetanensisCHN_HEN01|30
#TriTrypDB|29|TbruceiTREU927|30
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
