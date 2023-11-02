#!usr/bin/perl
use strict;
use warnings;

use Data::Dumper;

use File::Find::Rule;
use Digest::MD5 qw(md5_hex);
use IO::File;
use Getopt::Long;
use DBI;
use CBIL::Util::PropertySet;

my ($help, $downloadDir, $component, $gusConfigFile);

&GetOptions('help' => \$help,
            'downloadDir=s' => \$downloadDir,
            'component=s' => \$component,
            "gusConfigFile=s" => \$gusConfigFile,
    );

if($help) {
  &usage();
  exit;
}

unless(-e $gusConfigFile) {
  &usage("gus.config file not found!");
  exit;
}

unless($component) {
  &usage("Component must be specified");
  exit;
}


# Database connection, to map fileAbbrevs to organisms
my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $usr = $gusconfig->{props}->{databaseLogin};
my $pwd = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};
my $instance = $dsn;

#print STDERR "$instance, $usr, $pwd --CONECT NOW \n";

my %orgName;
getOrgNames();



#Get Organism Abbrev used for EST (like Pfalciparum is Plasmodium falciparum)
my %orgEst;
getOrgForEst();


## To get the projRelpaths (release-xyz)
$downloadDir = "/var/www/Common/apiSiteFilesMirror/downloadSite/" if (!$downloadDir);

my $projPath = $downloadDir . $component;
my @projRelpaths;

opendir( my $DIR, $projPath );

while (my $entry = readdir $DIR) {
  #next unless -d $projPath . '/' . $entry;
  next if $entry eq '.' or $entry eq '..' or $entry eq 'Current_Release' or $entry eq 'pathwayFiles';
  next unless $entry =~/release(\S)+/;


  ##  ignore release nums less than 23
  my $minBld = $entry;
  $minBld =~s/^(.)*release\-(\d+\.?\d*)(.)*/$2/;  # gives 55, etc
  next unless ($minBld >=24);
  #print "MIN BLD = $minBld \n";

#    next unless $entry =~/release-64/;

  push (@projRelpaths, $entry);
}

my %fileInfo;

