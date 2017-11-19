# <!-- coding: utf-8 -->
#
#
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
use English;
use XML::Simple;
#
# récupération des données OSM
# ============================

sub osm_get {
  my $self = shift;
  my ($get, $f_osm) = @_;
  if ( ! $f_osm ) {
    confess "osm_get() f:$f_osm";
  }
  my ($osm);
#  $f_osm = "$self->{cfgDir}/relations_routes.osm";
  if ( ! -f "$f_osm" or  $self->{DEBUG_GET} > 0 ) {
    $osm = $self->{oOAPI}->get($get);
    open(OSM, ">",  $f_osm) or die "osm_get() erreur:$!";
    print(OSM $osm);
    close(OSM);
  } else {
    $osm = do { open my $fh, '<', $f_osm or die $!; local $/; <$fh> };
  }
#  confess $osm;
  my $hash = osm2hash($osm);
  warn "osm_get() $f_osm nb_r:" . scalar(@{$hash->{relation}}) . " nb_w:" . scalar(@{$hash->{way}}) . " nb_n:" . scalar(@{$hash->{node}});
  return $hash;
}
#
# récupération des relations type=route et mise en hash
sub osm_route_get {
  my $self = shift;
  my $ref = shift;
  my ($osm, $f_osm);
  $f_osm = $self->{cfgDir}. "/relation_route_${ref}.osm";
  $osm = "(relation[network=fr_star][type=route][route=bus][ref=${ref}];>>);out meta;";
  return $self->osm_get($osm, $f_osm);
}
#
# récupération des relations type=route_master et mise en hash
sub osm_route_master_get {
  my $self = shift;
  my ($osm, $f_osm);
  $f_osm = "$self->{cfgDir}/relations_route_master.osm";
  $osm = "relation[network=fr_star][route_master=bus];out meta;";
  return $self->osm_get($osm, $f_osm);
}
#
# récupération des nodes highway=bus_stop mise en hash type osm
sub osm_relations_stop_area_get {
  my $self = shift;
  my ($osm, $f_osm);
  $f_osm = "$self->{cfgDir}/relations_stop_area.osm";
  $osm = "relation[network=fr_star][type=public_transport][public_transport=stop_area];out meta;";
  return $self->osm_get($osm, $f_osm);
}
#
# récupération des nodes highway=bus_stop mise en hash type osm
sub osm_nodes_bus_stop_get {
  my $self = shift;
  my ($osm, $f_osm);
  $f_osm = "$self->{cfgDir}/nodes_bus_stop.osm";
  $osm = "node(area:3602005861);node(around:1000)[highway=bus_stop];out meta;";
  return $self->osm_get($osm, $f_osm);
}
#
# récupération des nodes highway=bus_stop hors route=bus mise en hash type osm
sub osm_nodes_bus_stop_hors_get {
  my $self = shift;
  my ($osm, $f_osm);
  $f_osm = "$self->{cfgDir}/nodes_bus_stop_hors.osm";
  $osm = "node(area:3602005861);node(around:1000)[highway=bus_stop]->.all;relation[network=fr_star][route=bus](bn.all);node(r);( .all; - ._; );out meta;";
  return $self->osm_get($osm, $f_osm);
}
#
# récupération des nodes highway=bus_stop mise en hash type name/ref
sub osm_nodes_bus_stop_hash {
  my $self = shift;
  warn "osm_nodes_bus_stop_hash()";
  my $hash = $self->osm_nodes_bus_stop_get();

  warn "osm_nodes_bus_stop_hash() indexation osm";
  my ($stops, $names, $names_norm);
  foreach my $node (sort @{$hash->{node}} ) {
    my $name = '';
    my $name_norm = '';
    my $ref = '';
    if ( not defined $node->{tags}->{name} ) {
      if ( $self->{DEBUG} > 1 ) {
        warn "osm_nodes_bus_stop_hash() indexation osm ref pas de name";
      }
 #     warn Dumper $node;
      next;
    }
    $name = $node->{tags}->{name};
    $name_norm = name_norm($name);;
    if ( defined $node->{tags}->{ref} ) {
      $ref =  $node->{tags}->{ref};
      if ( $ref !~ m{^\d+$} ) {
        if ( $self->{DEBUG} > 1 ) {
          warn "osm_nodes_bus_stop_hash() indexation osm ref non numérique";
        }
#        warn Dumper $node;
        next;
      }
      push @{$stops->{$ref}->{osm}}, $node;
    }
    push @{$names->{$name}->{osm}}, $node;
    push @{$names_norm->{$name_norm}->{osm}}, $node;
  }
  warn "osm_nodes_bus_stop_hash() indexation nb names: " . scalar(keys %{$names});
  warn "osm_nodes_bus_stop_hash() indexation nb names_norm: " . scalar(keys %{$names_norm});
  warn "osm_nodes_bus_stop_hash() indexation nb ref: " . scalar(keys %{$stops});
  return $stops;
}
our ( $osm_nodes_bus_stop_refs );
sub osm_nodes_bus_stop_ref {
  my $self = shift;
  my $ref = shift;
  if ( not defined $osm_nodes_bus_stop_refs ) {
    $osm_nodes_bus_stop_refs = $self->osm_nodes_bus_stop_hash();
  }
  if ( not defined $osm_nodes_bus_stop_refs->{$ref} ) {
    confess "osm_nodes_bus_stop_ref() *** ref:$ref";
  }
  if ( $self->{DEBUG} > 1 ) {
    warn Dumper $osm_nodes_bus_stop_refs->{$ref}->{osm};
  }
  return  $osm_nodes_bus_stop_refs->{$ref}->{osm}[0];
}
#
# transformation de la réponse osm en hash
sub osm2hash {
  my $osm = shift;
#  confess $osm;
  my $hash = XMLin(
    $osm,
    ForceArray    => 1,
    KeyAttr       => [],
    SuppressEmpty => ''
  );
#  warn Dumper($hash);
  foreach my $relation (@{$hash->{relation}}) {
#    confess Dumper $relation;
    foreach my $tag (@{$relation->{tag}}) {
#     confess Dumper $tag;
      $relation->{tags}->{$tag->{k}} = $tag->{v};
    }
    delete $relation->{tag};
#	confess Dumper $relation->{tags};
#	last;
  }
  foreach my $node (@{$hash->{node}}) {
    foreach my $tag (@{$node->{tag}}) {
      $node->{tags}->{$tag->{k}} = $tag->{v};
    }
    delete $node->{tag};
  }
  foreach my $way (@{$hash->{way}}) {
    foreach my $tag (@{$way->{tag}}) {
      $way->{tags}->{$tag->{k}} = $tag->{v};
    }
    foreach my $nd (@{$way->{nd}}) {
      push @{$way->{nodes}}, $nd->{ref};
    }
    delete $way->{tag};
    delete $way->{nd};
  }
  return $hash;
}
#
# recherche d'un node dans le hash
sub find_node {
  my $id = shift;
  my $hash = shift;
  for my $node ( @{$hash->{node}} ) {
    if ( $id eq $node->{id} ) {
      return $node;
    }
  }
  return undef;
}
sub find_relation {
  my $id = shift;
  my $hash = shift;
  for my $relation ( @{$hash->{relation}} ) {
    if ( $id eq $relation->{id} ) {
      return $relation;
    }
  }
  return undef;
}
sub find_way {
  my $id = shift;
  my $hash = shift;
  for my $way ( @{$hash->{way}} ) {
    if ( $id eq $way->{id} ) {
      return $way;
    }
  }
  return undef;
}

