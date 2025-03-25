#!/usr/bin/perl

use strict;
use lib "$ENV{GUS_HOME}/lib/perl/";

use DBI;
use DBD::Oracle;
use Getopt::Long;

use CBIL::Util::PropertySet;
use GUS::ObjRelP::DbiDbHandle;
use GUS::Community::GeneModelLocations;

use Bio::Tools::GFF;

my ($help, $instanceName, $extDbRlsId, $outputFile, $orgAbbrev, $outputFileDir, $ifSeparateParents);
&GetOptions('help|h' => \$help,
            'instanceName=s' => \$instanceName,
            'orgAbbrev=s' => \$orgAbbrev,
            'extDbRlsId=s' => \$extDbRlsId,
            'outputFile=s' => \$outputFile,
            'ifSeparateParents=s' => \$ifSeparateParents,
            'outputFileDir=s' => \$outputFileDir
    );

&usage("Missing a required argument.") unless (defined $orgAbbrev);

my $gusConfigFile = "$ENV{GUS_HOME}/config/gus.config";

if (!$outputFile) {
  $outputFile = $orgAbbrev . ".gff3.before";
}

if ($outputFileDir) {
  $outputFile = "\./" . $outputFileDir. "\/".$outputFile;
}

if (!$ifSeparateParents) {
  $ifSeparateParents = "No";
}

my @properties;
my $gusconfig = CBIL::Util::PropertySet->new($gusConfigFile, \@properties, 1);

my $dbiDsn = $gusconfig->{props}->{dbiDsn};
my $dbiUser = $gusconfig->{props}->{databaseLogin};
my $dbiPswd = $gusconfig->{props}->{databasePassword};
$dbiDsn = "dbi:Oracle:".$instanceName if ($instanceName);

my $dbh = GUS::ObjRelP::DbiDbHandle->new($dbiDsn, $dbiUser, $dbiPswd);
$dbh->{RaiseError} = 1;
$dbh->{AutoCommit} = 0;
$dbh->{LongTruncOk} = 1;


if (!$extDbRlsId) {
  $extDbRlsId = getExtDbRlsIdFormOrgAbbrev ($orgAbbrev);
}

my $geneNames = getGeneName ($dbh, $extDbRlsId);
my $geneSynonyms = getSynonym ($dbh, $extDbRlsId, $orgAbbrev);
my $geneProducts = getGeneProductName ($dbh, $extDbRlsId);
my $transId2GeneId = getGeneIdFromTranscriptId ($dbh, $extDbRlsId);
my $transcriptComment = getTranscriptComment ($dbh, $extDbRlsId);
my $transcriptProduct = getTranscriptProductName ($dbh, $extDbRlsId);
my $goAssociation = getGoAssociations ($dbh, $extDbRlsId);
my $ecNumber = getEcNumbers ($dbh, $extDbRlsId);
my $featureAlias = getAliases ($dbh, $extDbRlsId);

open(GFF, "> $outputFile") or die "Cannot open file $outputFile For writing: $!";

my $geneAnnotations = {};
my $transcriptAnnotations = {};
my $ncbiTaxId;
my $sequenceLengths = {};
my $gene2TranscriptHash = {};

my $sql = "select gf.NAME, t.NAME, ns.SOURCE_ID as seq_source_id, ns.LENGTH, gf.SOURCE_ID as gene_source_id, 
t.SOURCE_ID as transcript_source_id, ta.NCBI_TAX_ID, t.is_pseudo, t.TRANSL_TABLE, t.ANTICODON, t.TRANSL_EXCEPT
from DOTS.EXTERNALNASEQUENCE ns, DOTS.GENEFEATURE gf, DOTS.TRANSCRIPT t, SRES.TAXON ta
where ns.NA_SEQUENCE_ID=gf.NA_SEQUENCE_ID and gf.NA_FEATURE_ID=t.PARENT_ID
and ns.TAXON_ID=ta.TAXON_ID
and gf.EXTERNAL_DATABASE_RELEASE_ID= ?
";


