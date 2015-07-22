#!/usr/bin/perl

use strict;

use Getopt::Long;

use Data::Dumper;

use lib "$ENV{GUS_HOME}/lib/perl";

use List::MoreUtils qw(uniq first_index indexes);

my ($inDir, $outDir, $configFile, $idFieldName, $dateFieldName, $parentIdFieldName, $help,);

&GetOptions('help|h' => \$help,
                      'input_directory=s' => \$inDir,
                      'output_directory=s' => \$outDir,
                      'id_field=s' => \$idFieldName,
                      'date_field=s' => \$dateFieldName,
                      'parent_id_field=s' => \$parentIdFieldName,
                      'header_config_file=s' => \$configFile,
           );
$idFieldName ='id' unless $idFieldName;
$dateFieldName = 'date' unless $dateFieldName;

$outDir = defined $outDir ? $outDir : $inDir."/FileTranslatorCfg";
$outDir =~ s/\/+/\//g;

mkdir $outDir unless ( -d $outDir );

my $idCfgHeader = "OUTPUT";
my $parentIdCfgHeader ="INPUT";
my $dateCfgHeader = "Parameter Values [Date]";
my $cfgFileOpener = qq(<?xml version="1.0"  encoding="ISO-8859-1" ?>

<!DOCTYPE cfg SYSTEM "FileTranslatorCfg.dtd" >


<cfg functions_class='GUS::Community::FileTranslator::Functions'>
  <inputs qualifier_row_present='0'>
      <header>);
	  
my $cfgMiddleBlock = qq(    </header>
  </inputs>

  <outputs>);
  
my $cfgFileCloser = qq(  </outputs>
</cfg>);

my ($header_hash) =parseHeaderConfig($configFile,$idCfgHeader,$parentIdCfgHeader,$dateCfgHeader,$idFieldName,$dateFieldName,$parentIdFieldName);

opendir(DH, $inDir) or die "unable to open dir $inDir: $!";
my @inputFiles = readdir(DH);
closedir(DH);

my $unhandledFields = {};
my $skippedFiles;
foreach my $inFile (@inputFiles) {
  next if ( -d "$inDir/$inFile");
  my ($inputBlock,$outputBlock);
  open (FILE, "$inDir/$inFile") or die "unable to open the input file $inDir/$inFile for reading: $!";
  my $header = <FILE>; 
  
  $header =~ s/\n|\r//g;
  my @fields = split ("\t" , $header);

   my $dateFieldIdx = first_index {  $_ =~ /^$dateFieldName$/i } @fields;
   unless ( $dateFieldIdx == -1 ) {
     splice (@fields,$dateFieldIdx,1);
     unshift (@fields, $dateFieldName);
   }
  
   if (defined $parentIdFieldName) {
     my $parentIdFieldIdx = first_index { $_ =~ /^$parentIdFieldName$/i } @fields;
     unless ( $parentIdFieldIdx == -1 ) {
       splice (@fields,$parentIdFieldIdx,1);
       unshift (@fields, $parentIdFieldName);
     }
   } 
   my $idFieldIdx = first_index { $_ =~ /^$idFieldName$/i } @fields;
   push (@$skippedFiles, $inFile) if $idFieldIdx == -1;
   splice (@fields,$idFieldIdx,1);
   unshift (@fields, $idFieldName);
  
  foreach my $field (@fields){
    $field = lc($field);
    unless (exists $header_hash->{$field}) {
      push ( @{$unhandledFields->{$inFile}} , $field );
      next;
    }
    my $required = ($field =~ /^$idFieldName|$dateFieldName|$parentIdFieldName$/i) ? 1 : 0 if defined $parentIdFieldName;
    my $required = ($field =~ /^$idFieldName|$dateFieldName$/i) ? 1 : 0 unless defined $parentIdFieldName;
    my ($inputElement,$outputElement) = processFieldValue ($field,$header_hash,$required,$idFieldName,$dateFieldName,$parentIdFieldName);
    push (@$inputBlock, $inputElement);
    push (@$outputBlock, $outputElement) if (defined $outputElement);
  }
  
  unshift (@$inputBlock, $cfgFileOpener);
  push (@$inputBlock, $cfgMiddleBlock);
  push (@$outputBlock, $cfgFileCloser);
  
  my $cfgFileText = join ("\n", @$inputBlock);
  $cfgFileText .= "\n".join ("\n", @$outputBlock);
  
  my $outFile = $inFile;
  $outFile .= ".cfg";
  my $outPath = "$outDir/$outFile";
  $outPath =~s/\/+/\//g;
  open (OUT, ">$outPath") or die "unable to open the cfg file $outPath for writing: $!";
  print OUT $cfgFileText;
}

