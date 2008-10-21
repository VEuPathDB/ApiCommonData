package ApiCommonData::Load::TuningConfig::TuningRegistry;


use strict;
use ApiCommonData::Load::TuningConfig::Log;

sub new {
    my ($class, $dbh) = @_;
    my $self = {};
    $self->{dbh} = $dbh;
    bless($self, $class);

    return $self;
}

sub getInfoFromRegistry {
    my ($self) = @_;

    my $dbh = $self->{dbh};

    my $sql = <<SQL;
      select imi.service_name, ti.instance_name, tf.subversion_url, tf.notify_emails
      from apidb.TuningInstance\@apidb.login_comment ti, apidb.TuningFamily\@apidb.login_comment tf,
           apidb.InstanceMetaInfo imi
      where ti.service_name(+) =  imi.service_name
        and ti.family_name = tf.family_name(+)
SQL

    my $stmt = $dbh->prepare($sql);
    $stmt->execute()
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");

    ($self->{service_name}, $self->{instance_name}, $self->{subversion_url}, $self->{notify_emails})
      = $stmt->fetchrow_array();

    ApiCommonData::Load::TuningConfig::Log::addErrorLog("no tuning info found in registry for service_name \"$self->{service_name}\"")
	if !defined $self->{subversion_url};
    $stmt->finish();
}

sub getSubversionUrl {
    my ($self) = @_;

    $self->getInfoFromRegistry() if !defined $self->{subversion_url};

    return($self->{subversion_url});
}

sub getNotifyEmails {
    my ($self) = @_;

    $self->getInfoFromRegistry() if !defined $self->{notify_emails};

    return($self->{notify_emails});
}

sub getInstanceName {
    my ($self) = @_;

    $self->getInfoFromRegistry() if !defined $self->{instance_name};

    return($self->{instance_name});
}

sub setLastUpdate {
    my ($self) = @_;

    my $dbh = $self->{dbh};
    my $processInfo = ApiCommonData::Load::TuningConfig::Log::getProcessInfo();

    my $sql = <<SQL;
      update apidb.TuningInstance\@apidb.login_comment
      set last_update = sysdate, last_updater = '$processInfo'
      where service_name = (select service_name from apidb.InstanceMetaInfo)
SQL

    my $stmt = $dbh->prepare($sql);
    $stmt->execute()
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");

    $stmt->finish();
}

sub setLastCheck {
    my ($self) = @_;

    my $dbh = $self->{dbh};
    my $processInfo = ApiCommonData::Load::TuningConfig::Log::getProcessInfo();

    my $sql = <<SQL;
      update apidb.TuningInstance\@apidb.login_comment
      set last_check = sysdate, last_checker = '$processInfo'
      where service_name = (select service_name from apidb.InstanceMetaInfo)
SQL

    my $stmt = $dbh->prepare($sql);
    $stmt->execute()
      or ApiCommonData::Load::TuningConfig::Log::addErrorLog("\n" . $dbh->errstr . "\n");

    $stmt->finish();
}

1;
