#!/usr/bin/perl

use strict;

use lib "$ENV{GUS_HOME}/lib/perl";

use XML::Simple;

use File::Basename;

use DBI;
use DBD::Oracle;

use Getopt::Long qw(GetOptions);

use Data::Dumper;

use ApiCommonShared::Model::tmUtils;

use ApiCommonData::Load::RetrieveAppNodeCharacteristics;

my ($help, $appNodeTypes, $propfile, $instance, $schema, $debug);

GetOptions("propfile=s" => \$propfile,
           "instance=s" => \$instance,
           "schema=s" => \$schema,
           "debug!" => \$debug,
           "help|h" => \$help,
          );

die "required parameter missing" unless ($propfile && $instance && $schema);

my $dbh = ApiCommonShared::Model::tmUtils::getDbHandle($instance, $schema, $propfile);

my $source_table = "ApidbTuning.AppNodeCharacteristics";

my $typeStatement = "select spec_value
                               from apidbtuning.METADATASPEC
                              where spec_property = 'type'
                                and property = ?";
my $typeRow = $dbh->prepare($typeStatement);

my $descStatement = "select spec_value
                               from apidbtuning.METADATASPEC
                              where spec_property = 'description'
                                and property = ?";
my $descRow = $dbh->prepare($descStatement);

my $displayStatement = "select spec_value
                               from apidbtuning.METADATASPEC
                              where spec_property = 'display'
                                and property = ?";
my $displayRow = $dbh->prepare($displayStatement);


my ($appNodeCategories,$allValuesHash) =  &ApiCommonData::Load::RetrieveAppNodeCharacteristics::getCategoriesAndValues($source_table,$dbh); 
# my $appNodeCategories;
# while(my ($type, $category) = $selectRow->fetchrow_array()) {
  
#   if (exists ($appNodeCategories->{$type})) {
#     my $categories = $appNodeCategories->{$type};
#     push (@$categories,$category);
#   }
#   else {
#     $appNodeCategories->{$type} = [ $category ];
#   }

# }
# $selectRow->finish();

my $wordCloudString = qq(              <plugin name="wordCloud" display="Word Cloud"
                      description="Display the terms in the attribute as word clouds"
                      implementation="org.gusdb.wdk.model.record.attribute.plugin.WordCloudAttributePlugin"
                      view="/wdk/jsp/results/wordCloud.jsp">
                      <property name="min-word-length">1</property>
                      <property name="common-words"></property>
                      <property name="exclude-numbers">false</property>
              </plugin>);

my $histogramString = qq(                            <plugin name="histogram" display="Histogram"
                      description="Display a histogram of the values"
                      implementation="org.gusdb.wdk.model.record.attribute.plugin.HistogramAttributePlugin"
                      view="/wdk/jsp/results/histogram.jsp" />);

my $attributeColumnSql = '';
my $sql ='';
my $tableName;

foreach my $key ( keys(%$appNodeCategories) ) {
  my $categories = $appNodeCategories->{$key}->{'clean'};
  my $rawCategories = $appNodeCategories->{$key}->{'raw'};
  my $ot_source_ids = $appNodeCategories->{$key}->{'ot_source_id'};
  my $categoryCount = scalar @$categories;
    $attributeColumnSql = undef;
    my $currentAttribute = $key;
    $currentAttribute =~ s/_/ /g;
    $currentAttribute =~ s/data//ig;
    $currentAttribute =~ s/(\w+)/\u\L$1/g;
    #  $currentAttribute = ucfirst($currentAttribute);
    $currentAttribute =~ s/ //g;
    $tableName= ($currentAttribute . "Attributes");
    my $textAttr=qq(
      <!-- =================================================================== -->
      <!--  Text Attributes  ++++++++-->
      <!-- =================================================================== -->
	  <attributeQueryRef ref=").$tableName.'.All"'.">\n";
  my $columnAttrs=qq(         <columnAttribute name="source_id" inReportMaker="false"/>
         <columnAttribute name="name" inReportMaker="false"/>)."\n";
  my $columns=qq(       <sqlQuery name="All" isCacheable="false">
         <column name="source_id"/>
         <column name="name"/>)."\n";

  for (my $i=0; $i<$categoryCount; $i++) {
    my $columnName = $categories->[$i];
    my $attribute = $ot_source_ids->[$i];
    $descRow->execute($attribute);
    my $desc = $descRow->fetchrow_array();
    $typeRow->execute($attribute);
    my $type = $typeRow->fetchrow_array();
    $displayRow->execute($attribute);
    my $displayName = $displayRow->fetchrow_array();
    $displayName=~ s/_+/ /;
    $displayName =  join '', map { ucfirst lc } split /(\s+)/, $displayName;
    if (defined $desc) {
      $columnAttrs = $columnAttrs.'<columnAttribute name="'.$columnName.'" displayName="'.$displayName.qq("  help=").$desc.qw(">)."\n";
    }
    else {
      $columnAttrs = $columnAttrs.'<columnAttribute name="'.$columnName.'" displayName="'.$displayName.qw(">)."\n";
    }
    $typeRow->execute($attribute);
    if ($type =~/number/) {
      $columnAttrs = $columnAttrs.$histogramString."\n";
    }
    else {
      $columnAttrs = $columnAttrs.$wordCloudString."\n";
    }
    $columnAttrs = $columnAttrs.'</columnAttribute>'."\n";
    
    $columns = $columns.qq(<column name=").$columnName.qw("/>)."\n";
  }
  $textAttr = $textAttr.$columnAttrs."</attributeQueryRef>";
  
  $sql = "select distinct * 
	          from $schema.$tableName"."\n";
  
  $columns = $columns."         <sql>
            <![CDATA[\n".$sql."            ]]>
         </sql>

         </sqlQuery>
      </querySet>";
	  
	  print STDERR $textAttr."\n";
	  print STDERR $columns."\n";

}
$typeRow->finish();
$descRow->finish();
$displayRow->finish();
$dbh->commit;
$dbh->disconnect();
