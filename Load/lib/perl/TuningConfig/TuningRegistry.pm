package ApiCommonData::Load::TuningConfig::TuningRegistry;


use strict;

sub new {
    my ($class, $dbh, $dblink) = @_;
    my $self = {};
    $self->{dbh} = $dbh;
    $dblink = "apidb.login_comment" if !$dblink;
    $self->{dblink} = $dblink;
    bless($self, $class);

    return $self;
}

sub getInfoFromRegistry {
    my ($self) = @_;

    my $dbh = $self->{dbh};
    my $dblink = $self->{dblink};
    $dblink = "\@" . $dblink
      if ($dblink && !($dblink =~ /^\@/));

    my $sql = <<SQL;
      select imi.instance_nickname, ti.instance_nickname, tf.subversion_url,
             tf.notify_emails, tf.is_live, tf.config_file, imi.project_id, imi.version
      from apidb_r.TuningInstance$dblink ti, apidb_r.TuningFamily$dblink tf,
           apidb.InstanceMetaInfo imi
      where lower(ti.instance_nickname(+)) =  lower(imi.instance_nickname)
        and ti.family_name = tf.family_name(+)
SQL

    my $stmt = $dbh->prepare($sql)
      or print STDERR "\n" . $dbh->errstr . "\n";

    $stmt->execute()
      or print STDERR "\n" . $dbh->errstr . "\n";

    ($self->{service_name},
     $self->{instance_name},
     $self->{subversion_url},
     $self->{notify_emails},
     $self->{is_live},
     $self->{config_file},
     $self->{project_id},
     $self->{version},
    )
      = $stmt->fetchrow_array();

    print STDERR "no tuning info found in registry for instance_nickname \"$self->{service_name}\".\n"
						       . "Use \"tuningMgrMgr addInstance\" to add this instance to the registry."
	if !defined $self->{subversion_url};
    $stmt->finish();
}

sub getSubversionUrl {
    my ($self) = @_;

    $self->getInfoFromRegistry() if !defined $self->{subversion_url};

    return($self->{subversion_url});
}

sub getSubversionBranch {
    my ($self) = @_;

    my $Url = $self->getSubversionUrl;

    my $branch;

    if ($Url =~ /ApiCommonData.(.*).Load.lib/) {
      $branch = $1;
    } else {
      print STDERR "Can't parse branch out of Subversion URL \"$Url\"";
    }

    return($branch);
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

sub getIsLive {
    my ($self) = @_;

    $self->getInfoFromRegistry() if !defined $self->{is_live};

    return($self->{is_live});
}

sub getConfigFile {
    my ($self) = @_;

    $self->getInfoFromRegistry() if !defined $self->{config_file};

    return($self->{config_file});
}

sub getProjectId {
    my ($self) = @_;

    $self->getInfoFromRegistry() if !defined $self->{project_id};

    return($self->{project_id});
}

sub getVersion {
    my ($self) = @_;

    $self->getInfoFromRegistry() if !defined $self->{version};

    return($self->{version});
}

sub getDblinkSuffix {
  my ($self) = @_;

  # never append suffixes to db links

  return "";

  # old code:
  if ($self->getIsLive()) {
    return "";
  } else {
    return "build";
  }
}

sub getDblink {
  my ($self) = @_;
  return $self->{dblink};
}

1;
