#!/usr/bin/perl
#vvvvvvvvvvvvvvvvvvvvvvvvv GUS4_STATUS vvvvvvvvvvvvvvvvvvvvvvvvv
  # GUS4_STATUS | SRes.OntologyTerm              | auto   | absent
  # GUS4_STATUS | SRes.SequenceOntology          | auto   | absent
  # GUS4_STATUS | Study.OntologyEntry            | auto   | absent
  # GUS4_STATUS | SRes.GOTerm                    | auto   | absent
  # GUS4_STATUS | Dots.RNAFeatureExon            | auto   | absent
  # GUS4_STATUS | RAD.SageTag                    | auto   | absent
  # GUS4_STATUS | RAD.Analysis                   | auto   | absent
  # GUS4_STATUS | ApiDB.Profile                  | auto   | absent
  # GUS4_STATUS | Study.Study                    | auto   | absent
  # GUS4_STATUS | Dots.Isolate                   | auto   | absent
  # GUS4_STATUS | DeprecatedTables               | auto   | absent
  # GUS4_STATUS | Pathway                        | auto   | absent
  # GUS4_STATUS | DoTS.SequenceVariation         | auto   | absent
  # GUS4_STATUS | RNASeq Junctions               | auto   | absent
  # GUS4_STATUS | Simple Rename                  | auto   | absent
  # GUS4_STATUS | ApiDB Tuning Gene              | auto   | absent
  # GUS4_STATUS | Rethink                        | auto   | absent
  # GUS4_STATUS | dots.gene                      | manual | unreviewed
die 'This file has broken or unreviewed GUS4_STATUS rules.  Please remove this line when all are fixed or absent';
#^^^^^^^^^^^^^^^^^^^^^^^^^ End GUS4_STATUS ^^^^^^^^^^^^^^^^^^^^

use strict;

use Getopt::Long;

use File::Basename;

use Data::Dumper;

my ($inFile, $outFile, $help, $configFile);



&GetOptions('help|h' => \$help,
            'inFile=s' => \$inFile,
            'outFile=s' => \$outFile,
	    'configFile=s' => \$configFile
           );

my $configDesc =
"sample config file:
skip,^genbank_id
delimiter,\t
source_id,0
description,2
description,3
sequence,4

must container delimiter,value
other key,value pairs are column_name,column_number
where column_name conforms to the names in this parser 
and column number is the position in the input file

column names for gene/protein
source_id,
description,
seqMolWt,
seqPI,
score,
percentCoverage,
sequenceCount,
spectrumCount,
sourcefile,
column names for peptides
start,
end,
observed,
mr_expect,
mr_calc,
delta,
miss,
sequence,
modification,
query,
hit,
ions_score

Input file must have consistent columns throughout and group all peptides with the source_id hit.
sample fit snippet:
TVAG_273260     alpha-amylase, putative 3
                        FDLLSAIAQTEDGTK
                        GDLDGITNALDYIK
                        NQDQFTDAYWNIHK
";

&usage() if($help);
&usage("Input tab delimited file is required") unless(-e $inFile);
&usage("Output file name is required") unless($outFile);
&usage("Config file is required, $configDesc") unless(-e $configFile);
my $expName = basename($inFile, ".txt");


open (CONFIG,$configFile) || die "Can't open config file $configFile for reading\n$configDesc\n";

my %configs;

while(<CONFIG>){
  chomp;
  next 
  die "Config format not correct, should be key,value on each line" unless $_ =~ /^\S+\,\S+$/;
  my ($key,$val) = split (/,/,$_);
  $configs{$key}=$val;
}

close (CONFIG);

my %uniqueSeq = ();

my $sourceId = "";

my %printHsh = ();

open (INFILE, "$inFile") || die "Can't open $inFile for reading\n";

while (<INFILE>){

  chomp;

  next if ($configs{'skip'} and $_ =~ /$configs{'skip'}/);

  die "Must provider a delimiter regex in config\n $configDesc\n" unless ($configs{'delimiter'});

  my @inFileArr = split(/$configs{'delimiter'}/, $_);

  if ($inFileArr[$configs{'source_id'}] && (scalar (keys %printHsh) >= 1)) {
    &printOutFile();
    %printHsh = ();
    %uniqueSeq = ();
    $sourceId = "";
  }



  if ($inFileArr[$configs{'source_id'}]) {

    $printHsh{'description'}=$configs{'description'} ? $inFileArr[$configs{'description'}] : "";
    $printHsh{'seqMolWt'}=$configs{'seqMolWt'} ? $inFileArr[$configs{'seqMolWt'}] : "";
    $printHsh{'seqPI'}=$configs{'seqPI'} ? $inFileArr[$configs{'seqPI'}] : "";
    $printHsh{'score'}=$configs{'score'} ? $inFileArr[$configs{'score'}] : "";
    $printHsh{'percentCoverage'}=$configs{'percentCoverage'} ? $inFileArr[$configs{'percentCoverage'}] : "";
    $printHsh{'spectrumCount'}=$configs{'spectrumCount'} ? $inFileArr[$configs{'spectrumCount'}] : "";
    $printHsh{'sourcefile'}=$configs{'sourcefile'} ? $inFileArr[$configs{'sourcefile'}] : "";
    $printHsh{'sourceId'}=$inFileArr[$configs{'source_id'}];
  }

  if ($inFileArr[$configs{'sequence'}]) {

    my $pepHsh = &getPepHsh(\@inFileArr);

    push (@{$printHsh{'peptides'}}, $pepHsh);

  }

  $printHsh{'sequenceCount'}=(scalar (keys %uniqueSeq));

}

