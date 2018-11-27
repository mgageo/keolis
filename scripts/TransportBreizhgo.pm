# <!-- coding: utf-8 -->
#
# les informations du Réseau Breizhgo
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
use Storable qw(store retrieve);
#
# pour créer une relation "route_master" pour ce réseau
sub breizhgo_route_master_creer {
  my $self = shift;

my $lignes =<<EOF;
# LRRNav1;Pontivy <> Rennes
LRRNav4;Saint-Brieuc <> Loudéac <> Pontivy <> Vannes/Lorient
EOF
  my @lignes = split(/\n/, $lignes);
#  confess Dumper \@lignes;
  my $osm_routes = '';
  for my $ligne ( @lignes ) {
    my ($ref, $nomlong) = split(/;/, $ligne);
#  confess Dumper  $lignes->{$self->{ref}};
    $self->{relation_id}--;
    my $osm = sprintf('
  <relation id="%s" version="1"  changeset="1">
    <tag k="route_master" v="bus"/>
    <tag k="service" v="busway"/>
    <tag k="type" v="route_master"/>
  </relation>' , $self->{relation_id});
    my $tags;
    $tags->{network} = $self->{network};
    $tags->{"public_transport:version"} =  "2";
    $tags->{description} = xml_escape($nomlong);
    $tags->{name} =   $self->{reseau_ligne}. " " . xml_escape($nomlong);
    $tags->{ref} =   $ref;
    $osm = $self->{oOSM}->modify_tags($osm, $tags, keys %{$tags}) . "\n";
    $osm_routes .= $osm;
  }
  $self->{oAPI}->changeset($osm_routes, $self->{osm_commentaire}, 'create');
}
#
# recherche de tous les stops d'une route
sub breizhgo_route_creer {
  my $self = shift;
  $self->{gtfs}->{route_id} = 'LRRNav1';
#  $self->breizhgo_route_stops_creer();
  $self->breizhgo_route_trips_creer();
}
#
# recherche de tous les stops d'une route
sub breizhgo_route_stops_creer {
  my $self = shift;
  warn "route_id: " . $self->{gtfs}->{route_id};
  $self->gtfs_stops_get();
#  confess Dumper $self->gtfs_stops_lire();
  $self->gtfs_stops_create();
}
#
# recherche de tous les trips d'une route
# perl scripts/keolis.pl breizhgo breizhgo_route_trips_creer
sub breizhgo_route_trips_creer {
  my $self = shift;
  warn "route_id: " . $self->{gtfs}->{route_id};
  my $trips = $self->gtfs_trips_stops_lire();
  $self->{stops} = $self->busstop_index_ref_lire();
#  confess Dumper $trips;
  my ($directions, $deparr);
  for my $t (keys %$trips) {
    my $trip = $trips->{$t};
    if ( $trip->{route_id} ne  $self->{gtfs}->{route_id} ) {
      confess Dumper $trip;
    }
    my $nb = $trip->{nb_stops};
    my $depart = $trip->{0}->{stop_id};
    my $arrivee = $trip->{$nb-1}->{stop_id};
    my $da = sprintf("%s %s/%s", $trip->{direction_id}, $depart, $arrivee);
#    $self->breizhgo_trip_level0($trip);
#    printf(" 20%s %s %02d\n", $t, $trip->{direction_id}, $trip->{nb_stops});
    if ( $trip->{nb_stops} >  $directions->{$trip->{direction_id}}->{nb} ) {
      $directions->{$trip->{direction_id}}->{nb} = $trip->{nb_stops};
      $directions->{$trip->{direction_id}}->{trip} = $trip;
    }
    if ( $trip->{nb_stops} >  $deparr->{$da}->{nb} ) {
      $deparr->{$da}->{nb} = $trip->{nb_stops};
      $deparr->{$da}->{trip} = $trip;
    }
  }
#  confess Dumper $stops;
  for my $d (sort keys %$directions) {
    next;
    warn $d;
    my $trip = $directions->{$d}->{trip};
    $self->breizhgo_trip_level0($trip);
  }
  for my $d (sort keys %$deparr) {
    printf("$d\n");
    my $trip = $deparr->{$d}->{trip};
    $self->breizhgo_trip_level0($trip);
  }
}
sub breizhgo_trip_level0 {
  my $self = shift;
  my $trip = shift;
#    confess Dumper $trip;
  my $nb = $trip->{nb_stops};
  my $level0 = '';
  my $arrets = $trip->{direction_id} . ' ';
  my $stops = $self->{stops};
  for (my $i=0; $i < $nb; $i++) {
    my $stop_id = $trip->{$i}->{stop_id};
    $arrets .= $stops->{$stop_id}->{tags}->{name} . ", ";
    $level0 .= sprintf("  nd %s platform\n", $stops->{$stop_id}->{id});
  }
  print $arrets . "\n";
  print $level0;
}
1;
