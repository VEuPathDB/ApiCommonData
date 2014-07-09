package ApiCommonData::Load::Plugin::InsertOldAnnotation;
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

@ISA = qw(GUS::PluginMgr::Plugin);

# -------------------------------------------------------------------------------------------
# Plugin to load gene data from old (previous release), i.e. coding sequences and annotation
# -------------------------------------------------------------------------------------------


use strict;
use warnings;

use GUS::PluginMgr::Plugin;
use GUS::Model::ApiDB::OldAnnotation;
use GUS::Model::ApiDB::OldCodingSequence;


my %subst;
my $subst_id;

# ----------------------------------------------------------
# Load Arguments
# ----------------------------------------------------------

sub getArgsDeclaration {
  my $argsDeclaration  =
    [
     stringArg({ name => 'gffFile',
		 descr => 'gff data file',
		 constraintFunc=> undef,
		 reqd  => 1,
		 isList => 0,
		 mustExist => 1,
	       }),

     stringArg({name => 'extDbName',
		descr => 'External database from whence this data came',
		constraintFunc=> undef,
		reqd  => 1,
		isList => 0
	       }),

     stringArg({name => 'extDbRlsVer',
		descr => 'Version of external database from whence this data came',
		constraintFunc=> undef,
		reqd  => 1,
		isList => 0
	       })
    ];

  return $argsDeclaration;
}

# ----------------------------------------------------------
# Documentation
# ----------------------------------------------------------

sub getDocumentation {

  my $description = <<DESCR;
Plugin to load gene data from old (previous release), i.e. coding sequences and annotation (GO terms, EC numbers and product names)
DESCR

  my $purpose = <<PURPOSE;
Plugin to load some gene data of old (previous release)
PURPOSE

  my $purposeBrief = <<PURPOSEBRIEF;
Plugin to load some gene data of old (previous release)
PURPOSEBRIEF

  my $notes = <<NOTES;
NOTES

  my $tablesAffected = <<AFFECT;
ApiDB::OldAnnotation;
ApiDB::OldCodingSequence;
AFFECT

  my $tablesDependedOn = <<TABD;
TABD

  my $howToRestart = <<RESTART;
No restart provided. Must undo and reload.
RESTART

  my $failureCases = <<FAIL;
FAIL

  my $documentation = { purpose          => $purpose,
                        purposeBrief     => $purposeBrief,
                        tablesAffected   => $tablesAffected,
                        tablesDependedOn => $tablesDependedOn,
                        howToRestart     => $howToRestart,
                        failureCases     => $failureCases,
                        notes            => $notes
                      };

  return ($documentation);
}

# ----------------------------------------------------------

sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);

  my $documentation = &getDocumentation();
  my $args = &getArgsDeclaration();
  my $configuration = { requiredDbVersion => 3.6,
                        cvsRevision => '$Revision$',
                        name => ref($self),
                        argsDeclaration => $args,
                        documentation => $documentation
                      };
  $self->initialize($configuration);
  return $self;
}

# ----------------------------------------------------------

