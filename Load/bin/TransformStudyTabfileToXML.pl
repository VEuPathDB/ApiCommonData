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

use Date::Parse;

my ($inFile, $configFile, $outFile, $help, );
my $type_ext_db_rls_spec = 'PRISM Data Dictionary|Apr_2014';

&GetOptions('help|h' => \$help,
            'configFile=s' => \$configFile,
           );

#&usage() if($help);
#&usage("Input dir containing csv files is required") unless(-e $inDir);
#&usage("Output file name is required") unless($outFile);

die "config file is required " unless $configFile;
my $isHeader = 1;
my $headerSize = 0;
my @Header;
my $ontologyHash = {};

my $xmlObj = XML::Simple->new(KeepRoot =>1, ForceArray=>1);

my $ColumnMap;
my $pan_id = 1;
my $validHeader = 2;

my $mapHash = {};

my ($studyName,$db_id,$protocol,$entity_type,$parent_entity_type,$header_regexp,$input_lookup,$external_database_release_spec);
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
  elsif ($line =~ /^entity_type/) {
    $entity_type = $line;
    $entity_type =~ s/^\w*://;
  }
  elsif ($line =~ /^external_database_release_spec/) {
    $external_database_release_spec = $line;
    $external_database_release_spec =~ s/external_database_release_spec://;
  }
  elsif ($line =~ /parent_entity_type/) {
    $parent_entity_type = $line;
    $parent_entity_type =~ s/^\w*://;
  }
  elsif ($line =~ /type_external_database_release_spec/) {
    $type_ext_db_rls_spec = $line;
    $type_ext_db_rls_spec =~ s/type_external_database_release_spec://;
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

 @tokens = split(/\|/,$type_ext_db_rls_spec);
my $type_ext_db_name = $tokens[0];
my $type_ext_db_version = $tokens[1];
my $lower_type_ext_db_name = lc($type_ext_db_name);
my $type_ext_db_sql = "select ex.external_database_release_id
                    from sres.externaldatabaserelease ex, sres.externaldatabase e
                   where e.external_database_id = ex.external_database_id
                     and ex.version = '$type_ext_db_version'
                     and lower(e.name) = '$lower_type_ext_db_name'";


my $gusConfigFile = $ENV{GUS_HOME} . "/config/gus.config";
  
my @properties = ();
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);
  
my $u = $gusconfig->{props}->{databaseLogin};
my $pw = $gusconfig->{props}->{databasePassword};
my $dsn = $gusconfig->{props}->{dbiDsn};
my $dbh = DBI->connect($dsn, $u, $pw) or die DBI::errstr;

my $sh = $dbh->prepare($ext_db_sql);
$sh->execute();

my $ext_db_rls_id = $sh->fetchrow_array();

$sh->finish();

$sh = $dbh->prepare($type_ext_db_sql);
$sh->execute();

my $type_ext_db_rls_id = $sh->fetchrow_array();