if (scalar (keys (%$unhandledFields)) || scalar $skippedFiles) {
  my $logPath = "$outDir/makeTranslatorCfg.log";
  print STDERR "errors found in your configuration, please review the log file $logPath for details";

  my $logLines;
  if (scalar $skippedFiles) {
    if (scalar $skippedFiles == 1) {
      my $skippedFile = $skippedFiles->[0];
      push (@$logLines, "The file $skippedFile was skipped because it does not contain a field matching the id field name $idFieldName.");
    }
    else {
      push (@$logLines, "The following files have been skipped because they do not contain a field matching the id field name $idFieldName.");
      push @$logLines, @$skippedFiles ;
    }
    push (@$logLines, "Please rerun this script with the appropriate id field name");
  }
  if (scalar (keys (%$unhandledFields))) {
    foreach my $file (keys %$unhandledFields) {
      my @fields = @{$unhandledFields->{$file}};
      push (@$logLines, "The file $file contains the following field(s) which are not in the header config file.");
      push @$logLines, @fields;
    }
    push (@$logLines ,"Please update the header config file and rerun this script");
  }
  open (LOG,">$logPath") or die "unable to open the log file $logPath for writing: $!";
  my $logFileText = join ("\n", @$logLines);
  print LOG  $logFileText;
}

sub parseHeaderConfig {
  my ($configFile,$idCfgHeader,$parentIdCfgHeader,$dateCfgHeader,$idFieldName,$dateFieldName,$parentIdFieldName) =@_;
  open(CFG, $configFile)or die "unable to open the config file $configFile for reading: $!";;
  my $ignoreFileHeader = <CFG>;
  my $header_hash = {};
  my @death_knell;
  for my $row (<CFG>) {
    $row=~s/\n|\r//g;
    my ($old_header, $new_header, $function, $functionVariableString, $exclude) = split("\t", $row);
    
    $exclude = undef if (!defined $exclude || $exclude !~/\w/ || $exclude =~/false/i) ;
    $function = '' if (!defined $function || $function !~/\w/) ;
    
    $functionVariableString = ((length ($functionVariableString)) && ($functionVariableString =~/\w/)) ? $functionVariableString : "\$$old_header\\t$old_header" ;

    $new_header =  $new_header =~ /\w/ ? $new_header : $old_header;
    my $key = $old_header;
    if ($old_header =~/^$idFieldName$/i) {
      push (@death_knell, "the id field cannot be excluded. Please correct the configuration for $idFieldName, or provide the correct id field name") if ($exclude);
      $new_header = $idCfgHeader;
    }

    if (defined $parentIdFieldName && $old_header =~/^$parentIdFieldName$/i) {
      push (@death_knell, "the parent id field cannot be excluded. Please correct the configuration for $parentIdFieldName, or provide the correct parent id field name") if ($exclude);
      $new_header = $parentIdCfgHeader;
    }

    if ($old_header =~/^$dateFieldName$/i) {
      $function = "formatDate" unless ($function =~ /\w/);
      push(@death_knell, "the date field cannot be excluded. Please correct the configuration for $dateFieldName, or provide the correct date field name") if ($exclude);
      $new_header = $dateCfgHeader;
    }

    $header_hash->{$key}->{old_header} = $old_header;
    $header_hash->{$key}->{new_header} = $new_header;
    $header_hash->{$key}->{function} = $function;
    $header_hash->{$key}->{variables} = $functionVariableString;
    $header_hash->{$key}->{exclude} = $exclude;
  }

  unless (exists $header_hash->{$dateFieldName}) {
    unshift (@death_knell, "date field, $dateFieldName not found, please check that you have provided the correct date field name");
  }
  unless (exists $header_hash->{$idFieldName}) {
    unshift (@death_knell, "id field, $idFieldName not found, please check that you have provided the correct id field name");
  }
  if (scalar @death_knell) {
    my $fail_string = join ("\n",@death_knell);
    die "\n\n$fail_string\n";
  } 
  return $header_hash;
}  

sub processFieldValue {
  my ($field,$header_hash,$required,$idFieldName,$dateFieldName,$parentIdFieldName) = @_;
  my $old_header = $header_hash->{$field}->{old_header};
  my $inputElement = "       <col header_val='$old_header' req='$required' name='$old_header'/>";
  my $outputElement;
  my $key = lc($field);
  my $function = $header_hash->{$key}->{function};
  my $new_header = $header_hash->{$key}->{new_header};
 
  unless ($old_header =~ /^$idFieldName$|^$dateFieldName$/) {
    unless  (defined $parentIdFieldName && $old_header =~ /^$parentIdFieldName/) {
      $new_header = "Characteristics [$new_header]"  ;
    }
  }
  unless (defined $header_hash->{$key}->{exclude}) {
    my @outputElementLines;   
    if ($function eq '') {
      push (@outputElementLines, "   <map name='$new_header'>");
      push (@outputElementLines, "      <in name='$old_header'/>");
      push (@outputElementLines, "    </map>");
    }
    else {
      my  $variables = $header_hash->{$key}->{variables};
      push (@outputElementLines, "    <idmap function='$function'");
      push (@outputElementLines, "         output_header='$new_header'");
      push (@outputElementLines, "         mapkey='$variables'>");
      push (@outputElementLines, "      <in name='$old_header'/>");
      push (@outputElementLines, "     </idmap>");      
    }
    $outputElement = join("\n", @outputElementLines);
  }
  return ($inputElement,$outputElement);   
}

