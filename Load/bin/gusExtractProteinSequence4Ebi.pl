#!/usr/bin/perl

## dumps sequences from sequence table 
## note the sequence must be returned as the last item


use strict;
use lib "$ENV{GUS_HOME}/lib/perl";
use Getopt::Long;
use GUS::ObjRelP::DbiDatabase;
use CBIL::Bio::SequenceUtils;
use GUS::Supported::GusConfig;

my ($gusConfigFile,
    $outFile,
    $extDbRlsId,
    $debug,
    $verbose,
    $minLength,
    $mscPercent,
    $noSeq,
    $posStrand,
    $negStrand,
    $allowEmptyOutput,

    $help
   );

&GetOptions('verbose!'=> \$verbose,
            'outputFile=s' => \$outFile,
            'extDbRlsId=s' => \$extDbRlsId,
            'minLength=i' => \$minLength,
	    'debug!' => \$debug,
            'maxStopCodonPercent=i' => \$mscPercent,
            'gusConfigFile=s' => \$gusConfigFile,
            'noSequence!' => \$noSeq,
            'allowEmptyOutput!' => \$allowEmptyOutput,
            'posStrand=s' => \$posStrand,
            'negStrand=s' => \$negStrand,
	    'help|h' => \$help
	   );

&usage() if ($help);
&usage("Missing a Required Argument") unless (defined $extDbRlsId && $outFile);

$gusConfigFile = "$ENV{GUS_HOME}/config/gus.config" unless ($gusConfigFile);

##set the defaults
$minLength = $minLength ? $minLength : 1;

#It is optimal if we don't set the default, but filter only if this is set.
#$mscPercent = $mscPercent ? $mscPercent : 100;

print STDERR "Establishing dbi login\n" if $verbose;
my $gusconfig = GUS::Supported::GusConfig->new($gusConfigFile);

my $db = GUS::ObjRelP::DbiDatabase->new($gusconfig->getDbiDsn(),
					$gusconfig->getReadOnlyDatabaseLogin(),
					$gusconfig->getReadOnlyDatabasePassword,
					$verbose,0,1,
					$gusconfig->getCoreSchemaName,
					$gusconfig->getOracleDefaultRollbackSegment());

my $dbh = $db->getQueryHandle();

$dbh->{LongReadLen} = 512 * 512 * 1024;

##want to be able to restart it....
my %done;
if(-e $outFile){
  open(F,"$outFile");
  while(<F>){
    if(/^\>(\S+)/){
      $done{$1} = 1;
    }
  }
  close F;
  print STDERR "Ignoring ".scalar(keys%done)." entries already dumped\n" if $verbose;
}

my $isPseudo = getIsPseudoFromProtein($extDbRlsId);
my $isSeleno = getIsSelenoFromProtein($extDbRlsId);

open(OUT,">>$outFile") || die "Can't open $outFile to append output\n Check write permission\n";

my $count = 0;
my $skip = 0;

my $idSQL = "select SOURCE_ID, SEQUENCE from DOTS.TRANSLATEDAASEQUENCE where AA_SEQUENCE_ID in (select AA_SEQUENCE_ID from dots.translatedaafeature where EXTERNAL_DATABASE_RELEASE_ID=$extDbRlsId)";

print STDERR "SQL: $idSQL\n" if $verbose;

my $idStmt = $dbh->prepare($idSQL);
$idStmt->execute();

my @ids;
while(my (@row) = $idStmt->fetchrow_array()){
  $count++;
  my $time = localtime(time());
  print STDERR "[$time] Getting id for $count\n" if $verbose && $count % 10000 == 0;
  next if exists $done{$row[0]};  ##don't put into hash if already have...
  &printSequence(@row)
}

$count = 2 * $count if ($posStrand && $negStrand);

my $countSeqInOutFile=`grep -c '>' $outFile`;

die "Inconsistant number of sequences between query results and outputs in $outFile. Please check log file.\n" unless (($countSeqInOutFile + $skip)==$count);

die "No sequences extracted. (Check your idSQL.)" unless ($count || $allowEmptyOutput);

###### subRoutine ######

