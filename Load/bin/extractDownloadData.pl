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

my ($help, $downloadDir, $gusConfigFile, $build_number);
my $projectName = 'UniDB';

&GetOptions('help' => \$help,
            'downloadDir=s' => \$downloadDir,
            'gusConfigFile=s' => \$gusConfigFile,
            'build_number=i' => \$build_number,
    );

if($help) {
  &usage();
  exit;
}

unless($build_number) {
  &usage("--build_number is required!");
  exit;
}

unless($gusConfigFile) {
  &usage("--gusConfigFile is required!");
  exit;
}

unless(-e $gusConfigFile) {
  &usage("gus.config file not found: $gusConfigFile");
  exit;
}


# Database connection, to map fileAbbrevs to organisms
my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $usr = $gusconfig->{props}->{databaseLogin};
my $pwd = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};


my %orgName;
getOrgNames();



## To get the projRelpaths (release-xyz)
$downloadDir = "/var/www/Common/apiSiteFilesMirror/downloadSite/" if (!$downloadDir);

my $projPath = $downloadDir . "UniDB/release-$build_number";
my @projRelpaths;
# print STDERR "Project path!! $projPath \n"; 
opendir( my $DIR, $projPath );

while (my $entry = readdir $DIR) {
  push (@projRelpaths, $entry);
}

