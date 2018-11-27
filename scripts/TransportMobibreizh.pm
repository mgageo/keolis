# <!-- coding: utf-8 -->
#
# les informations de Mobibreizh
#http://www.breizhgo.com/
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
#
#
sub mobibreizh {
  my $self = shift;
  $self->mobibreizh_platform_oapi();
  $self->mobibreizh_platform_get();
  $self->mobibreizh_parse();
  $self->mobibreizh_stops_geojson();
  $self->mobibreizh_platforms_stops();
}
#
# les noeuds platform versus les stops
sub mobibreizh_platforms_stops {
  my $self = shift;
  $self->mobibreizh_platform_lit();
  $self->mobibreizh_stop_lit();
  foreach my $n (keys %{$self->{platform}} ) {
    my $node = $self->{platform}->{$n};
#    confess Dumper $node;
    $self->mobibreizh_platform_stops($node);
  }
}
#
# un noeud platform versus les stops
sub mobibreizh_platform_stops {
  my $self = shift;
  my $node = shift;
  my $distance = 500000;
  my $s1;
  foreach my $s (keys %{$self->{stop_point}} ) {
    my $stop = $self->{stop_point}->{$s};
#    confess Dumper $stop;
    my $d = haversine_distance_meters($node->{lat}, $node->{lon}, $stop->{lat}, $stop->{lon});
    if ( $d < $distance ) {
      $distance = $d;
      $s1 = $stop;
    }
  }
  if ( $distance > 30 ) {
    warn "$distance n$node->{id} $node->{tags}->{name} $s1->{name}";
  }
}
#
# conversion en geojson
sub mobibreizh_stops_geojson {
  my $self = shift;
  $self->mobibreizh_stop_lit();
  my $geojson = <<EOF;
{ "type": "FeatureCollection",
"features": [
EOF
  my $geojson_format = <<EOF;
{ "type": "Feature",
  "geometry": { "type": "Point", "coordinates": [ %s, %s ] },
  "properties": { "name": "%s" }
},
EOF

  foreach my $s (keys %{$self->{stop_point}} ) {
    my $stop = $self->{stop_point}->{$s};
#    confess Dumper $stop;
    $geojson .= sprintf($geojson_format, $stop->{lon}, $stop->{lat}, $stop->{name});

  }
  $geojson =~ s{,\s*$}{};
  $geojson .= <<EOF;
]
}
EOF
  my $dsn = "$self->{cfgDir}/stop.geojson";
  open(TXT, '>:utf8', $dsn);
  print TXT  $geojson;
  close(TXT);
  warn("dsn: ", $dsn);
  $dsn = "d:/web/leaflet/exemples/stop.geojson";
  open(TXT, '>:utf8', $dsn);
  print TXT  $geojson;
  close(TXT);
  warn("dsn: ", $dsn);
}
#
# les noeuds platform
sub mobibreizh_platform_oapi {
  my $self = shift;
  use Storable;
  warn "mobibreihz_platform_oapi() debut";
  my $hash = $self->oapi_get("node[network='FR:Réseau MAT'][public_transport=platform];out meta;", "$self->{cfgDir}/mobibreihz_platform.osm");
  foreach my $node (@{$hash->{node}}) {
    $self->{platform}->{$node->{id}} = $node;
  }
  my $dsn = "$self->{cfgDir}/platform.dmp";
  store( $self->{platform}, $dsn );
  warn "nb: " . scalar(keys %{$self->{platform}})
}
#
# lecture du fichier des platform
sub mobibreizh_platform_lit {
  my $self = shift;
  use Storable;
  warn "mobibreihz_platform_lit() debut";
  my $dsn = "$self->{cfgDir}/platform.dmp";
  $self->{platform} = retrieve($dsn);
  warn "nb: " . scalar(keys %{$self->{platform}})
}
#
# pour récupérer les arrêts sur le site
sub mobibreizh_platform_get {
  my $self = shift;
  warn "mobibreihz_platform_get() debut";
  $self->mobibreizh_platform_lit();
  foreach my $n (keys %{$self->{platform}} ) {
    my $node = $self->{platform}->{$n};
    $self->mobibreizh_get_node($node);
  }
}
#
# les arrêts autour d'un node osm
sub mobibreizh_get_node {
  my $self = shift;
  warn "mobibreihz_get_node() debut";
  my ($node) = @_;
#  confess Dumper $node;
  my $url = 'http://www.breizhgo.com/fr/proximity/result/?proximity_search[uri][autocomplete-hidden]=' . $node->{lon} . '%3B' . $node->{lat} . '&proximity_search[distance]=400';
  warn $url;
  my $dsn = "$self->{cfgDir}/MOBIBREIZH/". $node->{id} . '.html';
  mirror($url, $dsn)
}
# les arrêts autour d'un stop gtfs
sub mobibreizh_get_stop {
  my $self = shift;
  warn "mobibreihz_get_stop() debut";
  my ($stop) = @_;
#  confess Dumper $node;
  my $url = 'http://www.breizhgo.com/fr/proximity/result/?proximity_search[uri][autocomplete-hidden]=' . $stop->{stop_lon} . '%3B' . $stop->{stop_lat} . '&proximity_search[distance]=400';
  warn $url;
  my $dsn = "$self->{cfgDir}/MOBIBREIZH/". $stop->{stop_id} . '.html';
  $dsn =~ s/\:/_/;
  mirror($url, $dsn)
}
#
# pour récupérer les arrêts dans les fichiers html
sub mobibreizh_parse {
  my $self = shift;
  use Storable;
  warn "mobibreihz_get() debut";
  my $dsn = "$self->{cfgDir}/MOBIBREIZH/";
  opendir(DIR, $dsn) or die "opendir(DIR, $dsn) erreur:$!";
	my @f = readdir(DIR);
	close(DIR);
  $self->{stop_point} = ();
	my @fic = grep(/\.html$/, @f);
  for my $fic ( @fic) {
    $self->mobibreizh_parse_node("$dsn/$fic");
  }
#  warn Dumper $self->{stop_point};
  my $dsn = "$self->{cfgDir}/mobibreizh.dmp";
  store( $self->{stop_point}, $dsn );
  warn "dsn: $dsn";
  warn "nb: " . scalar(keys %{$self->{stop_point}});
  return $self->{stop_point};
}
sub mobibreizh_stop_lit {
  my $self = shift;
  use Storable;
  my $dsn = "$self->{cfgDir}/mobibreizh.dmp";
  $self->{stop_point} = retrieve( $dsn );
  warn "nb: " . scalar(keys %{$self->{stop_point}});
  return $self->{stop_point};
}
sub mobibreizh_parse_node {
  use JSON qw( decode_json );
  my $self = shift;
  warn "mobibreihz_pase_node() debut";
  my ($file) = @_;
  open(FILE, '<', $file) or die " mobibreizh_pase_node() file : $file";
  my @lignes = <FILE>;
  close(FILE);
  my @data = grep(/ var data = /, @lignes);
#  warn $data[0];
  my $json = $data[0];
  $json =~ s{^\s+var data =\s+}{};
  $json =~ s{;$}{};
  my $decoded_json = decode_json( $json );
#  warn Dumper $decoded_json;
  my $places = $decoded_json->{'proximity.form.poi.group.stop'}->{'response'}[0]->{'places_nearby' };
#  warn Dumper $places;
  for my $place ( @{$places} ) {
#    confess Dumper $place;
#    printf("%s;%s;%s;%s\n", $place->{name}, $place->{id}, $place->{stop_point}->{coord}->{lon}, $place->{stop_point}->{coord}->{lat} );
    $self->{stop_point}->{$place->{id}} = $place->{stop_point}->{coord};
    $self->{stop_point}->{$place->{id}}->{name} = $place->{name};
  }
#  exit;
}
1;
