# <!-- coding: utf-8 -->
#
# les informations en format txt
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
sub txt_masters_lire {
  my $self = shift;
  warn "txt_masters_lire()";
  my $f_txt = "$self->{cfgDir}/masters.txt";
  open(TXT, "< :utf8", $f_txt) or die;
  my $ligne = <TXT>;
  while( my $ligne = <TXT>) {
    chomp($ligne);
    my ($id, $ref, $description, $colour, $text_colour) = split(";", $ligne);
#    $name =~ s{(\S)<}{$1 <}g;
#    warn "$ref => $name";
    $self->{masters}->{$id} = {
      ref => $ref,
      description => $description,
      colour => uc($colour),
      text_colour => uc($text_colour),
      name => sprintf("%s %s", $self->{reseau_ligne}, $ref)
    };
    $self->{masters_ref}->{$ref} = {
      ref => $ref,
      description => $description,
      colour => uc($colour),
      text_colour => uc($text_colour),
      name => sprintf("%s %s", $self->{reseau_ligne}, $ref)
    };
  }
  close(TXT);
  return  $self->{masters};
}
sub txt_routes_lire {
  my $self = shift;
  warn "txt_routes_lire()";
  $self->txt_masters_lire();
  my $f_txt = "$self->{cfgDir}/routes.txt";
  open(TXT, "< :utf8", $f_txt) or die;
  my $ligne = <TXT>;
  while( my $ligne = <TXT>) {
    chomp($ligne);
    my ($id, $ref, $name, $description, $from, $to) = split(";", $ligne);
#    $name =~ s{(\S)<}{$1 <}g;
#    warn "$ref => $name";
    $self->{routes}->{$id} = {
      ref => $ref,
      description => $description,
      from => $from,
      to => $to,
      name => $name,
      colour => $self->{masters_ref}->{$ref}->{colour},
      text_colour => $self->{masters_ref}->{$ref}->{text_colour},
    };
  }
  close(TXT);
  return  $self->{routes};
}
1;