&printOutFile();

close (INFILE);

sub getPepHsh {
  my ($inFileArr) = @_;

  my %pepHsh;

  my $sequence = $inFileArr->[$configs{'sequence'}];


  $uniqueSeq{$sequence}++;

  $pepHsh{$sequence}->{'start'} = $configs{'start'} ?  $inFileArr->[$configs{'start'}] : "";

  $pepHsh{$sequence}->{'end'} = $configs{'end'} ? $inFileArr->[$configs{'end'}] : "";

  $pepHsh{$sequence}->{'observed'} = $configs{'observed'} ? $inFileArr->[$configs{'observed'}] : "";

  $pepHsh{$sequence}->{'mr_expect'} = $configs{'mr_expect'} ?  $inFileArr->[$configs{'mr_expect'}] : "";

  $pepHsh{$sequence}->{'mr_calc'} = $configs{'mr_calc'} ? $inFileArr->[$configs{'mr_calc'}] : "";

  $pepHsh{$sequence}->{'delta'} = $configs{'delta'} ? $inFileArr->[$configs{'delta'}] : "";

  $pepHsh{$sequence}->{'miss'} = $configs{'miss'} ? $inFileArr->[$configs{'miss'}]  : "";

  $pepHsh{$sequence}->{'modification'} = $configs{'modification'} ? $inFileArr->[$configs{'modification'}] : "";

  $pepHsh{$sequence}->{'query'} = $configs{'query'} ? $inFileArr->[$configs{'query'}] : "";

  $pepHsh{$sequence}->{'hit'} = $configs{'hit'} ? $inFileArr->[$configs{'hit'}] : "";

  $pepHsh{$sequence}->{'ions_score'} = $configs{'ions_score'} ? $inFileArr->[$configs{'ions_score'}] : "";

  return \%pepHsh;
}

sub printOutFile {
  open (TABF, ">> $outFile") or die "could not append to $outFile\n";

    print TABF 
      '# source_id',      "\t",
        'description',      "\t",
          'seqMolWt',         "\t",
            'seqPI',            "\t",
              'score',            "\t",
                'percentCoverage',  "\t",
                  'sequenceCount',    "\t",
                    'spectrumCount',    "\t",
                      'sourcefile',       "\n",
                        ;

    print TABF
      $printHsh{'sourceId'},       "\t",
        $printHsh{'description'},     "\t",
          $printHsh{'seqMolWt'},        "\t",
            $printHsh{'seqPI'},           "\t",
              $printHsh{'score'},           "\t",
                $printHsh{'percentCoverage'}, "\t",
                  $printHsh{'sequenceCount'},   "\t",
                    $printHsh{'spectrumCount'},   "\t",
                      $printHsh{'sourcefile'},      "\n",
                        ;


    print TABF
      '## start',      "\t",
        'end',           "\t",
          'observed',      "\t",
            'mr_expect',     "\t",
              'mr_calc',       "\t",
                'delta',         "\t",
                  'miss',          "\t",
                    'sequence',      "\t",
                      'modification',  "\t",
                        'query',         "\t",
                          'hit',           "\t",
                            'ions_score',    "\n",
                              ;

    foreach  my $pep (@{$printHsh{'peptides'}}) {
      foreach my $sequence (keys %{$pep}){
	print TABF
        $pep->{$sequence}->{'start'},         "\t",
          $pep->{$sequence}->{'end'},           "\t",
            $pep->{$sequence}->{'observed'},      "\t",
              $pep->{$sequence}->{'mr_expect'},     "\t",
                $pep->{$sequence}->{'mr_calc'},       "\t",
                  $pep->{$sequence}->{'delta'},         "\t",
                    $pep->{$sequence}->{'miss'},          "\t",
                      $sequence,      "\t",
                        $pep->{$sequence}->{'modification'},  "\t",
                          $pep->{$sequence}->{'query'},         "\t",
                            $pep->{$sequence}->{'hit'},           "\t",
                              $pep->{$sequence}->{'ions_score'},    "\n",
                                ;
      }
    }
  close TABF;

}

#--------------------------------------------------------------------------------

sub usage {
  my ($m) = @_;

  print STDERR "ERROR:  $m\n" if($m);

  print STDERR "usage: massSpecParser.pl --inFile DATA_FILE --outFile OUTPUT_FILE --configFile comma delimited list of delimiter,regex and column_name,column_position\n";

  print STDERR "file must have consistent columns throughout and group each set of peptides with the appropriate source_id, peptides must have a sequence\n";

  exit;
}

#--------------------------------------------------------------------------------


1;