sub run {
  my $self = shift;

  my $file = $self->getArg('gffFile') or die "Couldn't open the file!\n";
  my $dbRlsId = $self->getExtDbRlsId($self->getArg('extDbName'),
				     $self->getArg('extDbRlsVer'))
      or die "Couldn't retrieve external database!\n";

  my %geneHash;
  my @columns;
  my $count = 0;
  my $seq_flag = 0; # will be turned on for CDS
  my ($sequence, $gene);

  open(FILE,"<". $file) or die "cannot open $file: $!\n";

  while (<FILE>) {

    # capture GO IDs, EC numbers and product of the gene
    if ($_ =~/\t/  && !($_ =~/^##/) ) {
      @columns = split(/\t/, $_);

      if ($columns[2] eq 'mRNA') {
	$count++;
	my @fields;

	# 8th column from gff file, which has the data
	@fields = split(/;/, $columns[8]);

	my ($temp, $gene) = split(/\=/, $fields[1]);  #Name
	$gene =~s/(\-)\d+//;

	foreach my $fld (@fields) {
	  my ($key, $value) = split(/\=/, $fld);

	  if ($key eq 'Ontology_term') {
	    my @goArr; # array for GO IDs
	    my @onterm = split(/,/, $value);

	    foreach my $x (@onterm){
	      push (@goArr, $x) if ($x =~ /GO/);
	    }
	    $geneHash{$gene}{GO} = \@goArr;

	  } elsif ($key eq 'Dbxref') {
	    my @ecArr; # array for EC numbers
	    my @dbxref = split(/,/, $value);

	    foreach my $x (@dbxref){
	      if ($x =~ /EC/) {
		$x =~s/EC\://; # strip out the 'EC:'
		push (@ecArr, $x);
	      }
	    }

	    $geneHash{$gene}{EC} = \@ecArr if ($#ecArr + 1);
	  }

	  if ($key eq 'description') {
	    my $desc = $self->fixDescript($value);
	    $geneHash{$gene}{product} = $desc;
	  }
	}

      }
    }
    # capture CDS sequence of the gene
    elsif ($_ =~/^>cds_/ ) {

    # >cds_MAL13P1.1-1 (for example)
      chomp;
      $seq_flag=1;
      $gene = $_;
      $gene =~s/^\>cds_(.*)\-\d$/$1/;

    } elsif ($_ =~/^>/ && !($_ =~/^>cds_/ ) ) {
      # sequence but not CDS
      $geneHash{$gene}{sequence} = $sequence if ($sequence);
      $seq_flag=0;
      $sequence='';

    } elsif ($seq_flag) {
      chomp;
      $sequence = $sequence . $_;
      $geneHash{$gene}{sequence} = $sequence;
    }

  }
  # needed for the last CDS
  $geneHash{$gene}{sequence} = $sequence if ($sequence);

  close(FILE);

  print "PARSED Total Genes = $count\n";
  $self->collectData($dbRlsId,\%geneHash);

}

sub fixDescript {
  my ($self, $desc) = @_;

  $desc =~ s/\+/ /g;
  $desc =~ s/\%2F/\//g;
  $desc =~ s/\%2C/,/g;

  $desc =~ s/\%3A/:/g;
  $desc =~ s/\%3B/;/g;
  $desc =~ s/\%3D/=/g;

  $desc =~ s/\%27/'/g;
  $desc =~ s/\%28/(/g;
  $desc =~ s/\%29/)/g;

  return $desc;
}


sub collectData {
  my ($self, $dbRlsId, $hashRef) = @_;
  my $count = 0;
  my %geneHash = %{$hashRef};
  my @data = keys(%geneHash);

  foreach my $gene (@data) {
    $count++;

    my %y = %{$geneHash{$gene}};
    my @props = keys(%y); # keys are the various properties

    # product
    my $product = $geneHash{$gene}{product};
    $self->insertOldAnnotation($count, $gene, $dbRlsId, 'product', $geneHash{$gene}{product});

    # GO IDs
    my $goArrRef = $geneHash{$gene}{GO};
    if ( $goArrRef) {
      foreach my $go (@{$goArrRef}) {
	$self->insertOldAnnotation($count, $gene, $dbRlsId, 'GO', $go);
      }
    }

    # EC numbers
    my $ecArrRef = $geneHash{$gene}{EC};
    if ($ecArrRef) {
      foreach my $ec (@{$ecArrRef}) {
	$self->insertOldAnnotation($count, $gene, $dbRlsId, 'EC', $ec);
      }
    }


    # sequence
    my $seq = $geneHash{$gene}{sequence};
    $self->insertOldSequence($count, $gene, $dbRlsId, $geneHash{$gene}{sequence});

  }

  print "INSERT Total Genes = $count\n";
}

sub insertOldAnnotation {
  my ($self, $count, $id, $dbRlsId, $type, $value) = @_;

  my $oldAnnotation = GUS::Model::ApiDB::OldAnnotation->new({ source_id => $id,
							      type      => $type,
							      value     => $value,
							      external_database_release_id =>$dbRlsId
							    });
  $oldAnnotation->submit();

  $self->undefPointerCache() if $count % 1000 == 0;
}


sub insertOldSequence {
  my ($self, $count, $id, $dbRlsId, $sequence) = @_;

  my $oldSequence = GUS::Model::ApiDB::OldCodingSequence->new({ source_id       => $id,
								coding_sequence => $sequence,
								external_database_release_id =>$dbRlsId
							      });
  $oldSequence->submit();

  $self->undefPointerCache() if $count % 100 == 0;

}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.OldAnnotation','ApiDB.OldCodingSequence');
}


return 1;
