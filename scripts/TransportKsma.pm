# <!-- coding: utf-8 -->
#
# les informations du réseau KSMA
# http://www.ksma.fr/fileadmin/Sites/ksma/documents/timeo/Liste_des_codes_TIMEO_hiver_au_2604.pdf
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
sub ksma_masters {
  my $self = shift;
  warn "ksma_masters()";
  my $f_txt = "$self->{cfgDir}/masters.txt";
  open(TXT, "< :utf8", $f_txt) or die;
  my $ligne = <TXT>;
  while( my $ligne = <TXT>) {
    chomp($ligne);
    my ($ref, $color, $bgcolor, $name) = split(";", $ligne);
    $name =~ s{(\S)<}{$1 <}g;
#    warn "$ref => $name";
    $self->{masters}->{$ref} = {
      name => $name,
      color => $color,
      bgcolor => $bgcolor
    };
  }
  close(TXT);
}
# https://smallpdf.com/fr/pdf-en-excel
sub ksma_routes {
  my $self = shift;
  warn "ksma_routes()";
  my $f_txt = "$self->{cfgDir}/routes.txt";
  open(TXT, "< :utf8", $f_txt) or die;
  while( my $ligne = <TXT>) {
    chomp($ligne);
# Ligne 1 : Sens : INTRA-MUROS vers LA MADELEINE
    if ( $ligne =~ m{^Ligne (.*) : Sens : (.*)} ) {
      my ($ref, $sens) = ($1, $2);
      warn "$ref, $sens";
      next;
    }
  }
  close(TXT);
}
#
# pour mettre à jour les relations "route"
sub ksma_routes_diff {
  my $self = shift;
  warn "ksma_routes_diff() debut";
  $self->ksma_masters();
  my $hash = $self->oapi_get("relation[network='fr_ksma'][type=route][route=bus];out meta;", "$self->{cfgDir}/routes_diff.osm");
  my $level0 = '';
  foreach my $relation (@{$hash->{relation}}) {
    my $ref_network = $relation->{tags}->{'ref:ksma'};
    if ( $ref_network =~ m{\-[ABCD]$} ) {
      next;
    }
    warn sprintf("ksma_routes_diff() r%s ;ref:%s;%s;%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp}, scalar(@{$relation->{nodes}}), scalar(@{$relation->{ways}}));
    $level0 .= 'r' . $relation->{id} . ',';
    $self->{id} = $relation->{id};
    $self->{'tags'}->{'ref'} = $relation->{tags}->{ref};
#    $self->ksma_route_diff();
  }
  chop $level0;
  warn "ksma_routes_diff() level0: $level0";
}
sub ksma_route_diff {
  my $self = shift;
  warn "ksma_route_diff() debut";
  my $id = $self->{id};
  my $ref = $self->{tags}->{ref};
  if ( not defined $self->{masters}->{$ref} ) {
    warn "ref:$ref";
    return;
  }

  my $name = $self->{masters}->{$ref}->{name};
  my $tags;
  $tags->{text_color} =  $self->{masters}->{$ref}->{color};
  $tags->{colour} =  $self->{masters}->{$ref}->{bgcolor};
  my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $id));
  $tags->{description} = xml_escape($name);
  $tags->{name} = xml_escape("Bus Saint-Malo Ligne $ref");
#  $tags->{"ref:ksma"} = "$ref-AR";
  my $osm = $self->{oOSM}->modify_tags($relation_osm, $tags, qw(name description text_color colour));
  $osm =~ s{<member type="node" ref="(\d+)" role="[^"]*"/>}{<member type="node" ref="$1" role="platform"/>}gsm;
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' modification tags', 'modify');
  warn "ksma_route_diff() fin";
}
#
# pour mettre à jour les relations "route"
sub ksma_routes_master_diff {
  my $self = shift;
  warn "ksma_routes_master_diff() debut";
  $self->ksma_masters();
  my $hash = $self->oapi_get("relation[network='$self->{network}'][type=route_master][route_master=bus];out meta;", "$self->{cfgDir}/routes_master_diff.osm");
  my $level0 = '';
# on indexe par ref
  my $refs;
  foreach my $relation (@{$hash->{relation}}) {
    $refs->{$relation->{tags}->{ref}} = $relation;
    warn sprintf("ksma_routes_master_diff() r%s ;ref:%s;%s;%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp}, scalar(@{$relation->{nodes}}), scalar(@{$relation->{ways}}));
    $level0 .= 'r' . $relation->{id} . ',';
    $self->{id} = $relation->{id};
    $self->{'tags'}->{'ref'} = $relation->{tags}->{ref};
    $self->{'ref'} = $relation->{tags}->{ref};
#    $self->ksma_route_master_diff();
    $self->valid_route_master();
  }
  exit;
  chop $level0;
  warn "ksma_routes_master_diff() level0: $level0";
  foreach my $ref (sort keys %{$self->{masters}} ) {
    warn $ref;
    if ( defined $refs->{$ref} ) {
      next;
    }
    $self->{relation_id}--;
    my $iti = $self->{masters}->{$ref};
#  warn Dumper $iti;
    my $format = <<'EOF';
  <relation id="%s" timestamp="0" changeset="1" version="1">
    <tag k="description" v="%s"/>
    <tag k="name" v="Bus Saint-Malo Ligne %s"/>
    <tag k="network" v="%s"/>
    <tag k="operator" v="%s"/>
    <tag k="ref" v="%s"/>
    <tag k="route_master" v="bus"/>
    <tag k="service" v="busway"/>
    <tag k="type" v="route_master"/>
    <tag k="colour" v="%s"/>
    <tag k="text_color" v="%s"/>
    <tag k="source" v="%s"/>
  </relation>
EOF
    my $osm = sprintf($format , $self->{relation_id}, xml_escape($iti->{name}), $ref, $self->{network}, $self->{operator}, $ref, $iti->{bgcolor}, $iti->{color}, $self->{source});
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'create');
  }
}
sub ksma_route_master_diff {
  my $self = shift;
  warn "ksma_route_master_diff() debut";
  my $id = $self->{id};
  my $ref = $self->{tags}->{ref};
  if ( not defined $self->{masters}->{$ref} ) {
    warn "ref:$ref";
    return;
  }

  my $name = $self->{masters}->{$ref}->{name};
  my $tags;
  $tags->{text_color} =  $self->{masters}->{$ref}->{color};
  $tags->{colour} =  $self->{masters}->{$ref}->{bgcolor};
  my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $id));
  $tags->{description} = xml_escape($name);
  $tags->{name} = xml_escape("Bus Saint-Malo Ligne $ref");
#  $tags->{"ref:ksma"} = "$ref-AR";
  my $osm = $self->{oOSM}->modify_tags($relation_osm, $tags, qw(name description text_color colour));
  $osm =~ s{<member type="node" ref="(\d+)" role="[^"]*"/>}{<member type="node" ref="$1" role="platform"/>}gsm;
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' modification tags', 'modify');
  warn "ksma_route_master_diff() fin";
}
#

sub ksma_network_diff {
  my $self = shift;
  warn "ksma_network_diff() debut";
  $self->{relation_id}--;
#  warn Dumper $iti;
  my $format = <<'EOF';
  <relation id="%s" timestamp="0" changeset="1" version="1">
    <tag k="network" v="%s"/>
    <tag k="public_transport" v="network"/>
    <tag k="type" v="network"/>
     <tag k="source" v="%s"/>
  </relation>
EOF
  my $osm = sprintf($format, $self->{relation_id}, $self->{network}, $self->{source});
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'create');
}



1;