sub get_relation_tag_ref {
  my $hash = shift;
  my $ref = shift;
  my @relations = ();
  foreach my $relation ( @{$hash->{relation}}) {
    if (  $relation->{tags}->{ref} eq $ref ) {
      push @relations, $relation;
    }
  }
  return @relations;
}
sub display_relation_route_member_node {
  my $relation = shift;
  my @nodes = get_relation_route_member_node($relation);
  warn sprintf("\n%s;%s;%s", $relation->{id},$relation->{user}, $relation->{timestamp});
  warn "display_relation_route_member_node ". join(",", @nodes);
  return @nodes;
}
#
# calcul de la distance entre 2 points en mètre
sub haversine_distance_meters {
  my $O = 3.141592654/180 ;
  my $lat1 = shift(@_) * $O;
  my $lon1 = shift(@_) * $O;
  my $lat2 = shift(@_) * $O;
  my $lon2 = shift(@_) * $O;
  my $dlat = $lat1 - $lat2;
  my $dlon = $lon1 - $lon2;
  my $f = 2 * &asin( sqrt( (sin($dlat/2) ** 2) + cos($lat1) * cos($lat2) * (sin($dlon/2) ** 2)));
  return sprintf("%d",$f * 6378137) ; 		# Return meters
  sub asin {
   atan2($_[0], sqrt(1 - $_[0] * $_[0])) ;
  }
}
sub test_haversine_distance_meters {
  warn haversine_distance_meters(48.09062505, -1.69500771, 48.09053717, -1.69493887);
}
# pour trier dans un ordre naturel la référence de la ligne
sub tri_ref {
  my $aa = $a;
  my $bb = $b;
  my ($an) = $aa =~ /^(\d+)/;
  my ($bn) = $bb =~ /^(\d+)/;
  if ( $an && $bn ) {
    $an <=> $bn;
  } else {
    $aa cmp $bb;
  }
}
sub tri_tags_ref {
  my $aa = $a->{tags}->{ref};
  my $bb = $b->{tags}->{ref};
  my ($an) = $aa =~ /^(\d+)/;
  my ($bn) = $bb =~ /^(\d+)/;
  if ( $an && $bn ) {
    $an <=> $bn;
  } else {
    $aa cmp $bb;
  }
}
1;