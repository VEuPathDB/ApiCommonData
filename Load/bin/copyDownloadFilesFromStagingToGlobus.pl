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
#FungiDB|29|AochraceoroseusIBT24754|40 ??
#
FungiDB|29|Ptriticina1-1BBBDRace1|43
FungiDB|29|EoligospermaCBS72588|43
FungiDB|29|CcarrioniiKSF|43
FungiDB|29|FpedrosoiCBS271-37|43
FungiDB|29|KheveanensisCBS569|43
FungiDB|29|AmutatusUAMH3576|43
FungiDB|29|NalbidaJCM2334|43
FungiDB|29|AnigerATCC13496|43
FungiDB|29|CtropicalisMYA3404|43
TriTrypDB|29|Tcruzi231|43
TriTrypDB|29|TcruziBug2148|43
TriTrypDB|29|TcruziY|43
TriTrypDB|29|LdonovaniLV9|43
#FungiDB|29|FoxysporumFOSC3a|42
#FungiDB|29|FproliferatumNRRL62905|42
#FungiDB|29|KbestiolaeCBS10118|42
#FungiDB|29|KdejecticolaCBS10117|42
#FungiDB|29|NalbidaNRRLY1402|42
#FungiDB|29|PplurivoraAV1007|42
#TriTrypDB|29|LdonovaniCL-SL|42
#TriTrypDB|29|TcruziTCC|42
#TriTrypDB|29|TcruziDm28c2018|42
#TriTrypDB|29|TcruziDm28c2014|42
#TriTrypDB|29|TcruziDm28c2017|42
#TriTrypDB|29|TbruceiLister427_2018|42
#TriTrypDB|29|BsaltansLakeKonstanz|42
#PlasmoDB|26|Pvivax-likePvl01|42
#HostDB|29|BtaurusHereford|42
#PiroplasmaDB|29|Bdivergens1802A|42
#TriTrypDB|29|LamazonensisMHOMBR71973M2269|42
#FungiDB|29|CparapsilosisCDC317|42
#FungiDB|29|CneoformansKN99|42
#
#MicrosporidiaDB|29|AspWSBS2006|41
#MicrosporidiaDB|29|EcuniculiEcunIII-L|41
#MicrosporidiaDB|29|NceranaePA08_1199|41
#CryptoDB|29|CspchipmunkLX2015|41
#PlasmoDB|26|Pfalciparum7G8|41
#PlasmoDB|26|PfalciparumCD01|41
#PlasmoDB|26|PfalciparumDd2|41
#PlasmoDB|26|PfalciparumGA01|41
#PlasmoDB|26|PfalciparumGB4|41
#PlasmoDB|26|PfalciparumGN01|41
#PlasmoDB|26|PfalciparumHB3|41
#PlasmoDB|26|PfalciparumKE01|41
#PlasmoDB|26|PfalciparumKH01|41
#PlasmoDB|26|PfalciparumKH02|41
#PlasmoDB|26|PfalciparumML01|41
#PlasmoDB|26|PfalciparumSD01|41
#PlasmoDB|26|PfalciparumSN01|41
#PlasmoDB|26|PfalciparumTG01|41
#PlasmoDB|26|PfalciparumIT|41
#FungiDB|29|AnigerN402ATCC64974|41
#FungiDB|29|CparapsilosisCDC317|41
#FungiDB|29|FproliferatumET1|41
#FungiDB|29|SapiospermumIHEM14462|41
#FungiDB|29|Sbrasiliensis5110|41
#FungiDB|29|CgattiiNT10|41
#FungiDB|29|LprolificansJHH5317|41
#FungiDB|29|YlipolyticaCLIB89W29|41
#FungiDB|29|AkawachiiIFO4308|41
#FungiDB|29|AnigerATCC1015|41
#
#FungiDB|29|Sschenckii1099-18|39
#FungiDB|29|CalbicansWO1|39
#FungiDB|29|AochraceoroseusIBT24754|39
#FungiDB|29|CalbicansSC5314|39
#FungiDB|29|CalbicansSC5314_B|39
#FungiDB|29|CglabrataCBS138|39
#FungiDB|29|BcinereaB05-10|39
#MicrosporidiaDB|29|EhepatopenaeiTH1|39
#MicrosporidiaDB|29|EcanceriGB1|39
#MicrosporidiaDB|29|HeriocheirGB1|39
#MicrosporidiaDB|29|Heriocheircanceri|39
#TriTrypDB|29|LinfantumJPCM5|39
#
#FungiDB|29|HcapsulatumH143|38
#FungiDB|29|CgattiiEJB2|38
#FungiDB|29|Foxysporum26406|38
#FungiDB|29|Foxysporumrace1|38
#FungiDB|29|Foxysporumrace4|38
#FungiDB|29|AcampestrisIBT28561|38
#FungiDB|29|AnovofumigatusIBT16806|38
#FungiDB|29|AsteyniiIBT23096|38
#PlasmoDB|26|PvivaxP01|38
#
#CryptoDB|29|CmeleagridisUKMEL1|37
#CryptoDB|29|CparvumIowaII|37
#FungiDB|29|AnovofumigatusIBT16806|37
#FungiDB|29|AcampestrisIBT28561|37
#FungiDB|29|AsteyniiIBT23096|37
#FungiDB|29|CaurisB8441|37
#FungiDB|29|CneoformansKN99|37
#PiroplasmaDB|29|BovataMiyake|37
#TriTrypDB|29|LpanamensisMHOMPA94PSC1|37
#TriTrypDB|29|PconfusumCUL13|37
#
#FungiDB|29|PrubensWisconsin54-1255|36
#FungiDB|29|HcapsulatumH88|36
#FungiDB|29|HcapsulatumG217B|36
#FungiDB|29|Foxysporum54006|36
#FungiDB|29|FoxysporumFo47|36
#PlasmoDB|26|PcynomolgiM|36
#PlasmoDB|26|PadleriG01|36
#PlasmoDB|26|PbillcollinsiG01|36
#PlasmoDB|26|PreichenowiG01|36
#PlasmoDB|26|PblacklockiG01|36
#PlasmoDB|26|PgaboniG01|36
#PlasmoDB|26|PpraefalciparumG01|36
#TriTrypDB|29|TcruzicruziDm28c|36
#TriTrypDB|29|TtheileriEdinburgh|36
#TriTrypDB|29|TcruziSylvioX10-1-2012|36
#MicrosporidiaDB|29|NdisplodereJUm2807|36
#CryptoDB|29|Chominis30976|36
#CryptoDB|29|CtyzzeriUGA55|36
#ToxoDB|27|CsuisWienI|36
#PiroplasmaDB|29|BmicrotiRI|36
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
