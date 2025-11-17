#!/usr/bin/perl

use strict;

use warnings;

use XML::Simple;

use Getopt::Long;

use File::Basename;

use Tie::IxHash;

use Data::Dumper;

use lib "$ENV{GUS_HOME}/lib/perl";

use DBI;

use List::MoreUtils qw(uniq);

use GUS::PluginMgr::Plugin;

use GUS::Model::SRes::OntologyTerm;

use GUS::Model::Study::Study;

my ($inFile, $configFile, $outFile, $table, $help, $valueMapFile,);

&GetOptions('help|h' => \$help,
            'configFile=s' => \$configFile,
	    'valueMapFile=s' =>\$valueMapFile,
           );

#&usage() if($help);
#&usage("Input dir containing csv files is required") unless(-e $inDir);
#&usage("Output file name is required") unless($outFile);

my $isHeader = 1;
my $headerSize = 0;
my @Header;

my $xmlObj = XML::Simple->new(KeepRoot =>1, ForceArray=>1);

my $ColumnMap;
my $pan_id = 1;
my $validHeader = 2;

my $mapHash = {};

if (defined $valueMapFile) {
  open (MAP, $valueMapFile) || die "Can't open $valueMapFile for reading : $!\n";
  foreach my $line (<MAP>){
    chomp $line;
    $line=~s/\r//g;
    my @row = split(/\t/,$line);
    my $characteristic = $row[0];
    my $skipCol = 1;

    foreach my $col (@row) {
      if ($skipCol) {
        $skipCol = 0;
        next;
      }
      my ($key,$value) = split (/:/,$col);
      $characteristic = lc($characteristic);
      $key = lc($key);
      $mapHash->{$characteristic}->{$key} = $value;
    }
  }
}

my ($studyName,$db_id,$protocol,$entity_type,$header_regexp,$input_lookup,$external_database_release_spec);
open (CONFIG, $configFile) || die "Can't open $configFile for reading : $!\n";
foreach my $line (<CONFIG>){
  chomp $line;
  next unless ($line); 
  if ($line =~ /study_name/) {
    $studyName = $line;
    $studyName =~ s/study_name://;
  }
  if ($line =~ /db_id/) {
    $db_id = $line;
    $db_id =~ s/db_id://;
	  }
  elsif ($line =~ /protocol/) {
    $protocol = $line;
    $protocol =~ s/protocol://;
  }
  elsif ($line =~ /header_regexp/) {
    $header_regexp = $line;
    $header_regexp =~ s/header_regexp://;
  }
  elsif ($line =~ /entity_type/) {
    $entity_type = $line;
    $entity_type =~ s/^\w*://;
  }
  elsif ($line =~ /input_lookup/) {
    $input_lookup = $line;
    $input_lookup =~ s/^\w*://;
  }
  elsif ($line =~ /external_database_release_spec/) {
    $external_database_release_spec = $line;
    $external_database_release_spec =~ s/external_database_release_spec://;
  }
  elsif ($line =~ /input_file/) {
    $inFile = $line;
    $inFile =~ s/input_file://;
  }
  elsif ($line =~ /output_file/) {
    $outFile = $line;
    $outFile =~ s/output_file://;
  }
}

my %studyHash; 
tie (%studyHash,'Tie::IxHash', (
                                "db_id" => $db_id,
                                "name" => {content => $studyName},
                                "description" => { content => ''},
                                "pubmed_id" => {content => ''},
                                "external_database_release" => {content => },
                                "source_id" => {content => ''},
                                "goal" => {content => ''},
                                "approaches" => {content => ''},
                                "results" => {content => ''},
                                "conclusions" => {content => ''},
                                "related_studies" => {content => ''},
                                "child_studies" => {content => ''},
                               )
    );

my $studyHash={};

my $official_header_hash ={};

if ($header_regexp) {
  my @header_terms = split(/,/,$header_regexp);
  foreach my $pair (@header_terms) {
    my ($pattern,$official) = split(/\|/,$pair);
    $official_header_hash->{$official} = $pattern;
  }
}

$studyHash->{"study"} = [\%studyHash,];
my $temp = $outFile.".tmp";
open (TEMP, ">$temp") || die "Can't open $outFile for reading\n";
print TEMP "<idf>\n".$xmlObj->XMLout([$studyHash])."</idf>\n";
print TEMP "<sdrf>\n";