#my $path = $downloadDir . $component . "/" . $build . "/";
foreach my $path (sort @projRelpaths) {
  $path = $downloadDir . $component . "/" . $path . "/";

  ###   ONLY fasta and gff files, say
  # my @files = File::Find::Rule->file()->name('*.fasta','*.gff')->in($path);

  ### ALL FILES
  my @files = File::Find::Rule->file()->name('*')->in($path);
  # print Dumper @files;


  foreach my $f (@files){
    ## Some of the exceptions!
    next if $f =~m/(.)*\~$/;
    next if ($f =~/index.html/ || $f =~/index.shtml/);
    next if $f =~/pathwayFiles/;
    next if $f =~/Release/;
    next if $f =~/CURRENT/;
    next if $f =~/provisional/;
    next if $f =~/ReadMe/i;
    next if $f =~/WorkshopAnnotation/i;  # plas
    next if $f =~/misc/;  # plas
    next if $f =~/training/;  # toxo
    next if $f =~/HEADER/;  # toxo
    next if $f =~/Software/;  # toxo

    my $bld = $f;
    $bld =~s/^(.)*release\-(\d+\.?\d*)(.)*/$2/;  # gives 55, etc

    my $name = $f;
    $name =~ s{^.*/}{};
    # Neglect "Build_number" files
    next if ($name eq 'Build_number');

    my $org = $f;
    $org =~s/^(.)*release\-\d+\.?\d*\/([a-zA-Z0-9\-\_]+).*$/$2/;  #  "Pfalciparum 3D7", etc
    # needed for just "Orf50.gff" files only
    if ($name eq 'Orf50.gff'){
      $name = $component . "-" . $bld . "_" . $org . "_" . $name;
    }


    # set the full organism name
    if (my $o = $orgName{$org}){
      $org = $o;
    } elsif ($orgEst{$org}) { # org entries for ESTs
      $org = $orgEst{$org};
#    } else {
#      print "NO MAPPING for $org \n"; # no org assignment should NOT happen
    }

    #  my $key = $bld.$org.$name; # primary_key
    my $key = $bld.$name; # primary_key
    $fileInfo{$key}->{build} = $bld;
    $fileInfo{$key}->{org} = $org;
    $fileInfo{$key}->{filename} = $name;

    # set the file_format
    my ($type) = $f =~ /([^.]+)$/;
    if ($f =~m/\.tab\.(.*)+/ || $f =~m/\.diff/|| $f =~m/.pct/){
      $fileInfo{$key}->{file_format} = "tab";
    } elsif ($f =~m/profile(.*)sense(\s)*$/ || $f =~m/profile(.*)min(.*)$/){
      $fileInfo{$key}->{file_format} = "tab";
    } elsif (($f =~/\.txt\.(.*)/) || ($f =~/\.txt_\d+/) || ($f =~/\.rma/)){
      $fileInfo{$key}->{file_format} = "txt";
    } elsif ($f =~/quantProfiles/ || $f =~/profiles/){   ## toxo
      $fileInfo{$key}->{file_format} = "tab";
    } elsif ($f =~/\.fa/){   ## toxo
      $fileInfo{$key}->{file_format} = "fasta";
    }else{
      $type = 'xml' if $type eq 'xgmml';
      $type = 'html' if $type eq 'shtml';
      $fileInfo{$key}->{file_format} = $type;
    }


    $fileInfo{$key}->{checksum} = md5_hex(do { local $/; IO::File->new("$f")->getline });
    $fileInfo{$key}->{size} = -s $f;

    my $path =$f;
    $path =~ s/$downloadDir$component/\/common\/downloads/;
    $fileInfo{$key}->{path} = $path;


    # set the data_type OR the file_type
    $fileInfo{$key}->{data_type} = 'genome' if ($fileInfo{$key}->{filename} =~/_Genome.fasta/);
    $fileInfo{$key}->{data_type} = 'transcript' if ($name =~/_AnnotatedTranscripts.fasta/);
    $fileInfo{$key}->{data_type} = 'protein' if ($f =~/^(.)+_AnnotatedProteins.fasta/);
    $fileInfo{$key}->{data_type} = 'CDS' if ($f =~/^(.)+_AnnotatedCDSs.fasta/);
    $fileInfo{$key}->{data_type} = 'EST' if ($f =~/^(.)+_ESTs.fasta/);
    $fileInfo{$key}->{data_type} = 'ORF' if ($f =~/Orf50.gff/);
    $fileInfo{$key}->{data_type} = 'Full GFF' if (($f =~/.gff/) && !($f =~/Orf50.gff/));
    $fileInfo{$key}->{data_type} = 'Codon Usage' if ($f =~/^(.)+_CodonUsage.txt/);
    $fileInfo{$key}->{data_type} = 'Interpro Domains' if ($f =~/^(.)+_InterproDomains.txt/);
    $fileInfo{$key}->{data_type} = 'Gene Ontology (GO)' if ($f =~/_GO.gaf/);
    $fileInfo{$key}->{data_type} = 'Gene Aliases' if ($f =~/^(.)+_GeneAliases.txt/);
    $fileInfo{$key}->{data_type} = 'Popset' if ($f =~/^(.)+_Isolates.fasta/);
    $fileInfo{$key}->{data_type} = 'Popset' if ($f =~/^(.)+Isolate.txt/);
    $fileInfo{$key}->{data_type} = '' if (!$fileInfo{$key}->{data_type});

    # set the category
    $fileInfo{$key}->{category} = '';
    $fileInfo{$key}->{category} = 'Sequence' if (($fileInfo{$key}->{data_type} eq 'Codon Usage')||
						 ($fileInfo{$key}->{data_type} eq 'genome')||
						 ($fileInfo{$key}->{data_type} eq 'CDS')||
						 ($fileInfo{$key}->{data_type} eq 'transcript')||
						 ($fileInfo{$key}->{data_type} eq 'protein')||
						 ($fileInfo{$key}->{data_type} eq 'EST')||
						 ($fileInfo{$key}->{data_type} eq 'ORF')
						);
    $fileInfo{$key}->{category} = 'Function prediction' if $fileInfo{$key}->{data_type} eq 'Gene Ontology (GO)';
    $fileInfo{$key}->{category} = 'Function prediction' if $fileInfo{$key}->{data_type} eq 'Interpro Domains';
    $fileInfo{$key}->{category} = 'Annotation and Curation' if $fileInfo{$key}->{data_type} eq 'Gene Aliases';
    $fileInfo{$key}->{category} = 'Annotation and Curation' if $fileInfo{$key}->{data_type} eq 'Full GFF';
    $fileInfo{$key}->{category} = 'Genetic Variation' if $fileInfo{$key}->{data_type} eq 'Popset';
    $fileInfo{$key}->{category} = 'LinkOuts' if ($f =~/^(.)+_NCBILinkout_(.)+.xml/);
  }
}

