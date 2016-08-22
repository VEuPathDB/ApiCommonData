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

# replaces arg1 with arg2 and makes a tscp original file

use strict;
use Getopt::Long;

my($ask,$nb,$old,$new,$fileOrDir,@noDotFiles,@inputFiles,$fileNamePattern);

&GetOptions("old=s" => \$old, 
            "new=s" => \$new,
            "file_or_dir=s" => \$fileOrDir,
	    "filename_pattern=s" => \$fileNamePattern,
            );

if (!$old){
print <<endOfUsage;
Replace.perl usage:

  replace.pl -old \"string to be replaced\" -new \"string to replace it with\" -file_or_dir \"file or directory where the string has to be replaced\" -filename_pattern \"perl regex specifying a file pattern, for e.g. - \"\\S+\\.gff\"\"

  A time-stamped-copy will be made of the original file for backup purposes.

endOfUsage


}


$fileNamePattern = "\S+" unless $fileNamePattern;

 if (-d $fileOrDir) {
#    opendir(DIR, $fileOrDir) || die "Can't open directory '$fileOrDir'";
#    @noDotFiles = grep { $_ ne '.' && $_ ne '..' } readdir(DIR);
#    @inputFiles = map { "$fileOrDir/$_" } @noDotFiles;
     
     &recurse($fileOrDir);
}else{
    push(@inputFiles,$fileOrDir);
}

foreach my $file (@inputFiles){
  my $new_file = "";
  my $replace = 0;
  open (F, "$file") || die "Can't open input file '$file'\n";;
  while (<F>) {
    while (m/$old/g) {
        $replace++;
        $_ =~ s|$old|$new|;
    } 
    $new_file .= $_;
  }
  if ( $replace >= 1) {
    print "$replace replacements made in $file\n";
    system ("cp $file $file.bak");
    system ("rm $file.bak");
    open (OUT, ">$file");
    print OUT $new_file;
    close OUT;
  }
}

sub recurse($) {
  my($path) = @_;


  $path .= '/' if($path !~ /\/$/);



  for my $eachFile (glob($path.'*')) {

    ## if the file is a directory
    if( -d $eachFile) {

      recurse($eachFile);
    } else {


	if ($eachFile  ne '.$'  && $_ ne '..$'){


		if($eachFile =~ /$fileNamePattern/){
		    print ("Filename: $eachFile\n");
		    push(@inputFiles,$eachFile);
		}
		
	}
    }
}
}