my @tokens = split(/\|/,$external_database_release_spec);

my $ext_db_name = $tokens[0];
my $ext_db_version = $tokens[1];
my $lower_ext_db_name = lc($ext_db_name);
my $ext_db_sql = "select ex.external_database_release_id
                    from sres.externaldatabaserelease ex, sres.externaldatabase e
                   where e.external_database_id = ex.external_database_id
                     and ex.version = '$ext_db_version'
                     and lower(e.name) = '$lower_ext_db_name'";

my $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";

my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};
my $dbh = DBI->connect($dsn, $u, $pw, {RaiseError => 1}) or die DBI::errstr;

my $sh = $dbh->prepare($ext_db_sql);
$sh->execute();

my $ext_db_rls_id = $sh->fetchrow_array();

$sh->finish();

my $inputLookupSql = " select pan.name
                         from study.protocolappnode pan, study.characteristic ch, SRES.ONTOLOGYTERM ot
                        where pan.protocol_app_node_id = ch.protocol_app_node_id
                          and ot.ontology_term_id = ch.ONTOLOGY_TERM_ID
                          and ot.name = to_char(?)
                          and ch.value= to_char(?) 
                  ";
my $ilsh = $dbh->prepare($inputLookupSql);
my $inputValidateSql = " select pan.name
                           from study.protocolappnode pan
                          where name = to_char(?)
                  ";
my $ivsh = $dbh->prepare($inputValidateSql);


open (INFILE, $inFile) || die "Can't open $inFile for reading : $!\n";
my $protocolAppNodes = [];
my $protocolApps = [];
my $rowCount = 0;
my $SkippedInputs = [];
foreach my $row (<INFILE>){
  chomp $row;
  $row=~s/\r//;
  my %hash;
  if (!$row || $row=~m/^\w$/) {
    next;
  }

  if ($isHeader) {
    $ColumnMap = parseHeader($row);
    $isHeader=0;
    $validHeader = 1;
    next;
  }
  my $counter = 0;
  my $colCount;
  my $finalValues = [];

  my $values = [split ("\t" , $row)];
  $values =~s/(\r|\n)//g;

  my $inputCol;
  $inputCol = $ColumnMap->{"Input"} if (defined $ColumnMap->{"Input"}) ;
  my $outputCol = $ColumnMap->{"Output"};
  my $dateCol = $ColumnMap->{"Date"};
  my $chars =  $ColumnMap->{"characteristics"};
  my $nodeChars = parseCharacteristics($chars,$ext_db_rls_id,$external_database_release_spec,$values,$mapHash,$official_header_hash,$dbh);
#  print STDERR Dumper ($nodeChars);
#  exit;
  my $panHash = {};
  my $paHash = {};
  my $input;
  $input = $values->[$inputCol] if (defined $ColumnMap->{"Input"});
  my $input_source_id;
  my $unvalidated_input;
  my $validated_input;
  my $output  = $values->[$outputCol];
  my $protocolAppDate = $values->[$dateCol];
  my $input_pan_id =undef;
  my $output_pan_id =undef;
  my %inputHash; 
  my $inputNode;
  
  if (defined $input) {
    if ($input_lookup) {
      $input_source_id = $ilsh->fetchrow_array;
      print STDERR "no match found for $input\n" unless $input_source_id;
    }
    $unvalidated_input = (defined $input_lookup) ? $input_source_id : $input;
    $ivsh->execute($unvalidated_input);
    $validated_input = $ivsh->fetchrow_array;
    unless ($validated_input) {
      
      print STDERR "no match found for $input\n";
      push @$SkippedInputs,$input;
      next;
    }
    
    $input = $validated_input;
    $inputNode = qq(
   <protocol_app_node addition="" id="$pan_id">
      <type></type>
      <subtype></subtype>
      <name>$input</name>
      <description></description>
      <ext_db_rls></ext_db_rls>
      <source_id>$input</source_id>
      <subtype></subtype>
      <uri></uri>
      <taxon></taxon>
   </protocol_app_node>);
    # tie (%inputHash,'Tie::IxHash', (
    #                                 "id" => $pan_id,
    #                                 "addition" => undef,
    #                                 "type" => {content => },
    #                                 "subtype" => {content => ''},
    #                                 "name" => {content => $input},
    #                                 "description" => {content => ''},
    #                                 "external_database_release" => {content => undef},
    #                                 "source_id" => {content => $input},
    #                                 "uri" => {content => ''},
    #                                 "taxon" => {content => ''},
    #                                )
    #     );
    print TEMP $inputNode."\n";
    # $panHash->{"protocol_app_node"} = \%inputHash;
    # push @$protocolAppNodes, $panHash;
    # $panHash = {};
    $input_pan_id = $pan_id;
    $pan_id++;
  }
  my %outputHash; 
  my $outputNode;
  $outputNode = qq(   <protocol_app_node addition="true" id="$pan_id">
      <type>$entity_type</type>
      <subtype></subtype>
      <name>$output</name>
      <description></description>
      <ext_db_rls>$external_database_release_spec</ext_db_rls>
      <source_id>$output</source_id>
      <uri></uri>
      <taxon></taxon>
      $nodeChars
   </protocol_app_node>);
  print TEMP $outputNode."\n";
  # tie (%outputHash,'Tie::IxHash', (
  #                                  "id" => $pan_id,
  #                                  "addition" => 'true',
  #                                  "type" => {content => $entity_type},
  #                                  "subtype" => {content => ''},
  #                                  "name" => {content => $output},
  #                                  "description" => {content => ''},
  #                                  "external_database_release" => {content => $external_database_release_spec},
  #                                  "source_id" => {content => $output},
  #                                  "uri" => {content => ''},
  #                                  "taxon" => {content => ''},
  #                                  "node_characteristic" => $nodeChars
  #       								  )
  #     );
  # $panHash->{"protocol_app_node"} = \%outputHash;
  # push @$protocolAppNodes, $panHash;
  # $panHash = {};
  $output_pan_id = $pan_id;
  $pan_id++;

  my %protocolAppHash; 
  tie (%protocolAppHash,'Tie::IxHash', (
                                        "addition" => 'true',
                                        "protocol" => {content => $protocol},
                                        "protocol_app_date" => {content => $protocolAppDate},
                                        "input" => {content => $input_pan_id},
                                        "output" => {content => $output_pan_id},
                                       )
      );
  $paHash->{"protocol_app"} = \%protocolAppHash;
  push @$protocolApps, $paHash;
  $paHash = {};

}

