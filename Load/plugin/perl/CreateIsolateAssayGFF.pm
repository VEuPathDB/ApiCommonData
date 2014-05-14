package ApiCommonData::Load::Plugin::CreateIsolateAssayGFF;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

my $argsDeclaration =
  [
    stringArg({ name   => 'extDbRlsName',
                descr  => 'External Database Release name of the AA sequences',
                isList => 0,
                reqd   => 1,
                constraintFunc => undef,
              }),

    stringArg({ name   => 'extDbRlsVer',
                descr  => 'External Database Release version of the AA sequences',
                isList => 0,
                reqd   => 1,
                constraintFunc => undef,
              }),

    stringArg({ descr  => 'Use projectName to discover the file path.',
                name   => 'projectName',
                isList => 0,
                reqd   => 0,
                constraintFunc => undef,
              }), 
  ];

my $purposeBrief = <<PURPOSEBRIEF;
Convert Isolate Chip Assay data (Broad Barcode/3k Chip) into Sequence Typed SNP gff format 
PURPOSEBRIEF

my $purpose = <<PURPOSE;
Convert Isolate Chip Assay data (Broad Barcode/3k Chip) into Sequence Typed SNP gff format 
PURPOSE

my $howToRestart = <<PLUGIN_RESTART;
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;

Example:
ga ApiCommonData::Load::Plugin::CreateIsolateAssayGFF --extDbRlsName pfal3D7_SNP_Broad3KGenotyping_RSRC --extDbRlsVer 2008-06-13 --projectName PlasmoDB

Above comment will read 
/eupath/data/EuPathDB/manualDelivery/PlasmoDB/pfal3D7/SNP/Broad3KGenotyping/2008-06-13/final/isolateSNPs.txt

and output gff will be placed at the same directory
/eupath/data/EuPathDB/manualDelivery/PlasmoDB/pfal3D7/SNP/Broad3KGenotyping/2008-06-13/final/isolateSNPs.gff

Still need to figure out how to handle metadata

PLUGIN_NOTES

my $documentation = { purposeBrief     => $purposeBrief,
                      purpose          => $purpose,
                      howToRestart     => $howToRestart,
                      failureCases     => $failureCases,
                      notes            => $notes, 
                      tablesAffected   => "",
                      tablesDependedOn => "",
                    };

sub new {
  my $class = shift;
  $class = ref $class || $class;
  my $self = {};
  
  bless $self, $class;

  $self->initialize({ requiredDbVersion => 3.6,
                       cvsRevision      => '$Revision$',
                       name             => ref($self),
                       argsDeclaration  => $argsDeclaration,
                       documentation    => $documentation
                   });

  return $self;
}

sub run {
  my ($self) = @_;
  my $extDbRlsName = $self->getArg("extDbRlsName");
  my $extDbRlsVer  = $self->getArg("extDbRlsVer");
  my $projectName  = $self->getArg("projectName");

  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsName, $extDbRlsVer);

   unless ($extDbRlsId) {
       die "No such External Database Release / Version:\n $extDbRlsName / $extDbRlsVer\n";
  }

  my @dbNames = split /\_/, $extDbRlsName;

  my $path = "/eupath/data/EuPathDB/manualDelivery/$projectName/". $dbNames[0]. "/". $dbNames[1]. "/". $dbNames[2] ."/". $extDbRlsVer . "/final";
  my $file = "$path/isolateSNPs.txt";

  my $dbh = $self->getQueryHandle();
  my $sql = <<EOSQL;
SELECT etn.source_id, nal.start_min, nal.end_max 
FROM   dots.snpfeature snp, dots.nalocation nal, dots.externalnasequence etn
WHERE snp.na_feature_id = nal.na_feature_id
  AND snp.na_sequence_id = etn.NA_SEQUENCE_ID
  AND snp.source_id = ?
EOSQL

  my $sth = $dbh->prepare($sql);
  my @strains;

  open (OUT, ">$path/isolateSNPs.gff");
  open (F, $file);
  while(<F>) {
    chomp;
    next if /^#/;
    next if /^(Origin|Source|Note|Identifier)/i;

    if(/^Strain/i) {
      @strains = split /\t/, $_; 
      shift @strains;
      next;
    }   

    my @snps = split /\t/, $_; 
    my $id = shift @snps;
    $id =~ s/\s//g;
    @snps = map { $_ =~ s/\s//g; $_ } @snps;

    $sth->execute($id);
    my ($seqid, $start, $stop) = $sth->fetchrow_array;

    next unless $seqid;
    print OUT "$seqid\tBroad\t". $dbNames[2]. "\t$start\t$stop\t.\t.\t.\tID $id". "_". $dbNames[2]. "; Allele ";

    my $count = 0;
    foreach my $snp (@snps) {
      my $strain = $strains[$count];
      next unless $snp;
      print OUT "\"$strain:$snp\" ";
      $count++;
    }

    print OUT "\n";
  }

  $sth->finish;

  close OUT;
  close F;
}
