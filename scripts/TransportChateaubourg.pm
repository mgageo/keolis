# <!-- coding: utf-8 -->
#
# les informations du réseau Chateaubourg
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;

# pour créer les relations "route"
sub chateaubourg_routes_creer {
  my $self = shift;
  warn "chateaubourg_routes_creer() debut";
  $self->chateaubourg_masters();
  my ( $format, $osm);
  foreach my $ref (sort keys %{$self->{masters}} ) {
    warn $ref;
    my $iti = $self->{masters}->{$ref};
#  warn Dumper $iti;
    $format = <<'EOF';
  <relation id="%s" timestamp="0" changeset="1" version="1">
    <tag k="description" v="%s"/>
    <tag k="name" v="Bus Châteaubourg Ligne %s"/>
    <tag k="network" v="%s"/>
    <tag k="operator" v="%s"/>
    <tag k="ref" v="%s"/>
    <tag k="route" v="bus"/>
    <tag k="type" v="route"/>
    <tag k="source" v="%s"/>
  </relation>
EOF
    $osm = sprintf($format , $self->{relation_id}, xml_escape($iti->{name}), $ref, $self->{network}, $self->{operator}, $ref, $self->{source});
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'create');
    $self->{relation_id}--;
    $format = <<'EOF';
  <relation id="%s" timestamp="0" changeset="1" version="1">
    <tag k="description" v="%s"/>
    <tag k="name" v="Bus Châteaubourg Ligne %s"/>
    <tag k="network" v="%s"/>
    <tag k="operator" v="%s"/>
    <tag k="ref" v="%s"/>
    <tag k="route_master" v="bus"/>
    <tag k="service" v="busway"/>
    <tag k="type" v="route_master"/>
    <tag k="source" v="%s"/>
  </relation>
EOF
    $osm = sprintf($format , $self->{relation_id}, xml_escape($iti->{name}), $ref, $self->{network}, $self->{operator}, $ref, $self->{source});
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'create');
    $self->{relation_id}--;
  }
  warn "chateaubourg_routes_creer()";
}
#
# pour mettre à jour les relations "route"
sub chateaubourg_routes_level0 {
  my $self = shift;
  warn "chateaubourg_routes_level0() debut";
  my $hash = $self->oapi_get("relation['network'='$self->{network}'];out meta;", "$self->{cfgDir}/routes_level0.osm");
  my $level0 = '';
  foreach my $relation (@{$hash->{relation}}) {
    warn sprintf("chateaubourg_routes_level0() r%s ;ref:%s;%s;%s;%s;%s", $relation->{id}, $relation->{tags}->{type}, $relation->{tags}->{name}, $relation->{tags}->{description}, $relation->{tags}->{ref},$relation->{user}, $relation->{timestamp}, scalar(@{$relation->{nodes}}), scalar(@{$relation->{ways}}));
    $level0 .= 'r' . $relation->{id} . ',';
    $self->{id} = $relation->{id};
    $self->{'tags'}->{'ref'} = $relation->{tags}->{ref};
  }
  chop $level0;
  warn "chateaubourg_routes_level0() level0: $level0";
}
#
# pour mettre à jour les relations "route"
sub chateaubourg_routes_diff {
  my $self = shift;
  warn "chateaubourg_routes_diff() debut";
  $self->chateaubourg_masters();
  my $hash = $self->oapi_get("relation[type=route][route=bus]['network'='$self->{network}'];out meta;", "$self->{cfgDir}/routes_diff.osm");
  my $level0 = '';
  foreach my $relation (@{$hash->{relation}}) {
    warn sprintf("chateaubourg_routes_diff() r%s ;ref:%s;%s;%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp}, scalar(@{$relation->{nodes}}), scalar(@{$relation->{ways}}));
    $level0 .= 'r' . $relation->{id} . ',';
    $self->{id} = $relation->{id};
    $self->{'tags'}->{'ref'} = $relation->{tags}->{ref};
    $self->chateaubourg_route_diff();
  }
  chop $level0;
  warn "chateaubourg_routes_diff() level0: $level0";
}
sub chateaubourg_route_diff {
  my $self = shift;
  warn "chateaubourg_route_diff() debut";
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
#  $tags->{"ref:chateaubourg"} = "$ref-AR";
  my $osm = $self->{oOSM}->modify_tags($relation_osm, $tags, qw(name description));
  $osm =~ s{<member type="node" ref="(\d+)" role="[^"]*"/>}{<member type="node" ref="$1" role="platform"/>}gsm;
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' modification tags', 'modify');
  warn "chateaubourg_route_diff() fin";
}
1;