$sh->finish();

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
  my $nodeChars = parseCharacteristics($chars,$ext_db_rls_id,$external_database_release_spec,$values,$mapHash,$ontologyHash,$dbh);
  my $panHash = {};
  my $paHash = {};
  my $input;
  $input = $values->[$inputCol] if (defined $ColumnMap->{"Input"});
  my $input_source_id;
  my $output  = $values->[$outputCol];
  my $protocolAppDate = $values->[$dateCol];
  my $input_pan_id =undef;
  my $output_pan_id =undef;
  my %inputHash; 
  my $inputNode;
  if (defined $input){  
    $inputNode = qq(
   <protocol_app_node addition="" id="$pan_id">
      <type>$parent_entity_type</type>
      <subtype></subtype>
      <name>$input</name>
      <description></description>
      <ext_db_rls>$type_ext_db_rls_id</ext_db_rls>
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




print TEMP $xmlObj->XMLout($protocolApps)."</sdrf>\n";
#print TEMP $xmlObj->XMLout($protocolApps);


$dbh->disconnect();
close TEMP;

open (TEMP, "$temp") || die "Can't open $outFile for reading\n";

open (OUTFILE, ">$outFile") || die "Can't open $outFile for reading\n";
print OUTFILE '<?xml version="1.0" encoding="iso-8859-1"?>'."\n<mage-tab>\n";
while (<TEMP>) {
  print OUTFILE '  '.$_ unless $_=~/^<anon>\n/ || $_=~/^<\/anon>\n/;
}
print OUTFILE "</mage-tab>";

print STDERR "Skipped these IDs";

my @uniqSkippedInputs = uniq(@$SkippedInputs);

print STDERR Dumper (\@uniqSkippedInputs);


sub lookupType {
  
  
}

sub parseHeader {

  my ($header) = @_;
  my @Header = split ("\t" , $header);
  my $columnCount = scalar(@Header);
  my $colMap = {};
  my $chars = [];
  my $paramValues = [];
  for (my $i = 0; $i < $columnCount; $i++) { 
    $colMap->{"Input"} = $i if ($Header[$i] =~ /Input/i);
    $colMap->{"Output"} = $i if $Header[$i] =~ /Output/i;
    $colMap->{"Date"} = $i if $Header[$i] =~ /\[DATE\]/i;
    my $field  = $Header[$i];
    if ($Header[$i] =~ /Characteristics\s*\[\w*.*\w*\]/i) {
      my $bareChar = $Header[$i];
      $bareChar =~ s/.*\[//i;
      $bareChar =~ s/\]//i;
      $bareChar = lc($bareChar);
      my $display_term = $bareChar;
      my $charHash = {characteristic=>$bareChar,
                                    column=>$i,
                                   };
      push @$chars,$charHash;
    }
    elsif ($Header[$i] =~ /Parameter\s*Value\s*\[\w+\]/i) {
      my $bareChar = $Header[$i];
      $bareChar =~ s/.*\[//i;
      $bareChar =~ s/\].*//i;
      my $charHash =  {characteristic=>$bareChar,
                                      column=>$i,
                                    };
      push @$paramValues,$charHash;
    }
  }
  $colMap->{"characteristics"} = $chars;
  $colMap->{"paramValues"} = $paramValues;
  $colMap->{"Input"} = undef unless  (defined $colMap->{"Input"});
  return $colMap;
}

sub parseCharacteristics {

  my ($characteristics,$ext_db_rls_id,$external_database_release_spec,$values,$mapHash,$ontologyHash,$dbh) = @_;
  
  my $nodeChars = "Empty";
  my $controlledVocab = "select category, value from (
               select pt.name as category, ot.name as value
                 from SRES.ONTOLOGYTERM ot, SRES.ONTOLOGYTERM pt
                where ot.external_database_release_id = $ext_db_rls_id
                  and ot.ancestor_term_id = pt.ontology_term_id
                  and lower(pt.name) = ?
                  and lower(ot.name) = ?
                  )";
  my $cvsh = $dbh->prepare($controlledVocab);

  my  $freeText = "select category, value from (
               select pt.name as category, ot.name as value
                 from SRES.ONTOLOGYTERM ot, SRES.ONTOLOGYTERM pt
                where ot.external_database_release_id = $ext_db_rls_id
                  and ot.ancestor_term_id = pt.ontology_term_id
                  and lower(ot.name) = ?
                  )";
  my $ftsh = $dbh->prepare($freeText);

  my $count =0;
  foreach my $characteristicsHash (@$characteristics) {

    my $characteristic = $characteristicsHash->{characteristic};
    next if (exists $ontologyHash->{bad_characteristics}->{$characteristic});
    my $column = $characteristicsHash->{column};
    unless (defined $characteristic && $characteristic=~/\w/) {
      print STDERR " $characteristic is null";
      next;
    }
    my $valueSet = $values->[$column];
    unless ( (defined $valueSet) && ($valueSet =~/\w/)) {
      next;
    }
    my @values = split (/\|/, $valueSet);
    foreach my $value (@values) {
      
      my $lower_value = lc($value); 
      my $lower_characteristic = lc($characteristic);
      $lower_value =~ s/\'/\'\'/g;
      $lower_characteristic =~ s/\'/\'\'/g;
      next unless (defined $lower_value && $lower_value=~/\w/);
      next if $lower_value =~ /NULL/i;
      
      my $db_value = undef;
      my $db_ot = undef;
      my $db_category = undef;
      my $free_value;
      
      if (exists $ontologyHash->{"$lower_characteristic:$lower_value"}) {
        $db_category = $ontologyHash->{"$lower_characteristic:$lower_value"}->{db_category};   
        $db_ot = $ontologyHash->{"$lower_characteristic:$lower_value"}->{db_ot}; 
        $free_value = undef;
      }
      elsif (exists $ontologyHash->{$lower_characteristic}) {
        $db_category = $ontologyHash->{$lower_characteristic}->{db_category};   
        $db_ot = $ontologyHash->{$lower_characteristic}->{db_ot}; 
        $free_value = $lower_value
      }
      else {
        $cvsh->execute($lower_characteristic,$lower_value);
        ($db_category,$db_value) = $cvsh->fetchrow_array;
        if (defined $db_value) {
          $db_ot = $db_value;
          $free_value = undef;
          $ontologyHash->{"$db_category:$db_ot"}->{db_category} =$db_category;
          $ontologyHash->{"$db_category:$db_ot"}->{db_ot} = $db_ot;
        }
        else {
          $ftsh->execute($lower_characteristic);
          ($db_category,$db_ot) = $ftsh->fetchrow_array;
          if (defined $db_ot) {
            $free_value = $lower_value;
            $ontologyHash->{"$db_ot"}->{db_category} =$db_category;
            $ontologyHash->{"$db_ot"}->{db_ot} = $db_ot;
          }
        }
      }
      unless (defined $db_ot) {
        print STDERR "\n ontology term $characteristic does not match anything in the database for the external database $external_database_release_spec\n";
        $ontologyHash->{bad_characteristics}->{$characteristic}=1;
        next;
      }
      $db_category = '' unless defined $db_category;
    if (defined ($free_value)) { 
      $free_value =~ s/&/&amp;/g;
      $free_value =~ s/</&lt;/g;
      $free_value =~ s/>/&gt;/g;
      $free_value =~ s/'/&apos;/g;
      $free_value =~ s/"/&quot;/g;
    }
    else {
      $free_value = '';
    }
      if ($nodeChars =~/Empty/) {
        $nodeChars = qq(<node_characteristic addition="true">
        <external_database_release>$external_database_release_spec</external_database_release>
        <ontology_term category="$db_category">$db_ot</ontology_term>
        <value>$free_value</value>
      </node_characteristic>)
      } else {
        $nodeChars = $nodeChars.qq(<node_characteristic addition="true">
        <external_database_release>$external_database_release_spec</external_database_release>
        <ontology_term category="$db_category">$db_ot</ontology_term>
        <value>$free_value</value>
      </node_characteristic>);
      }
    }
  }
  return ($nodeChars);
}

