package ApiCommonData::Load::Plugin::InsertVariantAlleleSummary;

@ISA = qw(GUS::PluginMgr::Plugin);

use GUS::Model::ApiDB::VariantAlleleSummary;
use GUS::PluginMgr::Plugin;
use strict;
# ----------------------------------------------------------------------
my $argsDeclaration =
  [
   fileArg({name           => 'variantAlleleFile',
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

 my ($allele, $distinct_strain_count, $allele_count, $average_coverage, $average_read_percent);

 my $fileName = $self->getArg('variantAlleleFile');
 my $rowCount = 0;

 open(my $data, '<', $fileName) || die "Could not open file $fileName: $!";
 while (my $line = <$data>) {
     my $rowCount++;
     chomp $line;
     my ($allele, $distinct_strain_count, $allele_count, $average_coverage, $average_read_percent) = split(/\t/, $line);
     my $row = GUS::Model::ApiDB::VariantAlleleSummary->new({allele => $allele,
							     distinct_strain_count => $distinct_strain_count, 
							     allele_count => $allele_count,
							     average_coverage => $average_coverage,
							     average_read_percent => $average_read_percent
						 });
     $row->submit();
 }
 print "$rowCount rows added.\n"
}


sub undoTables {
  my ($self) = @_;

  return ('ApiDB.VariantAlleleSummary'
     );
}

1;
