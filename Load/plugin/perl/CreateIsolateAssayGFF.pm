package ApiCommonData::Load::Plugin::CreateIsolateAssayGFF;
@ISA = qw(GUS::PluginMgr::Plugin);

use strict;
use warnings;

use GUS::PluginMgr::Plugin;

my $argsDeclaration =
  [
    stringArg({ name   => 'extDbRlsName',
                descr  => 'External Database Release name of the AA sequences',
                constraintFunc => undef,
                isList => 0,
                reqd   => 1,
              }),

    stringArg({ name   => 'extDbRlsVer',
                descr  => 'External Database Release version of the AA sequences',
                constraintFunc => undef,
                isList => 0,
                reqd   => 1,
              }),
  ];

my $purposeBrief = <<PURPOSEBRIEF;
Convert Isolate Chip Assay data (Broad Barcode/3k Chip) into 
Sequence Typed SNP gff format 
PURPOSEBRIEF

my $purpose = <<PURPOSE;
Convert Isolate Chip Assay data (Broad Barcode/3k Chip) into 
Sequence Typed SNP gff format 
PURPOSE

my $howToRestart = <<PLUGIN_RESTART;
PLUGIN_RESTART

my $failureCases = <<PLUGIN_FAILURE_CASES;
PLUGIN_FAILURE_CASES

my $notes = <<PLUGIN_NOTES;
PLUGIN_NOTES

my $documentation = { purposeBrief     => $purposeBrief,
                      purpose          => $purpose,
                      howToRestart     => $howToRestart,
                      failureCases     => $failureCases,
                      notes            => $notes, 
                      tablesAffected   => "",
                      tablesDependedOn => "",
                    };

sub new {
  my $class = shift;
  $class = ref $class || $class;
  my $self = {};
  
  bless $self, $class;

  $self->initialize({ requiredDbVersion => 3.6,
                       cvsRevision      => '$Revision$',
                       name             => ref($self),
                       argsDeclaration  => $argsDeclaration,
                       documentation    => $documentation
                   });

  return $self;
}

sub run {
  my ($self) = @_;
  my $extDbRlsName = $self->getArg("extDbRlsName");
  my $extDbRlsVer = $self->getArg("extDbRlsVer");

  my $extDbRlsId = $self->getExtDbRlsId($extDbRlsName, $extDbRlsVer);

  my $projectId = $self->getDb()->getDefaultProjectId();

   unless ($extDbRlsId) {
       die "No such External Database Release / Version:\n $extDbRlsName / $extDbRlsVer\n";
  }

  my @dbNames = split /_/, $extDbRlsName;

  my $file = "/eupath/data/EuPathDB/manualDelivery/$projectId/". $dbNames[0], "/". $dbNames[1]. "/". $dbNames[2] ."/". $extDbRlsVer . "/final/isolateSNPs.txt";

  #my $dbh = $self->getQueryHandle();

  open (F, $file);
  while(<F>) {
    chomp;
    print "$_\n";

  }

  close F;
}
