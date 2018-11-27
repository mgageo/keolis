# <!-- coding: utf-8 -->
#
# les informations du réseau de Quimper
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
use Storable qw(store retrieve);
#
#
# recherche de tous les stops
# perl scripts/keolis.pl reseau quimper quimper_stops_verifier
sub quimper_stops_verifier {
  my $self = shift;
  warn "quimper_stops_verifier()";;
  $self->{gtfs}->{dir} = "TRANSPORT/MOBIBREIZH";
  $self->{gtfs}->{agency_id} = "QUB";
#  my $routes = $self->gtfs_routeid_get();
#  confess Dumper $routes;
#  my $trips = $self->gtfs_tripid_get();
#  confess Dumper $trips;
#  my $stops = $self->gtfs_stop_time_id_get();
#  confess Dumper $trips;;
#  my $stops = $self->gtfs_stop_id_get();
#  confess Dumper $stops;
  $self->quimper_gtfs_mobibreizh_diff();
}
# récupération des stops gtfs sur mobibreizh
sub quimper_gtfs_mobibreizh_get {
  my $self = shift;
  warn " quimper_gtfs_mobibreizh_get";
  my $stops = $self->gtfs_stop_id_lire();
  mkdir($self->{exportDir} . '/MOBIBREIZH');
  for my $s ( keys(%$stops) ) {
    my $stop = $stops->{$s};
#    $self->mobibreizh_get_stop($stop);
  }
  my $mobi = $self->mobibreizh_parse();
#  confess Dumper $mobi;
}
# différence des stops gtfs mobibreizh
sub quimper_gtfs_mobibreizh_diff {
  my $self = shift;
  warn "quimper_gtfs_mobibreizh_diff";
  my $mobi = $self->mobibreizh_stop_lit();
  my $gtfs = $self->gtfs_stop_id_lire();
  my $stops;
# on indexe le gtfs
  for my $s ( keys(%$gtfs) ) {
    my $stop = $gtfs->{$s};
#    confess Dumper $stop;
    my $id = $stop->{stop_id};
    $id =~ s{.*\:QUI}{};
    $stops->{$id}->{gtfs} = $stop;
  }
# on indexe mobibreizh
  for my $s ( keys(%$mobi) ) {
    my $stop = $mobi->{$s};
#    confess $s;
    my $id = $s;
    $id =~ s{.*\:}{};
    $stops->{$id}->{mobi} = $stop;
  }
  confess Dumper $stops;
}
# différence des stops gtfs mobibreizh
sub quimper_gtfs_osm_diff {
  my $self = shift;
  warn "quimper_gtfs_osm_diff";
  my $hash = $self->busstop_reseau_get();
  my $gtfs = $self->gtfs_stop_id_lire();
  foreach my $node ( @{$hash->{node}}) {
    my $tags = $node->{tags};
    if ( defined $tags->{public_transport} && $tags->{public_transport} eq 'stop_position') {
      next;
    }
# on parcours le gtfs pour trouver le plus proche
    my $distance = 500000;
    my $s1;
    for my $s ( keys(%$gtfs)) {
      my $stop = $gtfs->{$s};
      my $d = haversine_distance_meters($node->{lat}, $node->{lon}, $stop->{stop_lat}, $stop->{stop_lon});
      if ( $d < $distance ) {
        $distance = $d;
        $s1 = $s;
      }
    }
#    warn Dumper $tags;
#    warn Dumper $s1;
#    warn "distance:$distance";
#    printf("%4d % 30s % 30s\n", $distance, $gtfs->{$s1}->{stop_name}, $tags->{name});
    $node->{stop_id} = $s1;
    $node->{distance} = $distance;
    $gtfs->{$s1}->{osm}++;
  }
#  confess Dumper $hash->{node};
  my $ko = 0;
  my $t = {
    'highway' => 'bus_stop',
    'bus' => 'yes',
    'public_transport' => 'platform',
  };
  my $osm;
  foreach my $node ( @{$hash->{node}}) {
    my $tags = $node->{tags};
    if ( defined $tags->{public_transport} && $tags->{public_transport} eq 'stop_position') {
      next;
    }
    if ( $tags->{name} !~ m{^\s*$} ) {
      next;
    }
    my $s1 = $node->{stop_id};
    my $stop = $gtfs->{$s1};
    printf("***\n");
    warn Dumper $stop;
    warn Dumper $node;
    $ko++;
    my $node_osm = get(sprintf("https://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{id}));
    $s1 =~ s{.*\:QUI}{};
    $t->{'ref:QUB'} = $s1;
    $t->{'name'} = $stop->{stop_name};
    $osm .= $self->{oOSM}->modify_tags($node_osm, $t, keys(%$t)) . "\n";
#    last;
  }
  warn "quimper_gtfs_osm_diff() ko: $ko";
  if ( $osm ne '' ) {
#    $self->{oAPI}->changeset($osm, "ajout nom source gtfs", 'modify');
  }
  my $osm;
  foreach my $node ( @{$hash->{node}}) {
    my $tags = $node->{tags};
    if ( defined $tags->{public_transport} && $tags->{public_transport} eq 'stop_position') {
      next;
    }
    if ( $tags->{'ref:QUB'} !~ m{^\s*$} ) {
      next;
    }
    my $s1 = $node->{stop_id};
    my $stop = $gtfs->{$s1};
    if ( $stop->{osm} > 1 ) {
      next;
    }
    $ko++;
    my $node_osm = get(sprintf("https://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{id}));
    $s1 =~ s{.*\:QUI}{};
    $t->{'ref:QUB'} = $s1;
    $osm .= $self->{oOSM}->modify_tags($node_osm, $t, keys(%$t)) . "\n";
#    last;
  }
  warn "quimper_gtfs_osm_diff() ko: $ko";
  if ( $osm ne '' ) {
    $self->{oAPI}->changeset($osm, "ajout nom source gtfs", 'modify');
  }
  my $gpx = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.0" creator="mga" xmlns="http://www.topografix.com/GPX/1/0">
EOF

  for my $s ( keys(%$gtfs)) {
    my $stop = $gtfs->{$s};
    if ( ! defined $stop->{osm} ) {
#      next;
    }
    if ( $stop->{osm} == 1 ) {
#      next;
    }
    $gpx .= sprintf("\n  <wpt lat='%s' lon='%s'><name>%s %s</name></wpt>", $stop->{stop_lat}, $stop->{stop_lon}, $stop->{stop_name}, $stop->{osm});
  }
  $gpx .= <<EOF;

</gpx>
EOF
#  warn $gpx;
  my $dsn = "$self->{cfgDir}/quimper_gtfs_osm_diff.gpx";
  open(GPX, "> :utf8", $dsn) or die;
  print GPX $gpx;
  close(GPX);
  warn "quimper_gtfs_osm_diff() $dsn";
}
# perl scripts/keolis.pl reseau quimper quimper_routes_clean
sub quimper_routes_clean {
  my $self = shift;
  warn "quimper_routes_clean()";
  my $hash = $self->oapi_get("area[name='Bretagne'];relation[network='$self->{network}'][type=route][route=bus](area);out meta;", "$self->{cfgDir}/quimper_routes_clean.osm");
  my $get = "relation[network='$self->{network}'][type=route][route=bus];out meta;";
  foreach my $relation (@{$hash->{relation}}) {
    warn "ref: " . $relation->{tags}->{ref};
    $self->quimper_route_clean($relation->{id});
  }
}
sub quimper_route_clean {
  my $self = shift;
  warn "quimper_route_clean()";
  my $id = shift;
  my $osm = get(sprintf("https://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $id));
  my $osm1 = $osm;
  $osm =~ s{forward_}{}g;
  $osm =~ s{backward_}{}g;
  $osm =~ s{"foo?rr?ward"}{""}g;
  $osm =~ s{"backward"}{""}g;
  $osm =~ s{colour_1}{text_colour}g;
  $osm =~ s{<tag k="public_transport" v="v2"/>}{<tag k="public_transport:version" v="2"/>}g;
  if ( $osm eq $osm1 ) {
    warn "quimper_route_clean() ok: $id";
    return;
  }
#  warn $osm;
  $osm =~ s{.*<(node|way|relation)}{<$1}sm;
  $osm =~ s{</(node|way|relation)>.*}{</$1>}sm;
  $self->{oAPI}->changeset($osm, "modifications pour conversion en pt2", 'modify');
}
#
# recherche de tous les stops d'une route
sub quimper_route_stops_creer {
  my $self = shift;
  warn "route_id: " . $self->{gtfs}->{route_id};
  $self->gtfs_stops_get();
#  confess Dumper $self->gtfs_stops_lire();
#  $self->gtfs_stops_create();
}
1;