my $sh = $dbh->prepare($sql);
$sh->execute($extDbRlsId);

while(my ($geneSoTermName, $soTermName, $sequenceSourceId, $sequenceLength, $geneSourceId, $transcriptSourceId, $ncbi, $isPseudo, $translTable, $anticodon, $translExcept ) = $sh->fetchrow_array()) {
  $ncbiTaxId = $ncbi if($ncbi);

  $geneAnnotations->{$geneSourceId} = {
                                       ncbi_tax_id => $ncbiTaxId,
                                       so_term_name => $geneSoTermName,
#                                       eupathdb_id => $geneSourceId,
#                                       ebi_id => 'null',    # a place holder for EBI unique ID
  };

  $transcriptAnnotations->{$transcriptSourceId} = {
                                   so_term_name => $soTermName,
                                   is_pseudo => $isPseudo,
                                   transl_table => $translTable,
                                   transl_except => $translExcept,
                                   anticodon => $anticodon,
#                                   eupathdb_id => $transcriptSourceId,
#                                   ebi_id => 'null',    # a place holder for EBI unique ID
#                                   translation => $translation,
  };

  ## GUS is using lncRNA, which should be lnc_RNA in gene ontology
  $geneAnnotations->{$geneSourceId}->{so_term_name} = "lnc_RNA" if ($geneAnnotations->{$geneSourceId}->{so_term_name} eq "lncRNA");
  $transcriptAnnotations->{$transcriptSourceId}->{so_term_name} = "lnc_RNA" if ($transcriptAnnotations->{$transcriptSourceId}->{so_term_name} eq "lncRNA");

  $sequenceLengths->{$sequenceSourceId} = $sequenceLength;
  push @{$gene2TranscriptHash->{$geneSourceId}}, $transcriptAnnotations->{$transcriptSourceId};
}

my $geneModelLocations = GUS::Community::GeneModelLocations->new($dbh, $extDbRlsId, 1);


print GFF "##gff-version 3\n";
#print GFF "#!gff-spec-version 1.21\n";

foreach(sort keys %$sequenceLengths) {
  my $length = $sequenceLengths->{$_};

#  print GFF "##sequence-region $_ 1 $length\n";   ## sequence query from dots.externalNaFeature table are not top level
}

my $date = HTTP::Date::time2iso();
#print GFF "#created $date\n";