close INFILE;
$ilsh->finish();
$ivsh->finish();




print TEMP $xmlObj->XMLout($protocolApps)."</sdrf>\n";
#print TEMP $xmlObj->XMLout($protocolApps);


$dbh->disconnect();
close TEMP;

open (TEMP, "$temp") || die "Can't open $outFile for reading\n";

open (OUTFILE, ">$outFile") || die "Can't open $outFile for reading\n";
print OUTFILE '<?xml version="1.0" encoding="UTF-8"?>'."\n<mage-tab>\n";
while (<TEMP>) {
  print OUTFILE '  '.$_ unless $_=~/^<anon>\n/ || $_=~/^<\/anon>\n/;
}
print OUTFILE "</mage-tab>";

print STDERR "Skipped these IDs";

my @uniqSkippedInputs = uniq(@$SkippedInputs);

print STDERR Dumper (\@uniqSkippedInputs);
exit;


sub parseHeader {

  my ($header,$offical_header_hash) = @_;
  my @Header = split ("\t" , $header);
  my $columnCount = scalar(@Header);
  my $colMap = {};
  my $chars = [];
  my $paramValues = [];
  for (my $i = 0; $i < $columnCount; $i++) {
    $colMap->{"Input"} = $i if ($Header[$i] =~ /Input/i);
    $colMap->{"Output"} = $i if $Header[$i] =~ /Output/i;
    $colMap->{"Date"} = $i if $Header[$i] =~ /\[DATE\]/i;
    if ($Header[$i] =~ /Characteristics\s*\[\w+\]/i) {
      my $bareChar = $Header[$i];
      $bareChar =~ s/.*\[//i;
      $bareChar =~ s/\]//i;
      $bareChar = lc($bareChar);
      my $display_term = $bareChar;
      if ($official_header_hash) {
        while (my ($official,$pattern) = each %$offical_header_hash) {
          if ($display_term =~ /$pattern/) {
            $display_term =~ s/$pattern/$official/ ;
          }
        }
      }
      my $charHash = {characteristic=>$bareChar,
                                     column=>$i,
                                     official_characteristic=>$display_term};
      push @$chars,$charHash;
    }
    elsif ($Header[$i] =~ /Parameter\s*Value\s*\[\w+\]/i) {
      my $bareChar = $Header[$i];
      $bareChar =~ s/.*\[//i;
      $bareChar =~ s/\].*//i;
      my $charHash =  {characteristic=>$bareChar,
                                     column=>$i,
                                     display=>$bareChar};
      push @$paramValues,$charHash;
      
    }

  }
  $colMap->{"characteristics"} = $chars;
  $colMap->{"paramValues"} = $paramValues;
  $colMap->{"Input"} = undef unless  (defined $colMap->{"Input"});

  return $colMap;
}

