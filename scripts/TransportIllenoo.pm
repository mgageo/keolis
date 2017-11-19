# <!-- coding: utf-8 -->
#
# les traitements sur les données Illenoo récupérées en wfs
#
#
package Transport;
use utf8;
use strict;
#
# les données Illenoo
# ===================
#
#
# récupération d'une table
sub table_get {
  my $self = shift;
  my $table = shift;
  $self->{oDB}->table_select($table);
  warn "table_get() nb:".scalar(@{$self->{oDB}->{table}->{$table}});
  return $self->{oDB}->{table}->{$table};
}
# récupération des routes avec indexation par id
sub illenoo_routes_get {
  my $self = shift;
  my $table = 'illenoo_parcours';
  $self->{oDB}->table_select($table);
#  confess Dumper $self->{oDB}->{table}->{routes};
  my $routes;
  for my $route ( @{$self->{oDB}->{table}->{$table}} ) {
    $routes->{$route->{id}} = $route;
  }
#  confess Dumper $routes;
  warn "illenoo_routes_get() nb:".scalar(keys %{$routes});
  return $routes;
}
# récupération des stops avec indexation par id
sub illenoo_stops_get {
  my $self = shift;
  my $table = 'arrets_physiques_illenoo_cg35';
  $self->{oDB}->table_select($table);
#  confess Dumper $self->{oDB}->{table}->{stops};
  my $stops;
  for my $stop ( @{$self->{oDB}->{table}->{$table}} ) {
#    confess Dumper $stop;
    $stops->{$stop->{ID}} = $stop;
  }
#  confess Dumper $stops;
  warn "illenoo_stops_get() nb:".scalar(keys %{$stops});
  return $stops;
}
#
# la partie wfs
# pour les arrêts
sub illenoo_stops_diff {
  my $self = shift;
  warn "illenoo_stops_diff() début";
  my $illenoo_stops = $self->illenoo_stops_get();
  my $tag_ref = $self->{k_ref};
  my $osm_stops = $self->oapi_get("node['highway'='bus_stop']['${tag_ref}'];out meta;", "$self->{cfgDir}/illenoo_stops_diff.osm");
  my $hash_35 = $self->{oOAPI}->osm_get("area[name='Ille-et-Vilaine'];node(area)['highway'='bus_stop'];out meta;", "$self->{cfgDir}/bus_stop_35.osm");
  my ($stops, $names);
  my $level0;
#
# on indexe par ref et par name
# =============================
#
# les stops du fichier ad-hoc
  for my $stop ( keys %{$illenoo_stops} ) {
    if ( defined $stops->{$stop}->{illenoo} ) {
      warn "*** doublon illenoo";
    }
    $stops->{$stop}->{illenoo} = $illenoo_stops->{$stop};
    my $name = $illenoo_stops->{$stop}->{NAME};
    $names->{$name}->{illenoo}->{$stop} = $illenoo_stops->{$stop};
  }
  foreach my $node ( @{$osm_stops->{node}} ) {
    if ( not defined $node->{tags}->{name} ) {
      if ( $self->{DEBUG} > 1 ) {
        warn "illenoo_stops_diff() indexation pas de name";
        warn Dumper $node;
      }
      next;
    }
    my $name = $node->{tags}->{'name'};
    $names->{$name}->{osm}->{$node->{id}} = $node;
    if ( defined $stops->{$node->{tags}->{${tag_ref}}}->{osm} ) {
      warn "*** doublon osm";
      warn Dumper $stops->{$node->{tags}->{${tag_ref}}} ;
      warn Dumper $node;
      my $node1 = $stops->{$node->{tags}->{${tag_ref}}}->{osm};
      my $stop = $stops->{$node->{tags}->{${tag_ref}}}->{illenoo};
      my $d_osm = haversine_distance_meters($node->{lat}, $node->{lon}, $node1->{lat}, $node1->{lon});
      my $d_stop = haversine_distance_meters($node->{lat}, $node->{lon}, $stop->{Y_WGS84}, $stop->{X_WGS84});
      my $d_stop1 = haversine_distance_meters($node1->{lat}, $node1->{lon}, $stop->{Y_WGS84}, $stop->{X_WGS84});
      warn "distance:$d_osm $d_stop $d_stop1";
      my $id = $node->{id};
      if ( $node1->{id} > $id ) {
        $id = $node1->{id};
      }
      $level0 .= "n$id,";
    }
    $stops->{$node->{tags}->{${tag_ref}}}->{osm} = $node;
  }
  chomp $level0;
  warn "level0: $level0";
  my $absent_osm = 0;
  my $absent_illenoo = 0;
  my $nb_distance = 0;
  $level0 = '';
  my $format = <<EOF;
  <node id="%s" lat="%s" lon="%s" version="1" timestamp="0" changeset="1">
    <tag k="highway" v="bus_stop"/>
    <tag k="public_transport" v="platform"/>
    <tag k="name" v="%s"/>
    <tag k="${tag_ref}" v="%s"/>
    <tag k="source" v="%s"/>
  </node>
EOF
  my $osm_create = '';
  my $osm_modify = '';
  my $osm_latlon = '';
  my $osm_name = '';
  my @deleted_keys = qw(fr:illenoo);
  my $deleted_keys = join('|', @deleted_keys);
  for my $stop ( sort keys %{$stops} ) {

    if ( not defined $stops->{$stop}->{illenoo} ) {
#      warn "absent de illenoo" . Dumper $stops->{$stop};
      $absent_illenoo++;
      $level0 .= "n" .  $stops->{$stop}->{osm}->{id} . ",";
      next;
    }
    if ( not defined $stops->{$stop}->{osm} ) {
      $absent_osm++;
      my $illenoo =  $stops->{$stop}->{illenoo};
# un noeud proche ?
      for my $osm ( @{$hash_35->{node}} ) {
        my $distance =  haversine_distance_meters($osm->{lat}, $osm->{lon}, $illenoo->{Y_WGS84}, $illenoo->{X_WGS84});
        if ( $distance < 1 ) {
          warn "absent de osm" . Dumper $stops->{$stop};
          warn "*** distance:$distance";
          warn Dumper $osm;
          my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $osm->{id}));
          my $tags = {
            source => $self->{source},
            'ref:fr_illenoo' => $illenoo->{'ID'},
          };
          $node_osm = $self->{oOSM}->delete_tags($node_osm, $deleted_keys);
          $osm_modify .= $self->{oOSM}->modify_tags($node_osm, $tags, qw(ref:fr_illenoo source)) . "\n";
        }
      }
      my $opendata =  $stops->{$stop}->{illenoo};
      $osm_create .= sprintf($format, $self->{node_id}, $opendata->{Y_WGS84}, $opendata->{X_WGS84}, $opendata->{NOM}, $opendata->{ID}, $self->{source});
      $self->{node_id}--;
      next;
    }