foreach my $geneSourceId (sort @{$geneModelLocations->getAllGeneIds()}) {
  my $features = $geneModelLocations->bioperlFeaturesFromGeneSourceId($geneSourceId);

  foreach my $feature (@$features) {
    $feature->source_tag("VEuPathDB");

    # remove unneeded tags
    foreach my $extraTag ("NA_FEATURE_ID"
			  , "NA_SEQUENCE_ID"
			  , "PARENT_NA_FEATURE_ID"
			  , "AA_FEATURE_ID"
			  , "AA_SEQUENCE_ID"
			  , "GENE_NA_FEATURE_ID"
			  , "EBI_BIOTYPE"
			  , "GENE_EBI_BIOTYPE"
			  , "SEQUENCE_IS_PIECE") {
      $feature->remove_tag($extraTag) if($feature->has_tag($extraTag));
    }

    # lowercase tag names and seperate Parent info
    foreach($feature->get_all_tags()) {
      if($_ eq 'ID') { }
      elsif($_ eq 'PARENT') {

        my ($parent) = $feature->remove_tag($_);

        my @parents = split(",", $parent);
        foreach(@parents) {
          $feature->add_tag_value('Parent', $_);
        }
      }
      else {
        $feature->add_tag_value(lc($_), $feature->remove_tag($_));
      }

    }

    # change protein_coding_gene, *RNA_gene to gene
    if ($feature->primary_tag eq 'protein_coding_gene'
       || $feature->primary_tag =~ /RNA_gene$/ ) {
      $feature->primary_tag('gene');
    }


    if($feature->primary_tag eq 'gene') {
      ## add locus_tag
      $feature->add_tag_value("locus_tag", $feature->get_tag_values("ID")) if ($feature->get_tag_values("ID"));
    }

    if($feature->primary_tag eq 'transcript' || $feature->primary_tag =~ /RNA$/) {


      my ($transcriptId) = $feature->get_tag_values("ID");

      my $soTermName = $transcriptAnnotations->{$transcriptId}->{so_term_name};
      my $isPseudo = $transcriptAnnotations->{$transcriptId}->{is_pseudo};
      my $translTable = $transcriptAnnotations->{$transcriptId}->{transl_table};
      my $translExcept = $transcriptAnnotations->{$transcriptId}->{transl_except};
      my $anticodon = $transcriptAnnotations->{$transcriptId}->{anticodon};
#      my $translation = $transcriptAnnotations->{$transcriptId}->{translation};

      $feature->primary_tag($soTermName);
      $feature->add_tag_value("is_pseudo", $isPseudo) if($isPseudo);
      $feature->add_tag_value("transl_table", $translTable) if($translTable);
      $feature->add_tag_value("transl_except", $translExcept) if($translExcept);
      $feature->add_tag_value("anticodon", $anticodon) if($anticodon);
#      $feature->add_tag_value("translation", $translation) if($translation);
      $feature->add_tag_value("transcript_id", $feature->get_tag_values("ID")) if ($feature->get_tag_values("ID"));
    }

    if($feature->primary_tag eq 'CDS') {
      my ($translated_id) = $feature->get_tag_values('protein_source_id') if ($feature->has_tag('protein_source_id'));
      $feature->remove_tag ('protein_source_id') if ($feature->has_tag('protein_source_id'));
      $feature->add_tag_value("protein_id", $translated_id) if($translated_id);

      ## add product
      my ($tTId) = $feature->get_tag_values("Parent");
      my $tGId = $transId2GeneId->{$tTId};

      ## TODO need to deal with product in transcript tables
      if ($geneProducts->{$tGId}) {
        $feature->add_tag_value("product", $geneProducts->{$tGId});
      }
      if ($transcriptProduct->{$tTId}) {
        $feature->add_tag_value("product", $transcriptProduct->{$tTId});
      }
      #$feature->add_tag_value("product", $prod) if ($prod);
    }

    my $bioType = getBioTypeAndUpdatePrimaryTag(\$feature, $geneSourceId);
    $feature->add_tag_value ("gene_biotype", $bioType) if ($bioType && $feature->primary_tag eq 'gene');

    if($feature->primary_tag eq 'utr3prime') {
      $feature->primary_tag('three_prime_UTR');
    }
    if($feature->primary_tag eq 'utr5prime') {
      $feature->primary_tag('five_prime_UTR');
    }


    unless($feature->primary_tag eq 'CDS') {
      $feature->frame('.');
    }

#    print STDERR "$feature->primary_tag\n" if ($feature->primary_tag ne "gene" 
#					       || $feature->primary_tag =~ /RNA$/
#					       || $feature->primary_tag ne "CDS"
#					       || $feature->primary_tag ne "pseudogene"
#					       || $feature->primary_tag ne "pseudogenic_transcript"
#					       || $feature->primary_tag ne "pseudogenic_exon"
#					       || $feature->primary_tag ne "exon");

    ## separate features if there are more than one parent
    if ($ifSeparateParents =~ /^y/i) {
      if ($feature->has_tag("Parent") && scalar ($feature->get_tag_values("Parent")) > 1 ) {

	my @parents = $feature->get_tag_values("Parent");

	my $c = 0;
	foreach my $pant (@parents) {
	  $c++;
	  $feature->remove_tag("Parent");
	  $feature->add_tag_value('Parent', $pant);
	  if ($feature->has_tag("ID")) {
	    my ($nid) = $feature->remove_tag("ID");
	    $nid =~ s/\.\d//;
	    $nid .= ".$c";
	    $feature->add_tag_value("ID", $nid);
	  }

	  $feature->gff_format(Bio::Tools::GFF->new(-gff_version => 3));
	  print GFF $feature->gff_string . "\n";
	}
      } else {
	$feature->gff_format(Bio::Tools::GFF->new(-gff_version => 3));
	print GFF $feature->gff_string . "\n";
      }
    } else {
      $feature->gff_format(Bio::Tools::GFF->new(-gff_version => 3));
      print GFF $feature->gff_string . "\n";
    }
  }
}