my %fileInfo;

  ###   ONLY fasta and gff files, say
  # my @files = File::Find::Rule->file()->name('*.fasta','*.gff')->in($path);

  ### ALL FILES
  my @files = File::Find::Rule->file()->name('*')->in($projPath);

  my $count = 1;
  foreach my $f (sort @files){
    $count++ ; 
    print STDERR "$count FILE \n" if ($count % 100==0);
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

  
  my $bld = $build_number;
  
    my $name = $f;
    $name =~ s{^.*/}{};
    # Neglect "Build_number" files
    next if ($name eq 'Build_number');

    my $org = $f;
    $org =~s/^(.)*release\-\d+\.?\d*\/([a-zA-Z0-9\-\_.]+).*$/$2/;  #  "Pfalciparum 3D7", etc
    # needed for just "Orf50.gff.gz" files only
    if ($name eq 'Orf50.gff.gz'){
      $name = $projectName . "-" . $bld . "_" . $org . "_" . $name;
    }

    # set the full organism name
    if (my $o = $orgName{$org}){
      #print STDERR "abbrev = $org, and name = $o\n";
      $org = $o;
    }
    else {print STDERR "abbrev = $org NOT MAPPED!!\n";
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

    if ($fileInfo{$key}->{file_format} eq  "zip" || $fileInfo{$key}->{file_format} eq  "gzip"){
	$fileInfo{$key}->{file_format} = "gz";
    }


    $fileInfo{$key}->{checksum} = md5_hex(do { local $/; IO::File->new("$f")->getline });
    $fileInfo{$key}->{size} = -s $f;

    my $path =$f;
    $path =~ s/$downloadDir$projectName/\/common\/downloads/;
    $fileInfo{$key}->{path} = $path;


    # set the data_type OR the file_type
    $fileInfo{$key}->{data_type} = 'Genome' if ($fileInfo{$key}->{filename} =~/_Genome.fasta/);
    $fileInfo{$key}->{data_type} = 'Transcript' if ($name =~/_AnnotatedTranscripts.fasta/);
    $fileInfo{$key}->{data_type} = 'Protein' if ($f =~/^(.)+_AnnotatedProteins.fasta/);
    $fileInfo{$key}->{data_type} = 'CDS' if ($f =~/^(.)+_AnnotatedCDSs.fasta/);
    $fileInfo{$key}->{data_type} = 'EST' if ($f =~/^(.)+_ESTs.fasta/);
    $fileInfo{$key}->{data_type} = 'ORF' if ($f =~/Orf50.gff.gz/);
    $fileInfo{$key}->{data_type} = 'Full GFF' if (($f =~/.gff/) && !($f =~/Orf50.gff.gz/));
    $fileInfo{$key}->{data_type} = 'Codon Usage' if ($f =~/^(.)+_CodonUsage.txt/);
    $fileInfo{$key}->{data_type} = 'Interpro Domains' if ($f =~/^(.)+_InterproDomains.txt/);
    $fileInfo{$key}->{data_type} = 'Gene Ontology (GO)' if ($f =~/_GO.gaf/);
    $fileInfo{$key}->{data_type} = 'Gene Aliases' if ($f =~/^(.)+_GeneAliases.txt/);
    $fileInfo{$key}->{data_type} = 'Popset' if ($f =~/^(.)+_Isolates.fasta/);
    $fileInfo{$key}->{data_type} = 'Popset' if ($f =~/^(.)+Isolate.txt/);
    $fileInfo{$key}->{data_type} = '' if (!$fileInfo{$key}->{data_type});
    # set the category
    my $dt = $fileInfo{$key}->{data_type};
    $fileInfo{$key}->{category} = '';
    $fileInfo{$key}->{category} = 'Sequence' if (($dt eq 'Codon Usage')||
						 ($dt eq 'Genome')||
						 ($dt eq 'CDS')||
						 ($dt eq 'Transcript')||
						 ($dt eq 'Protein')||
						 ($dt eq 'EST')||
						 ($dt eq 'ORF')
						);
    $fileInfo{$key}->{category} = 'Function prediction' if $dt eq 'Gene Ontology (GO)';
    $fileInfo{$key}->{category} = 'Function prediction' if $dt eq 'Interpro Domains';
    $fileInfo{$key}->{category} = 'Annotation and Curation' if $dt eq 'Gene Aliases';
    $fileInfo{$key}->{category} = 'Annotation and Curation' if $dt eq 'Full GFF';
    $fileInfo{$key}->{category} = 'Genetic Variation' if $dt eq 'Popset';
    $fileInfo{$key}->{category} = 'LinkOuts' if ($f =~/^(.)+_NCBILinkout_(.)+.xml/);

    #PRINT THE RECORD
    print $key
    ."\t". $fileInfo{$key}->{filename}
    ."\t". $fileInfo{$key}->{path}
    ."\t". $fileInfo{$key}->{org}
    ."\t". $fileInfo{$key}->{build}
    ."\t". $fileInfo{$key}->{category}
    ."\t". $fileInfo{$key}->{data_type}
    ."\t". $fileInfo{$key}->{file_format}
    ."\t". $fileInfo{$key}->{size}
    ."\t". $fileInfo{$key}->{checksum}
    ."\n";

  }
  print STDERR "ALL FILES DONE.";



sub getOrgNames{
  my $dbh = DBI->connect($dsn, $usr, $pwd) ||  die "Couldn't connect to database: " . DBI->errstr;

  my $sql =
  q{SELECT organism_name as organism,
           name_for_filenames as fileAbbrev
    FROM apidbtuning.organismAttributes
    UNION
    SELECT distinct  ea.organism,
           regexp_replace(ea.organism, '^(\S)\S+\s+(\S+).*$', '\1\2') as  fileAbbrev
    FROM webready.estattributes_p ea};

  my $sth = $dbh->prepare($sql) || die "Couldn't prepare the SQL statement: " . $dbh->errstr;
  $sth->execute() ||  die "Couldn't execute statement: " . $sth->errstr;
  while (my ($organism, $fileAbbrev) = $sth->fetchrow_array()) {
    #print "DEBUG $organism $fileAbbrev \n";
    $orgName{$fileAbbrev} = $organism;
  }
  $dbh->disconnect;
}


sub usage {
  my $m = shift;
  if($m) {
    print STDERR "$m\n\n";
  }
  print STDERR "usage:\nperl extractDownloadData.pl --gusConfigFile <GUS_CONFIG> --build_number <BUILD> [--downloadDir <DIR>]\n";
  exit;
}
