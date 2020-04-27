use strict;
use warnings;
package ApiCommonData::Load::Biom::UserDatasetsStorage;
use GUS::ObjRelP::DbiDatabase;
use DBI;
use Log::Log4perl;
my $log = Log::Log4perl->get_logger(__PACKAGE__);

# The big tables are loaded with sqlldr
# We create logs and control files in current working directory
use ApiCommonData::Load::Fifo;
use ApiCommonData::Load::Sqlldr;

sub new {
  my ($class, $db) = @_;
  my $self = {};
  my $dbh = $db->getQueryHandle(0);
  $dbh->{RaiseError} = 1;

  $self->{insertPresenterSth} = $dbh->prepare(<<SQL) or $log->logdie($dbh->errstr);
    insert into ApiDBUserDatasets.UD_Presenter
       (user_dataset_id, property_name, property_value)
    values (?,?,?)
SQL
  $self->{getNextSampleIdSth} = $dbh->prepare(<<SQL) or $log->logdie($dbh->errstr);
    select ApiDBUserDatasets.ud_Sample_sq.nextval from dual
SQL
  $self->{insertSampleNameSth} = $dbh->prepare(<<SQL) or $log->logdie($dbh->errstr);
    insert into ApiDBUserDatasets.ud_Sample
      (user_dataset_id, sample_id, name, display_name)
    values (?,?,?,?)
SQL
  $self->{getNextPropertyIdSth} = $dbh->prepare(<<SQL) or $log->logdie($dbh->errstr);
    select ApiDBUserDatasets.ud_Property_sq.nextval from dual
SQL
  $self->{insertPropertySth} = $dbh->prepare(<<SQL) or $log->logdie($dbh->errstr);
    insert into apidbUserDatasets.ud_Property
       (user_dataset_id, property_id, property, type, filter, distinct_values, parent, parent_source_id, description)
    values (?,?,?,?,?,?,?,?,?)
SQL
  $self->{insertSampleDetailSth} = $dbh->prepare(<<SQL) or $log->logdie($dbh->errstr);
    insert into ApiDBUserDatasets.ud_SampleDetail
      (user_dataset_id, sample_id, property_id, date_value, number_value, string_value)
    values (?,?,?,?,?,?)
SQL
  $self->{insertAbundanceSth} = $dbh->prepare(<<SQL) or $log->logdie($dbh->errstr);
    insert into apidbUserDatasets.ud_Abundance
       (user_dataset_id, sample_id, lineage, relative_abundance, absolute_abundance, ncbi_tax_id, kingdom, phylum, class, rank_order, family, genus, species)
    values (?,?,?,?,?,?,?,?,?,?,?,?,?)
SQL

  $self->{insertAggregatedAbundanceSth} = $dbh->prepare(<<SQL) or $log->logdie($dbh->errstr);
    insert into apidbUserDatasets.ud_AggregatedAbundance
       (user_dataset_id, sample_id, taxon_level_name, taxon_level, taxon_name, lineage, relative_abundance, absolute_abundance)
    values (?,?,?,?,?,?,?,?)
SQL
  $self->{deleteForUserDatasetIdSths} = [map {
    $dbh->prepare("delete from apidbUserDatasets.$_ where user_dataset_id=?") or $log->logdie($dbh->errstr)
  } reverse qw/ud_Presenter ud_Sample ud_Property ud_SampleDetail ud_Abundance ud_AggregatedAbundance ud_AggregatedAbundance/];

  $self->{commit} = sub {
    $dbh->commit;
  };

  my $END_OF_RECORD_DELIMITER = "#EOR#\n";
  my $END_OF_COLUMN_DELIMITER = "#EOC#\t";
  (my $EOR_LITERAL = $END_OF_RECORD_DELIMITER) =~ s/\n/\\n/;
  (my $EOC_LITERAL = $END_OF_COLUMN_DELIMITER) =~ s/\t/\\t/;

  $self->{insertAbundanceCreateWriter} = sub {
    my $login = $db->getLogin;
    my $password = $db->getPassword;
    my $dbiDsn      = $db->getDSN();
    my ($dbi, $type, $dbString) = split(':', $dbiDsn);

    my $fifo = ApiCommonData::Load::Fifo->new("insertAbundance.dat");
    my $ldr = ApiCommonData::Load::Sqlldr->new({_login => $login,
                                                     _password => $password,
                                                     _database => $dbString,
                                                     _direct => 0,
                                                     _controlFilePrefix => "insertAbundanceLdr",
                                                     _quiet => 0,
                                                     _infile_name => "insertAbundance.dat",
                                                     _reenable_disabled_constraints => 1,
                                                     _fields => [
"user_dataset_id", "sample_id", "lineage CHAR(1406)", "relative_abundance", "absolute_abundance", "ncbi_tax_id", "kingdom", "phylum", "class", "rank_order", "family", "genus", "species"
                                                     ],
                                                     _table_name => "apidbUserDatasets.ud_Abundance",
                                                     _rows => 100000
                                                    });
    $ldr->setLineDelimiter($EOR_LITERAL);
    $ldr->setFieldDelimiter($EOC_LITERAL);
    $ldr->writeConfigFile();

    my $processString = $ldr->getCommandLine();
    my $pid = $fifo->attachReader($processString);
    $processString=~s/$password/<password>/;
    $log->info("Running under PID $pid: $processString");
    my $fh = $fifo->attachWriter();
    my $writeRow = sub {
      print $fh join($END_OF_COLUMN_DELIMITER, map {defined $_ ? $_ : ""} @_) . $END_OF_RECORD_DELIMITER;
    };
    my $close = sub {
      $fifo->cleanup;
    };
    return $writeRow, $close;
  };

  $self->{insertAggregatedAbundanceCreateWriter} = sub {
    my $login = $db->getLogin;
    my $password = $db->getPassword;
    my $dbiDsn      = $db->getDSN();
    my ($dbi, $type, $dbString) = split(':', $dbiDsn);

    my $fifo = ApiCommonData::Load::Fifo->new("insertAggregatedAbundance.dat");
    my $ldr = ApiCommonData::Load::Sqlldr->new({_login => $login,
                                                     _password => $password,
                                                     _database => $dbString,
                                                     _direct => 0,
                                                     _controlFilePrefix => "insertAggregatedAbundanceLdr",
                                                     _quiet => 0,
                                                     _infile_name => "insertAggregatedAbundance.dat",
                                                     _reenable_disabled_constraints => 1,
                                                     _fields => [
"user_dataset_id", "sample_id", "taxon_level_name", "taxon_level", "taxon_name", "lineage CHAR(1406)", "relative_abundance", "absolute_abundance"
                                                     ],
                                                     _table_name => "apidbUserDatasets.ud_AggregatedAbundance",
                                                     _rows => 100000
                                                    });
    $ldr->setLineDelimiter($EOR_LITERAL);
    $ldr->setFieldDelimiter($EOC_LITERAL);
    $ldr->writeConfigFile();

    my $processString = $ldr->getCommandLine();
    my $pid = $fifo->attachReader($processString);
    $processString=~s/$password/<password>/;
    $log->info("Running under PID $pid: $processString");
    my $fh = $fifo->attachWriter();
    my $writeRow = sub {
      print $fh join($END_OF_COLUMN_DELIMITER, map {defined $_ ? $_ : ""} @_) . $END_OF_RECORD_DELIMITER;
    };
    my $close = sub {
      $fifo->cleanup;
    };
    return $writeRow, $close;
  };

  return bless $self, $class;
}
sub insertPresenter {
  my ($self, $userDatasetId, $propertyName, $propertyValue) = @_;
  $self->{insertPresenterSth}->execute($userDatasetId, $propertyName, $propertyValue);
}

