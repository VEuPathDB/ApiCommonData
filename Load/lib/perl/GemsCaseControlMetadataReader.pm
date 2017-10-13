package ApiCommonData::Load::GemsCaseControlMetadataReader;
use base qw(ApiCommonData::Load::MetadataReader);

use strict;

use ApiCommonData::Load::MetadataReader;

use Data::Dumper;

use Text::CSV;

sub getLineParser {
  my ($self) = @_;

  return $self->{_line_parser};
}

sub setLineParser {
  my ($self, $lp) = @_;

  $self->{_line_parser} = $lp;
}


sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);

  my $csv = Text::CSV->new({ binary => 1, 
                               sep_char => "," 
                           }) 
      or die "Cannot use CSV: ".Text::CSV->error_diag ();  

  $self->setLineParser($csv);

  return $self;
}

sub splitLine {
  my ($self, $delimiter, $line) = @_;

  my $csv = $self->getLineParser();

  my @columns;
  if($csv->parse($line)) {
    @columns = $csv->fields();
  }
  else {
    die "Could not parse line: $line";
  }

  return wantarray ? @columns : \@columns;
}


sub clean {
  my ($self, $ar) = @_;

  my $clean = $self->SUPER::clean($ar);

  for(my $i = 0; $i < scalar @$clean; $i++) {

    my $v = $clean->[$i];

    my $lcv = lc($v);

    if($lcv eq 'na' || $lcv eq 'a' || $lcv eq 'f' || $lcv eq 't' || $lcv eq 'u' || $lcv eq 'n' || $lcv eq 'r') {
      $clean->[$i] = undef;
    }
  }
  return $clean;
}