# la référence est présente dans les deux
    if ( defined $stops->{$stop}->{illenoo} && defined $stops->{$stop}->{osm} ) {
      my $illenoo =  $stops->{$stop}->{illenoo};
      my $osm =  $stops->{$stop}->{osm};
#      confess Dumper $illenoo;
      if ( $illenoo->{NOM} ne $osm->{tags}->{name} ) {
        warn "$stop ***name " . $illenoo->{NOM} . " # " . $osm->{tags}->{name};
        warn Dumper $osm;
      }
      next;
    }

    my $osm =  $stops->{$stop}->{osm};
    my $illenoo =  $stops->{$stop}->{illenoo};
    my $distance =  haversine_distance_meters($osm->{lat}, $osm->{lon}, $illenoo->{Y_WGS84}, $illenoo->{X_WGS84});
    if ( $distance > 100 ) {
      warn "distance : $distance\n" . Dumper  $stops->{$stop};
      $nb_distance++;
      my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $osm->{id}));
      $osm_latlon .= $self->{oOSM}->modify_latlon($node_osm, $illenoo->{Y_WGS84}, $illenoo->{X_WGS84}) . "\n";
    }
  }
  warn "absent_illenoo $absent_illenoo absent_osm $absent_osm nb_distance $nb_distance";
  warn "level0: $level0";
#  confess Dumper $stops;
#  $self->{oAPI}->changeset($osm_create, $self->{osm_commentaire}, 'create');
#  $self->{oAPI}->changeset($osm_modify, $self->{osm_commentaire}, 'modify');
  $self->{oAPI}->changeset($osm_latlon, $self->{osm_commentaire}, 'modify');
  warn "illenoo_stops_diff() fin";
}
#
#
# pour les arrêts faisant partie d'une way
sub opendata_stops_way {
  my $self = shift;
  warn "opendata_stops_diff() début";
  my $opendata_stops = $self->illenoo_stops_get();
  my $tag_ref = $self->{k_ref};
  my $osm_stops = $self->oapi_get("node['highway'='bus_stop']['${tag_ref}'];way(bn);>;out meta;", "$self->{cfgDir}/opendata_stops_way.osm");
  my $stops;

#
# les stops du fichier ad-hoc
  for my $stop ( keys %{$opendata_stops} ) {
    if ( defined $stops->{$stop}->{opendata} ) {
      warn "*** doublon opendata";
    }
    $stops->{$stop}->{opendata} = $opendata_stops->{$stop};
  }
# on indexe par ref
  my $format = <<EOF;
  <node id="%s" lat="%s" lon="%s" version="1" timestamp="0" changeset="1">
    <tag k="highway" v="bus_stop"/>
    <tag k="name" v="%s"/>
    <tag k="ref:illenoo" v="%s"/>
    <tag k="source" v="%s"/>
  </node>
EOF
  my $osm = '';
  my $level0;
  foreach my $node ( @{$osm_stops->{node}} ) {
    if ( not defined $node->{tags}->{${tag_ref}} ) {
      next;
    }
    if ( not defined $stops->{$node->{tags}->{${tag_ref}}}->{opendata} ) {
      confess;
    }
#    warn Dumper $node;
    my $opendata =  $stops->{$node->{tags}->{${tag_ref}}}->{opendata};
    $level0 .= "n$node->{id},";
    $osm .= sprintf($format, $self->{node_id}, $opendata->{Y_WGS84}, $opendata->{X_WGS84}, $opendata->{NOM}, $opendata->{ID}, $self->{source});
    $self->{node_id}--;
  }
  chomp $level0;
  warn "level0: $level0";
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'create');
  warn "opendata_stops_way() fin";
}
1;