sub insertSampleName {
  my ($self, $userDatasetId, $sampleGloballyUniqueName, $sampleDisplayName) = @_;
  
  $self->{getNextSampleIdSth}->execute;
  my ($sampleId) = $self->{getNextSampleIdSth}->fetchrow_array;

  $self->{insertSampleNameSth}
    ->execute($userDatasetId, $sampleId, $sampleGloballyUniqueName, $sampleDisplayName);

  return $sampleId;
}
sub insertProperty {
  my ($self, $userDatasetId, $propertyName, $propertyDetails) = @_;
  my %propertyDetails = %{$propertyDetails};

  $self->{getNextPropertyIdSth}->execute;
  my ($propertyId) = $self->{getNextPropertyIdSth}->fetchrow_array;

  $self->{insertPropertySth}
    ->execute($userDatasetId, $propertyId, $propertyName, @propertyDetails{qw/type filter distinct_values parent parent_source_id description/});

  return $propertyId;
}
sub insertSampleDetail {
  my ($self, $userDatasetId, $sampleId, $propertyId, $sampleDetail) = @_;
  my %sampleDetail = %{$sampleDetail};
  $self->{insertSampleDetailSth}
    ->execute($userDatasetId, $sampleId, $propertyId, @sampleDetail{qw/date_value number_value string_value/});
}