sub adjustHeaderArray { 
  my ($self, $ha) = @_;

  my @headers = map { $_ =~ s/\"//g; $_;} @$ha;

  return \@headers;
}

1;

package ApiCommonData::Load::GemsCaseControlMetadataReader::ParticipantReader;
use base qw(ApiCommonData::Load::GemsCaseControlMetadataReader);

use strict;

sub getParentPrefix {
  my ($self, $hash) = @_;

  return "GCCHH_";
}

sub makeParent {
  my ($self, $hash) = @_;

  if($hash->{"primary_key"}) {
    return uc $hash->{"primary_key"};
  }

  return $hash->{childid};
}

sub makePrimaryKey {
  my ($self, $hash) = @_;

  if($hash->{"primary_key"}) {
    return uc $hash->{"primary_key"};
  }

  return $hash->{childid};
}

sub getPrimaryKeyPrefix {
  my ($self, $hash) = @_;

  unless($hash->{"primary_key"}) {
    return "GCCP_";
  }

  return "";
}


sub cleanAndAddDerivedData {
  my ($self, $hash) = @_;

  my @a = ('F11_BLOOD',
           'F11_PUS',
           'F11_MUCUS',
           'F7_BLOOD',
           'F7_FEVER',
           'F7_VOMIT',
           'F4B_CHEST_INDRW',
           'F4B_RECTAL',
           'F4B_BIPEDAL',
           'F4B_ABN_HAIR',
           'F4B_UNDER_NUTR',
           'F4B_SKIN_FLAKY',
           'F7_BIPEDAL',
           'F7_ABN_HAIR',
           'F7_UNDER_NUTR',
           'F7_SKIN_FLAKY',
           'F5_DIAG_TYP',
           'F5_DIAG_MAL',
           'F5_DIAG_PNE',
           'F5_DIAG_MENG',
           'F5_DIAG_OTHR',
           'F5_EXP_DRH',
           'F5_EXP_DYS',
           'F5_EXP_COU',
           'F5_EXP_FEVER',
           'F5_EXP_OTHR',
           'F5_EXP_OTHR2',
           'F5_EXP_RECTAL',
           'F5_EXP_CONVUL',
           'F5_EXP_ARTHRITIS',
           'F5_EXP_DRH_VISIT',
           'F5_EXP_DYS_VISIT',
           'F5_EXP_COU_VISIT',
           'F5_EXP_FEVER_VISIT',
           'F5_EXP_OTHR_VISIT',
           'F5_EXP_OTHR2_VISIT',
           'F5_RECTAL',
           'F5_BIPEDAL',
           'F5_ABN_HAIR',
           'F5_UNDER_NUTR',
           'F5_SKIN_FLAKY',
           'F16_CAMPY_NONJEJ',
           'F16_CAMPY_NONSPEC',
           'F16CORR_SHIG_4A',
           'F16CORR_SHIG_4B',
           'F16CORR_SHIG_4C',
           'F16CORR_SHIG_5A',
           'F16CORR_SHIG_5B',
           'F16CORR_SHIG_6',
           'F16CORR_SHIG_X',
           'F16CORR_SHIG_Y',
           'F16CORR_SHIG_NONTYP',
           'F16CORR_NONTYPABLE',
           'F16_VIB_CHOLERAE',
           'F16_VIB_01',
           'F16_VIB_0139',
           'F16_VIB_NON',
           'F16_VIB_INABA',
           'F16_VIB_OGAWA',
           'F16_VIB_PARAHAEM',
           'F16_VIB_OTHER',
           'F17CORR_RESULT_ESTA',
           'F17CORR_RESULT_ELTB',
           'F17CORR_RESULT_BFPA',
           'F17CORR_RESULT_AATA',
           'F17CORR_RESULT_AAIC',
           'F17CORR_RESULT_EAE',
           'F17A_STX2',
           'F17A_SEN',
           'F17A_STX1',
           'F17A_EFA1',
           'pn1',
           'pn2',
           'pn3',
           'pn4',
           'pn5',
           'pn6',
           'pn7',
           'pn8',
           'pn9',
           'pn11',
           'pn12',
           'pn13',
           'pn14',
           'pn17',
           'pn19',
           'pn20',
           'pn21',
           'pn22',
           'pn23',
           'pn24',
           'pn25',
           'pn26',
           'pn27',
           'pn28',
           'pn29',
           'pn30',
           'pn31',
           'pn32',
           'pn33',
           'pn34',
           'pn35',
           'pn36',
           'pn37',
           'pn38',
           'pn39',
           'pn40',
           'pn41',
           'pn42',
           'pn10',
           'pn15',
           'pn16',
           'F4A_DRH_BLOOD',
           'F4A_DRH_VOMIT',
           'F4A_DRH_THIRST',
           'F4A_DRH_LESSDRINK',
           'F4A_DRH_UNDRINK',
           'F4A_DRH_BELLYPAIN',
           'F4A_DRH_FEVER',
           'F4A_DRH_RESTLESS',
           'F4A_DRH_LETHRGY',
           'F4A_DRH_CONSC',
           'F4A_DRH_STRAIN',
           'F4A_DRH_PROLAPSE',
           'F4A_DRH_COUGH',
           'F4A_DRH_BREATH',
           'F4A_DRH_CONV',
           'F4A_CUR_THIRSTY',
           'F4A_CUR_NODRINK',
           'F4A_CUR_SUNKEYES',
           'F4A_CUR_SKIN',
           'F4A_CUR_RESTLESS',
           'F4A_CUR_LETHRGY',
           'F4A_CUR_DRYMOUTH',
           'F4A_CUR_FASTBREATH'
      );

  foreach my $key (@a) {
    my $lcKey = lc($key);
    my $v = $hash->{$lcKey};

    if($v == 0) {
      $hash->{"neg_$lcKey"} = $v;
    }
    elsif($v == 1) {
      $hash->{"pos_$lcKey"} = $v;
    }
    elsif($v == 9) {
      $hash->{"other_$lcKey"} = $v;
    }
    else {
      die "Unknown value $v for header $key";
    }
  }
}





1;