sub printSequence{
  my @row = @_;

  my $sequence = pop(@row) unless $noSeq;
  my $defline = "\>".join(' ',@row);
  $defline =~ s/\s+/ /g;
  $defline .= "\n";

  my $pId = shift (@row);
 # print STDERR "$pId\n$sequence\n";

  ## 1. remove the stop codon at the end if has it
  $sequence =~ s/\*+$//;

  ## 2. If a known selenocysteine, replacd * to U
  if ($isSeleno->{$pId} == 1) {
    $sequence =~ s/\*/U/;
    print STDERR "processed selenocysteine: $pId ... replace * to U.\n";
  }

  ## 3. If proten_coding gene, replace * to X, EBI pipelines will detect X and generate seqedits
  ## 4. For pseudogene, truncate to the 1st stop codon
  if ($isPseudo->{$pId} == 1) {
    $sequence =~ s/(.*?)\*.*/$1/;
#    print STDERR "after pseudo_process:\n$sequence\n";
  } else {
    my $seqEdit = ($sequence =~ /\*/) ? 1 : 0;
    $sequence =~ s/\*/X/g;
    print STDERR "after replace * to X:\n$sequence\n" if ($seqEdit == 1);
  }

  ## TODO 5. should we set up the minLenth for the truncated protein sequence?

  if(!$noSeq && length($sequence) < $minLength){
    print STDERR "Skipping: $row[0] too short: ",length($sequence),"\n";
    $skip++;
    return;
  }

  if ($mscPercent) {
	  my $aaLength = length ($sequence);	
	  my $aaCount = ($sequence =~ tr/[^A-Za-z]//);
	  my $aaStopCodonPercent = (($aaLength - $aaCount)/($aaLength)) * 100;
	  if ($aaStopCodonPercent > $mscPercent) {
  		print STDERR "Skipping: $row[0] has $aaStopCodonPercent\% stop codons\n";
		$skip++;
		return;
	  }
  }

  $noSeq ? print OUT $defline : print OUT $defline . CBIL::Bio::SequenceUtils::breakSequence($sequence,60);
  if ($posStrand && $negStrand) {
    $defline =~ s/$posStrand/$negStrand/;
    my $negSeq = CBIL::Bio::SequenceUtils::reverseComplementSequence($sequence);
    print OUT $defline . CBIL::Bio::SequenceUtils::breakSequence($negSeq,60) unless $noSeq;
  }
}

sub getIsPseudoFromProtein {
  my ($extDbRlsId) = @_;
  my %isP;

  my $sql = "select taf.source_id, t.is_pseudo from dots.translatedaafeature taf, dots.transcript t
where taf.NA_FEATURE_ID=t.NA_FEATURE_ID and taf.EXTERNAL_DATABASE_RELEASE_ID=$extDbRlsId
";
  my $stmt = $dbh->prepare($sql);
  $stmt->execute();
  while (my ($pId, $prefer) = $stmt->fetchrow_array()) {
    $isP{$pId} = $prefer if ($pId);
  }
  $stmt->finish();
#  $dbh->undefPointerCache();

  return \%isP;
}

sub getIsSelenoFromProtein {
  my ($extDbRlsId) = @_;
  my %isS;

  my $sql = "select taf.source_id, tp.product
from dots.translatedaafeature taf, dots.transcript t, APIDB.TRANSCRIPTPRODUCT tp
where taf.NA_FEATURE_ID=t.NA_FEATURE_ID and t.NA_FEATURE_ID=tp.NA_FEATURE_ID
and taf.EXTERNAL_DATABASE_RELEASE_ID=$extDbRlsId";

  my $stmt = $dbh->prepare($sql);
  $stmt->execute();
  while (my ($pId, $product) = $stmt->fetchrow_array()) {
    $isS{$pId} = 1 if ($pId && $product =~ /selenopro/i);
  }
  $stmt->finish();

  return \%isS;
}


sub usage {
  die
"
A script to dump the protein sequence file from GUS to EBI pipeline

Usage: 

where:
  --outputFile: required,
  --extDbRlsId: required,
  --gusConfigFile: optional, default is \$GUS_HOME/config/gus.config
  --minLength: optional, the min length of sequence that what to output
  --verbose:
  --debug:
  --posStrand <pos strand notation in idSQL defline,required for file of both strands>:
  --negStrand <neg strand notation, substituted and required in file of both strands>
  --maxStopCodonPercent:<maxium multiple-stop-codons per 100 AA sequences [100]>
  --noSequence
  --allowEmptyOutput

";
}