## get info of transposable_element
my $tes = getTransposableElement($dbh, $extDbRlsId);
foreach my $k (sort keys %{$tes}) {
  foreach my $i (0..$#{$tes->{$k}}) {
    ($i == $#{$tes->{$k}}) ? print GFF "$tes->{$k}[$i]\n" : print GFF "$tes->{$k}[$i]\t";
  }
}

$dbh->disconnect();
close GFF;

1;


## TODO
## 1. add product to CDS and mRNA
## 2. add gene name and gene synonym to gene
## 3. add EC_number to CDS?
## 4. add GO
## 5. add DbxRef

############
sub getTranscriptComment {
  my ($dbh, $extDbRlsId) = @_;
  my %t2Comment;
  my $sql = "
             select t.source_id, fc.comment_string
             from DoTS.NaFeatureComment fc, dots.transcript t, dots.genefeature gf
             where (t.na_feature_id=fc.na_feature_id OR gf.na_feature_id=fc.na_feature_id)
             and gf.na_feature_id=t.parent_id and gf.external_database_release_id=$extDbRlsId
            ";
  my $stmt = $dbh->prepare($sql);
  $stmt->execute();
  while (my ($tid, $cmmt) = $stmt->fetchrow_array()) {
    $t2Comment{$tid} = $cmmt if($tid && $cmmt);
  }
  $stmt->finish();

  return \%t2Comment;
}

sub getGeneIdFromTranscriptId {
  my ($dbh, $extDbRlsId) = @_;
  my %t2gs;
  my $sql = "
            select gf.source_id, t.source_id from dots.genefeature gf, dots.transcript t
            where gf.na_feature_id = t.parent_id and t.external_database_release_id=$extDbRlsId
           ";
  my $stmt = $dbh->prepare($sql);
  $stmt->execute();
  while (my ($gid, $tid) = $stmt->fetchrow_array()) {
    $t2gs{$tid} = $gid if($gid && $tid);
  }
  $stmt->finish();

  return \%t2gs;
}

sub getGeneName {
  my ($dbh, $extDbRlsId) = @_;
  my (%g2Names, %gNames);
  my $sql = "
             select gf.source_id, n.name from dots.genefeature gf, ApiDB.GeneFeatureName n
             where gf.na_feature_id=n.na_feature_id and n.is_preferred=1 and gf.external_database_release_id=$extDbRlsId
           ";
  my $stmt = $dbh->prepare($sql);
  $stmt->execute();
  while (my ($sourceId, $name) = $stmt->fetchrow_array()) {
    push (@{$gNames{$sourceId}}, $name);
  }
  $stmt->finish();

  foreach my $k (sort keys %gNames) {
    $g2Names{$k} = join (",", @{$gNames{$k}});
  }

  return \%g2Names;
}

sub getSynonym {
  my ($dbh, $extDbRlsId, $orgAbbrev) = @_;
  my (%g2Synonyms, %gSynonyms);

  my $synonymExtDbName = $orgAbbrev . "_dbxref_%_synonym_RSRC";
  my $sql2 = "
              select name from sres.externaldatabase where name like '$synonymExtDbName'
             ";
  my $stmt2 = $dbh->prepare($sql2);
  $stmt2->execute();
  my $synonymExtDbRlsId;
  while (my ($extDbName) = $stmt2->fetchrow_array()) {
    print STDERR "\$extDbName = extDbName\n";
    $synonymExtDbRlsId = getExtDbRlsIdFromExtDbName ($extDbName);
  }
  $stmt2->finish();

  return \%gSynonyms if (!$synonymExtDbRlsId);

  my $sql = "
            select gf.source_id, d.primary_identifier from dots.genefeature gf, sres.dbref d, dots.dbrefnafeature dnf
where gf.na_feature_id = dnf.na_feature_id and dnf.db_ref_id = d.db_ref_id and d.external_database_release_id=$synonymExtDbRlsId
           ";
  my $stmt = $dbh->prepare($sql);
  $stmt->execute();
  while (my ($sourceId, $synonym) = $stmt->fetchrow_array()) {
    push (@{$gSynonyms{$sourceId}}, $synonym) if ($sourceId && $synonym);
  }
  $stmt->finish();

  foreach my $k (sort keys %gSynonyms) {
    $g2Synonyms{$k} = join (",", @{$gSynonyms{$k}});
  }

  return \%g2Synonyms;
}

sub getGeneProductName {
  my ($dbh, $extDbRlsId) = @_;
  my (%g2Product, %products);
  my $sql = "
             select gf.source_id, gp.product from dots.genefeature gf, apidb.genefeatureproduct gp
             where gf.na_feature_id=gp.na_feature_id and gf.external_database_release_id=$extDbRlsId
           ";
  my $stmt = $dbh->prepare($sql);
  $stmt->execute();
  while (my ($sourceId, $pd) = $stmt->fetchrow_array()) {
    push (@{$products{$sourceId}}, $pd) if ($sourceId && $pd);
  }
  $stmt->finish();

  foreach my $k (sort keys %products) {
    $g2Product{$k} = join(';', @{$products{$k}});
  }
  return \%g2Product;
}

sub getTranscriptProductName {
  my ($dbh, $extDbRlsId) = @_;
  my (%t2Product, %products);
  my $sql = "
             select t.source_id, tp.product from dots.transcript t, apidb.transcriptproduct tp
             where t.na_feature_id=tp.na_feature_id and t.external_database_release_id=$extDbRlsId
            ";
  my $stmt = $dbh->prepare($sql);
  $stmt->execute();
  while (my ($sourceId, $pd) = $stmt->fetchrow_array()) {
    push (@{$products{$sourceId}}, $pd) if($sourceId && $pd);
  }
  $stmt->finish();

  foreach my $k (sort keys %products) {
    $t2Product{$k} = join(';', @{$products{$k}});
  }

  return \%t2Product;
}

sub getEcNumbers {
  my ($dbh, $extDbRlsId) = @_;
  my (%t2ECs, %ecs);
  my $sql = "
select t.source_id, ec.ec_number, taf.source_id
from DoTS.AASequenceEnzymeClass asec, sres.EnzymeClass ec, dots.transcript t, dots.translatedaafeature taf, dots.translatedaasequence tas
where asec.enzyme_class_id=ec.enzyme_class_id and asec.aa_sequence_id = tas.aa_sequence_id and t.na_feature_id=taf.na_feature_id and taf.aa_sequence_id = tas.aa_sequence_id and t.external_database_release_id=$extDbRlsId
           ";
  my $stmt = $dbh->prepare($sql);
  $stmt->execute();
  while (my ($sourceId, $ec) = $stmt->fetchrow_array()) {
    push (@{$ecs{$sourceId}}, $ec) if($sourceId && $ec);
  }
  $stmt->finish();

  foreach my $k (sort keys %ecs) {
    $t2ECs{$k} = join(',', @{$ecs{$k}});
  }

  return \%t2ECs;
}

sub getGoAssociations {
  my ($dbh, $extDbRlsId) = @_;
  my (%t2GOs, %gos);

  my $eC2Name = getEvidenceCode ($dbh);

  my $sql = "
select t.source_id as t_source_id, ot.source_id as go_source_id, gaie.go_evidence_code_id, gaie.reference, gaie.evidence_code_parameter
from DoTS.GOAssociation ga, DoTS.GOAssociationInstance gai, DoTS.GOAssocInstEvidCode gaie, dots.translatedaafeature taf, dots.transcript t, sres.ontologyterm ot
where ga.go_association_id = gai.go_association_id and gai.go_association_instance_id = gaie.go_association_instance_id
and taf.aa_sequence_id = ga.row_id and taf.na_feature_id=t.na_feature_id and ga.go_term_id=ot.ontology_term_id and t.external_database_release_id=$extDbRlsId
            ";
  my $stmt = $dbh->prepare($sql);
  $stmt->execute();
  while (my ($sourceId, $go, $eviCode, $reference, $parameter) = $stmt->fetchrow_array()) {
    $go =~ s/GO_/GO:/;
	my $goList = $go . "|" . $eC2Name->{$eviCode} . "|" . $reference . "|" . $parameter;
    push (@{$gos{$sourceId}}, $goList) if($sourceId && $goList);
  }
  $stmt->finish();

  foreach my $k (sort keys %gos) {
    $t2GOs{$k} = join(',', @{$gos{$k}});
  }

  return \%t2GOs;
}

sub getAliases {
  my ($dbh, $extDbRlsId) = @_;
  my (%g2Aliases, %aliases);
  my $sql = "
select nf.source_id, df.primary_identifier
from dots.nafeature nf, DoTS.DbRefNAFeature dnf, sres.dbref df, sres.externalDatabaseRelease edr
where df.external_database_release_id = edr.external_database_release_id and edr.id_is_alias = 1
and nf.na_feature_id = dnf.na_feature_id and dnf.db_ref_id = df.db_ref_id and nf.external_database_release_id=$extDbRlsId
           ";
  my $stmt = $dbh->prepare($sql);
  $stmt->execute();
  while (my ($sourceId, $alias) = $stmt->fetchrow_array()) {
    push (@{$aliases{$sourceId}}, $alias) if ($sourceId && $alias);
  }
  $stmt->finish();

  foreach my $k (sort keys %aliases) {
    $g2Aliases{$k} = join (",", @{$aliases{$k}});
  }

  return \%g2Aliases;
}

sub getDbxref {
}

sub getEvidenceCode {
  my ($dbh) = @_;
  my (%id2Name);
  my $sql = "
select ontology_term_id, name from sres.ontologyterm
           ";
  my $stmt = $dbh->prepare($sql);
  $stmt->execute();
  while (my ($id, $name) = $stmt->fetchrow_array()) {
    $id2Name{$id}  = $name if ($id && $name);
  }
  $stmt->finish();

  return \%id2Name;
}

sub getTransposableElement {
  my ($dbh, $extDbRlsId) = @_;
  my %elements;

  my $sql = "
            select te.SOURCE_ID, ot.name, ns.SOURCE_ID, nl.START_MIN, nl.END_MAX, nl.IS_REVERSED
            from DOTS.TRANSPOSABLEELEMENT te, DOTS.EXTERNALNASEQUENCE ns, dots.nalocation nl, SRES.ONTOLOGYTERM ot
            where te.NA_FEATURE_ID=nl.NA_FEATURE_ID and te.NA_SEQUENCE_ID=ns.NA_SEQUENCE_ID and te.SEQUENCE_ONTOLOGY_ID=ot.ONTOLOGY_TERM_ID
            and ot.name like 'transposable_element' and te.EXTERNAL_DATABASE_RELEASE_ID=$extDbRlsId
           ";

  my $stmt = $dbh->prepare($sql);
  $stmt->execute();
  while (my ($eSourceId, $eProduct, $sSourceId, $start, $end, $std) = $stmt->fetchrow_array()) {
    if ($eSourceId) {

      my $strand = ($std == 0) ? "+" : "-";

      $eSourceId .= ".2" if ($elements{$eSourceId}); ## temp fix for id
      $eSourceId =~ s/TEG/TE/ if ($eSourceId eq "TVAG_TEG_DS113326_1");
      next if ($eSourceId eq "TVAG_TE_DS113443_3"); ## skip TVAG_TE_DS113443_3 because it has been annotated at a wrong sequence

      my $idColumn = "ID=$eSourceId";
      $idColumn .= ";biotype=transposable_element";

      push (@{$elements{$eSourceId}}, $sSourceId, 'EuPathDB', 'transposable_element', $start, $end, '.', $strand, '.', $idColumn);
    }
  }
  $stmt->finish();

  foreach my $k (sort keys %elements) {
    foreach my $i (0..$#{$elements{$k}}) {
#      ($i == $#{$elements{$k}}) ? print STDERR "$elements{$k}[$i]\n" : print STDERR "$elements{$k}[$i]\t";
    }
  }

  return \%elements;
}

sub getBioTypeAndUpdatePrimaryTag {
  my ($feat, $geneSourceId) = @_;
  my $bioType;

  my ($id) = $$feat->get_tag_values("ID");
  my $type = $$feat->primary_tag;
#  print STDERR "processing $type, '$id'......\n";

  ## for those primary_tag = transcript, assign with gene soTerm
  if ($$feat->primary_tag eq "transcript") {
    my ($parentID) = $$feat->get_tag_values('Parent');
    my $transcriptType = $geneAnnotations->{$parentID}->{so_term_name};
    if ($transcriptType eq "coding_gene" || $transcriptType eq "protein_coding" 
                  || $transcriptType eq "pseudogene" || $transcriptType eq "pseudogene_with_CDS") {
      $transcriptType = "mRNA";
    } elsif ($transcriptType eq "tRNA_pseudogene") {
      $transcriptType = "tRNA";
    } else {
      $transcriptType =~ s/\_gene$//;
      $transcriptType =~ s/\_encoding$//;
    }
    $$feat->primary_tag($transcriptType);
  }

  if ($$feat->primary_tag eq "gene") {
    $bioType = $geneAnnotations->{$id}->{so_term_name};
    my $isPseudoString = "";
    foreach my $transcriptHash (@{$gene2TranscriptHash->{$id}}) {
      if ($transcriptHash->{so_term_name} eq "mRNA" || $transcriptHash->{so_term_name} eq "transcript") {

#	## this will assign gene as pseudogene when partial of transcripts are pseudo-, which is incorrect
#	if ($transcriptHash->{is_pseudo} == 1) {
#	  $bioType = "pseudogene";
#	  $$feat->primary_tag("pseudogene");
#	}
	my $isP = ($transcriptHash->{is_pseudo} == 1) ? 1 : 0;
	$isPseudoString .= $isP;
      }
    }
    if ($isPseudoString =~ /^1+$/) {
      $$feat->remove_tag("is_pseudo") if ($$feat->has_tag("is_pseudo"));
      $$feat->add_tag_value("pseudo", "true");
      $bioType = "pseudogene";
#      $$feat->primary_tag("gene");
    }

    $bioType = "protein_coding" if ($bioType eq "coding_gene");
    $bioType =~ s/\_gene$/\_encoding/i;

    ## add extra qualifiers
    my ($gid) = $$feat->get_tag_values("ID");
    if ($geneNames->{$gid}) {
      $$feat->add_tag_value("gene", $geneNames->{$gid});
    }
    if ($geneSynonyms->{$gid}) {
      $$feat->add_tag_value("synonym", $geneSynonyms->{$gid});
    }
    if ($featureAlias->{$gid}) {
      $$feat->add_tag_value("Aliases", $featureAlias->{$gid});
    }
    if ($geneProducts->{$gid}) {
      $$feat->add_tag_value("product", $geneProducts->{$gid});
    }

  } elsif ($$feat->primary_tag =~ /RNA$/ || $$feat->primary_tag =~ /transcript$/i) {
    $bioType = $transcriptAnnotations->{$id}->{so_term_name};
    if ($$feat->has_tag("is_pseudo") && ($$feat->get_tag_values("is_pseudo")) == 1) {
      $$feat->remove_tag("is_pseudo");
      $$feat->add_tag_value("pseudo", "true");
      if ($$feat->primary_tag =~ /tRNA/) {
	$bioType = "pseudogenic_tRNA";
	$$feat->primary_tag("tRNA");
      } elsif ($$feat->primary_tag =~ /rRNA/) {
	$bioType = "pseudogenic_rRNA";
	$$feat->primary_tag("rRNA");
      } else {
	$bioType = "pseudogenic_transcript";
	$$feat->primary_tag("mRNA");
      }
    }
    my ($tid) = $$feat->get_tag_values("ID");
    print STDERR "\$tid = $tid\n";

    if ($featureAlias->{$tid}) {
      $$feat->add_tag_value("Aliases", $featureAlias->{$tid});
    }
    if ($transcriptProduct->{$tid}) {
      $$feat->add_tag_value("product", $transcriptProduct->{$tid});
    }
    if ($ecNumber->{$tid}) {
      $$feat->add_tag_value("ec_number", $ecNumber->{$tid});
    }
    if ($goAssociation->{$tid}) {
      $$feat->add_tag_value("Ontology_term", $goAssociation->{$tid});
    }
    if ($transcriptComment->{$tid}) {
      my $tc = $transcriptComment->{$tid};
      $$feat->add_tag_value("comment", $tc) if ($tc);
    }

  } elsif ($$feat->primary_tag eq "exon" ) {
    my @parentIDs = $$feat->get_tag_values('Parent');
    foreach my $parentID (@parentIDs) {
      if ($transcriptAnnotations->{$parentID}->{is_pseudo} == 1) {
	$bioType = "pseudogenic_exon";
      } else {
	$bioType = $$feat->primary_tag;
      }
    }
  } else {
    ## do not need it for CDS and others
  }
  return $bioType;
}

sub getExtDbRlsIdFormOrgAbbrev {
  my ($abbrev) = @_;

  my $extDb = $abbrev. "_primary_genome_RSRC";

  my $extDbRls = getExtDbRlsIdFromExtDbName ($extDb);

  return $extDbRls;
}

sub getExtDbRlsIdFromExtDbName {
  my ($extDbRlsName) = @_;

#  my $dbh = $self->getQueryHandle();

  my $sql = "select edr.external_database_release_id from sres.externaldatabaserelease edr, sres.externaldatabase ed
             where ed.name = '$extDbRlsName'
             and edr.external_database_id = ed.external_database_id";
  my $stmt = $dbh->prepareAndExecute($sql);
  my @rlsIdArray;

  while ( my($extDbRlsId) = $stmt->fetchrow_array()) {
      push @rlsIdArray, $extDbRlsId;
    }

  die "No extDbRlsId found for '$extDbRlsName'" unless(scalar(@rlsIdArray) > 0);

  die "trying to find unique extDbRlsId for '$extDbRlsName', but more than one found" if(scalar(@rlsIdArray) > 1);

  return @rlsIdArray[0];

}


sub usage {
  die
"
Usage: makeGff4GenbankSubmission.pl --orgAbbrev ctyzUGA55 --outputFile ctyzUGA55.gff3.before --gusConfigFile \$GUS_HOME/config/gus.config --ifSeparateParents y
       -- this script is same as makeGff4BRC4.pl except the output gff3 is different, a)pseudogene, b)dbxref, c)biotype

where
  --orgAbbrev:  required, organims abbreviation
  --extDbRlsId: optional, the externalDatabaseRleaseId that have database name like '*_primary_genome_RSRC'
  --outputFile: optional, the ouput file and/or dir
  --outputFileDir: optional, the ouput file dir that holds all output file
  --instanceName: optional, use the instance in \$GUS_HOME gus.config if not specify
  --ifSeparateParents: optional, Yes|No, default is No
";
}
