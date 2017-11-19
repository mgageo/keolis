# <!-- coding: utf-8 -->
#
# les informations du réseau  	Vitré Communauté
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
sub vitre_masters {
  my $self = shift;
  warn "vitre_masters()";
  my $f_txt = "$self->{cfgDir}/masters.txt";
  open(TXT, "< :utf8", $f_txt) or die;
  my $ligne = <TXT>;
  while( my $ligne = <TXT>) {
    chomp($ligne);
    my ($ref, $name) = split(";", $ligne);
    $self->{masters}->{$ref} = {
      name => $name,
    };
  }
  close(TXT);
}
#
# pour mettre à jour les relations "route"
sub vitre_routes_diff {
  my $self = shift;
  warn "vitre_routes_diff() debut";
  $self->vitre_masters();
  my $hash = $self->oapi_get("relation[type=route][route=bus]['network'='$self->{network}'];out meta;", "$self->{cfgDir}/routes_diff.osm");
  my $level0 = '';
  foreach my $relation (@{$hash->{relation}}) {
    warn sprintf("vitre_routes_diff() r%s ;ref:%s;%s;%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp}, scalar(@{$relation->{nodes}}), scalar(@{$relation->{ways}}));
    $level0 .= 'r' . $relation->{id} . ',';
    $self->{id} = $relation->{id};
    $self->{'tags'}->{'ref'} = $relation->{tags}->{ref};
    $self->vitre_route_diff();
  }
  chop $level0;
  warn "vitre_routes_diff() level0: $level0";
}
sub vitre_route_diff {
  my $self = shift;
  warn "vitre_route_diff() debut";
  my $id = $self->{id};
  my $ref = $self->{tags}->{ref};
  if ( not defined $self->{masters}->{$ref} ) {
    warn "ref:$ref";
    return;
  }

  my $name = $self->{masters}->{$ref}->{name};
  my $tags;
  my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $id));
  $tags->{description} = xml_escape($name);
  $tags->{name} = xml_escape("Bus Vitré Ligne $ref");
#  $tags->{"ref:vitre"} = "$ref-AR";
  my $osm = $self->{oOSM}->modify_tags($relation_osm, $tags, qw(name description));
  $osm =~ s{<member type="node" ref="(\d+)" role="[^"]*"/>}{<member type="node" ref="$1" role="platform"/>}gsm;
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' modification tags', 'modify');
  warn "vitre_route_diff() fin";
}
1;