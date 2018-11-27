# <!-- coding: utf-8 -->
#
# les traitements sur les différents réseaux
#
#
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseExcel::Utility qw(ExcelFmt);
use WWW::Mechanize qw();
#
#
#  perl scripts/keolis.pl --DEBUG 0 --DEBUG_GET 1 reseau star
sub reseau {
  my $self = shift;
  my $reseau = shift;
  my $dsn = "$self->{cfgDir}/agency.xls";
  warn "reseau() dsn: $dsn";
  my $parser = Spreadsheet::ParseExcel->new();
  my $workbook = $parser->parse($dsn);
  if(!defined $workbook) {
    die $parser->error(),".\n";
  };
  my( $oWkS, $oWkC, $iC, $iR);
  my $oWkS = $workbook->worksheet('reseaux');
  my $ok = 0;
  for my $iR (1 .. $oWkS->{MaxRow}) {
    $oWkC = $oWkS->{Cells}[$iR][0];
    if ( ! $oWkC ) {
      next;
    }
    my $key = $oWkC->value();
    if ( $key ne $reseau ) {
      next;
    }
    warn "key: $key";
    $self->{cfgDir} .= '/' . uc($key);
    $self->{reseau} = $key;
    for my $iC (1..10) {
      $oWkC = $oWkS->{Cells}[$iR][$iC];
      if ( ! $oWkC ) {
        next;
      }
      my $v = $oWkC->value();
      $oWkC = $oWkS->{Cells}[0][$iC];
      my $k = $oWkC->value();
      if ( $k =~ m{_id$} ) {
        $self->{gtfs}->{$k} = $v;
      } else {
        $self->{$k} = $v;
      }
      warn "$k => $v";
    }
    $ok++;
    last;
  }
  if ( $ok == 0 ) {
    confess "reseau inconnu: $reseau";
  }
  $self->{k_ref} = sprintf('ref:%s', $self->{network});
  my $sp = shift;
  $self->$sp(@_);
}
1;