# print the tab-delimited records
foreach my $test (keys( %fileInfo )){
  print $test
  ."\t". $fileInfo{$test}->{filename}
  ."\t". $fileInfo{$test}->{path}
  ."\t". $fileInfo{$test}->{org}
  ."\t". $fileInfo{$test}->{build}
  ."\t". $fileInfo{$test}->{category}
  ."\t". $fileInfo{$test}->{data_type}
  ."\t". $fileInfo{$test}->{file_format}
  ."\t". $fileInfo{$test}->{size}
  ."\t". $fileInfo{$test}->{checksum}
  ."\n";

}


sub getOrgNames{
  my $dbh = DBI->connect("dbi:Oracle:$instance", $usr, $pwd) ||  die "Couldn't connect to database: " . DBI->errstr;

  my $sql =
  q{select name_for_filenames as fileAbbrev, n.name as organism
    from apidb.organism o, sres.taxonName n
    where o.taxon_id = n.taxon_id(+)
    and n.name_class = 'scientific name'
    order by name_for_filenames };

  my $sth = $dbh->prepare($sql) || die "Couldn't prepare the SQL statement: " . $dbh->errstr;
  $sth->execute() ||  die "Couldn't execute statement: " . $sth->errstr;
  while (my ($fileAbbrev, $organism) = $sth->fetchrow_array()) {
    $orgName{$fileAbbrev} = $organism;
  }
  $dbh->disconnect;
}

sub getOrgForEst {
  my $dbh = DBI->connect("dbi:Oracle:$instance", $usr, $pwd) ||  die "Couldn't connect to database: " . DBI->errstr;

  my $sql =
  q{with estOrgs as (
   select distinct ea.organism,
          regexp_replace(ea.organism, '(\S)\S+\s* ', '\1') as briefname
   from apidbtuning.estattributes ea)
  select distinct  fa.organism, eo.organism
  from apidb.fileAttributes fa, estOrgs eo
  where fa.organism = eo.briefname};


  my $sth = $dbh->prepare($sql) || die "Couldn't prepare the SQL statement: " . $dbh->errstr;
  $sth->execute() ||  die "Couldn't execute statement: " . $sth->errstr;
  while (my ($fileAbbrev, $organism) = $sth->fetchrow_array()) {
    $orgEst{$fileAbbrev} = $organism;
  }
  $dbh->disconnect;
}


sub usage {
  my $m = shift;
  if($m) {
    print STDERR "$m\n\n";
  }
  print STDERR "usage:\nperl extractDownloadData.pl  --gusConfigFile <GUS_CONFIG> --component=s > [FILE]\n";
  exit;
}