sub writeAbundance {
  my ($cb, $userDatasetId, $sampleId, $abundance) = @_;
  my %abundance = %{$abundance};
  my $ls = $abundance{levels};
  my @levels = $ls ? @{$ls} : map {undef} 1..7; 
  $cb->($userDatasetId, $sampleId, @abundance{qw/lineage relative_abundance absolute_abundance ncbi_taxon_id/}, @levels);
}

sub writeAggregatedAbundance {
  my ($cb, $userDatasetId, $sampleId, $aggregatedAbundance) = @_;
  my %aggregatedAbundance = %{$aggregatedAbundance};

  $cb->($userDatasetId, $sampleId, @aggregatedAbundance{qw/taxon_level_name taxon_level taxon_name lineage relative_abundance absolute_abundance/});
}

sub storeUserDataset {
  my ($self, $userDatasetId, $datasetSummary, $propertyDetailsByName, $sampleNamesInOrder, $sampleDetailsByName, $abundancesBySampleName, $aggregatedAbundancesBySampleName) = @_;
  return unless @{$sampleNamesInOrder};

  $log->info("storeUserDataset $userDatasetId");
  # Clean up any previous runs
  $self->deleteUserDataset($userDatasetId);

  # This gets queried when showing the dataset in the sample page
  # relying on the property being under "dataset_summary"
  $self->insertPresenter($userDatasetId, "dataset_summary", $datasetSummary);

  my %propertyIdsByName;
  for my $propertyName (keys %{$propertyDetailsByName}){
    $propertyIdsByName{$propertyName} = $self->insertProperty($userDatasetId, $propertyName, $propertyDetailsByName->{$propertyName});
  }
  $log->info(sprintf("Inserted %s properties", scalar keys %propertyIdsByName));

  my $numSamplesTotal = @{$sampleNamesInOrder};

  my %sampleIdsBySampleName;
  for my $i (0.. $#$sampleNamesInOrder){
    $log->info("Inserted sample IDs for $i / $numSamplesTotal samples")
      if $i and not $i % 1000;
    my $sampleName = $sampleNamesInOrder->[$i];
    my $sampleId = $self->insertSampleName($userDatasetId, "$userDatasetId-$sampleName", $sampleName);
    $sampleIdsBySampleName{$sampleName} = $sampleId;
  }

  for my $i (0.. $#$sampleNamesInOrder){
    $log->info("Inserted sample details for $i / $numSamplesTotal samples")
      if $i and not $i % 1000;
    my $sampleName = $sampleNamesInOrder->[$i];
    my $sampleId = $sampleIdsBySampleName{$sampleName};


    for my $sampleDetail (@{$sampleDetailsByName->{$sampleName}}){
      $self->insertSampleDetail($userDatasetId, $sampleId, $propertyIdsByName{$sampleDetail->{property}}, $sampleDetail);
    }
  }
  $self->{commit}->();
  
  my ($writeAbundanceCb, $closeAbundanceCb) = $self->{insertAbundanceCreateWriter}->();
  for my $i (0.. $#$sampleNamesInOrder){
    $log->info("Wrote abundances for $i / $numSamplesTotal samples")
      if $i and not $i % 1000;
    my $sampleName = $sampleNamesInOrder->[$i];
    my $sampleId = $sampleIdsBySampleName{$sampleName};

    for my $abundance (@{$abundancesBySampleName->{$sampleName}}){
      writeAbundance($writeAbundanceCb, $userDatasetId, $sampleId, $abundance);
    }
  }
  $closeAbundanceCb->();

  my ($writeAggregatedAbundanceCb, $closeAggregatedAbundanceCb) = $self->{insertAggregatedAbundanceCreateWriter}->();
  for my $i (0.. $#$sampleNamesInOrder){
    $log->info("Wrote aggregated abundances for $i / $numSamplesTotal samples")
      if $i and not $i % 1000;
    my $sampleName = $sampleNamesInOrder->[$i];
    my $sampleId = $sampleIdsBySampleName{$sampleName};

    for my $aggregatedAbundance (@{$aggregatedAbundancesBySampleName->{$sampleName}}){
      writeAggregatedAbundance($writeAggregatedAbundanceCb, $userDatasetId, $sampleId, $aggregatedAbundance);
    }
  } 
  $closeAggregatedAbundanceCb->();

  $log->info("Added data for $numSamplesTotal samples");
}


sub deleteUserDataset {
  my ($self, $userDatasetId) = @_;
  $log->info("deleteUserDataset $userDatasetId");
  my $numDeletedRows;
  for my $sth (@{$self->{deleteForUserDatasetIdSths}}){
    $numDeletedRows += $sth->execute($userDatasetId);
  }
  $log->info("deleted $numDeletedRows entries in tables with user dataset id $userDatasetId");
}
1;
