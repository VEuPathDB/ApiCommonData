package ApiCommonData::Load::Plugin::InsertVariantProductSummary;

@ISA = qw(GUS::PluginMgr::Plugin);

use GUS::Model::ApiDB::VariantProductSummary;
use GUS::PluginMgr::Plugin;
use strict;
# ----------------------------------------------------------------------
my $argsDeclaration =
  [
   fileArg({name           => 'variantProductFile',
            descr          => 'file for the sample data',
            reqd           => 1,
            mustExist      => 1,
            format         => '',
            constraintFunc => undef,
            isList         => 0, })
  ];


my $documentation = { purpose          => "",
                      purposeBrief     => "",
                      notes            => "",
                      tablesAffected   => "",
                      tablesDependedOn => "",
                      howToRestart     => "",
                      failureCases     => "" };

# ----------------------------------------------------------------------

sub new {
  my ($class) = @_;
  my $self = {};
  bless($self,$class);

  $self->initialize({ requiredDbVersion => 4.0,
                      cvsRevision       => '$Revision$',
                      name              => ref($self),
                      argsDeclaration   => $argsDeclaration,
                      documentation     => $documentation});

  return $self;
}

# ======================================================================

sub run {
 my ($self) = @_;

 my ($codon, $position_in_codon, $transcript, $count, $product, $ref_location_cds, $ref_location_protein);

 my $fileName = $self->getArg('variantProductFile');
 my $rowCount = 0;

 open(my $data, '<', $fileName) || die "Could not open file $fileName: $!";
 while (my $line = <$data>) {
     my $rowCount++;
     chomp $line;
     my ($codon, $position_in_codon, $transcript, $count, $product, $ref_location_cds, $ref_location_protein) = split(/\t/, $line);
     my $row = GUS::Model::ApiDB::VariantProductSummary->new({codon => $codon,
							           position_in_codon => $position_in_codon,
							           transcript_na_feature_id => $transcript,
                                                                   count => $count,
                                                                   product => $product,
                                                                   ref_location_cds => $ref_location_cds,
                                                                   ref_location_protein => $ref_location_protein
						 });
     $row->submit();
 }
 print "$rowCount rows added.\n"
}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.VariantProductSummary'
     );
}

1;