sub swapMappedValues {
  my ($char, $value, $mapHash) = @_;
 
  if (defined ($mapHash->{$char})) {
    if (defined ($mapHash->{$char}->{$value})) { 
      $value = $mapHash->{$char}->{$value};
    }
    else {
      print STDERR "Warning, mapping not defined for $char : $value \n";
    }
  }
  return $value;
}

sub parseCharacteristics {

  my ($characteristics,$ext_db_rls_id,$external_database_release_spec,$values,$mapHash,$official_header_hash,$dbh) = @_;

  my $nodeChars = "Empty";
  my $sql = "select value from (
               select name as value 
                 from SRES.ONTOLOGYTERM ot
                where ot.external_database_release_id = $ext_db_rls_id
                  and lower(name) = ?
                  )";
  my $sh = $dbh->prepare($sql);

  foreach my $characteristicsHash (@$characteristics) {
    my $characteristic = $characteristicsHash->{official_characteristic};
    my $column = $characteristicsHash->{column};
    unless (defined $characteristic && $characteristic=~/\w/) {
        next;
    }    my $value = $values->[$column];
    unless ( (defined $value) && ($value =~/\w/)) {
      next;
    }
    my $lower_value = lc($value); 
    my $lower_characteristic = lc($characteristic);

    $lower_value =swapMappedValues($lower_characteristic,$lower_value,$mapHash);

    $lower_value =~ s/\'/\'\'/g;
    $lower_characteristic =~ s/\'/\'\'/g;

    $sh->execute($lower_value);
    my $db_value = undef;
    $db_value = $sh->fetchrow_array;

    my $db_ot = undef;
    my $db_category = 'Characteristic';

    $lower_characteristic =~ s/\'/\'\'/g;

    if (defined $db_value) {
      $db_ot = $db_value;
      $db_value = undef;

      $sh->execute($lower_characteristic);

      $db_category = $sh->fetchrow_array;
    }
    else {
      $sh->execute($lower_characteristic);
   #   print STDERR Dumper ($sh) if ($column=~/22/);
      $db_ot = $sh->fetchrow_array;

      print STDERR "\n ontology term $characteristic does not match anything in the database for the external database $external_database_release_spec\n" unless (defined $db_ot);
     next unless (defined $db_ot);

      $db_value = $lower_value;
    }

#    unless (defined $db_ot) {
#       exit;
#    }
    if (defined ($db_value)) { 
      $db_value =~ s/&/&amp;/g;
      $db_value =~ s/</&lt;/g;
      $db_value =~ s/>/&gt;/g;
      $db_value =~ s/'/&apos;/g;
      $db_value =~ s/"/&quot;/g;
    }

    if ($nodeChars =~/Empty/) {
      $nodeChars = qq(<node_characteristic addition="true">
        <external_database_release>$external_database_release_spec</external_database_release>
        <ontology_term category="$db_category">$db_ot</ontology_term>
        <value>$db_value</value>
      </node_characteristic>)
    } else {
      $nodeChars = $nodeChars.qq(<node_characteristic addition="true">
        <external_database_release>$external_database_release_spec</external_database_release>
        <ontology_term category="$db_category">$db_ot</ontology_term>
        <value>$db_value</value>
      </node_characteristic>);
    }
  }
  
return ($nodeChars);
}
