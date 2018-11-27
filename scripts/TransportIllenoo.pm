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
sub illenoo_masters_verif {
  my $self = shift;
  warn "illenoo_masters_verif()";
  my $network = $self->{network};
  my $hash = $self->oapi_get("relation[network='${network}'][type=route_master];out meta;", "$self->{cfgDir}/relations_route_master.osm");
  my $masters = $self->gtfs_routes_get();
#  confess Dumper $masters;
  my $refs = {};
  for my $ref ( sort keys %{$masters} ) {
#    warn "ref:$ref";
    $refs->{$ref}->{gtfs} = $masters->{$ref}
  }
  my $k_ref = 'ref';
  foreach my $relation (sort @{$hash->{relation}} ) {
    if ( ! defined $refs->{$relation->{tags}->{ref}} ) {
      warn "illenoo_masters_verif() ***";
      next;
    }
    $refs->{$relation->{tags}->{ref}}->{osm} = $relation;
    $self->illenoo_master_verif($refs->{$relation->{tags}->{ref}});
  }
}
sub illenoo_master_verif {
  my $self = shift;
  warn "illenoo_master_verif()";
  my $hash = shift;
  my $tags;
  $tags->{network} = $self->{network};
  $tags->{"public_transport:version"} =  "2";
  $tags->{type} = 'route_master';
  $tags->{'route_master'} = 'bus';
  $tags->{'service'} = 'busway';
#  $tags->{description} = xml_escape($nomlong);
#  $tags->{name} = $self->{reseau_ligne}. " " . xml_escape($nomlong);
#  $tags->{ref} =  $ref;
  $tags->{text_colour} = '#' . uc($hash->{gtfs}->{route_text_color});
  $tags->{colour} = '#' . uc($hash->{gtfs}->{route_color});
  my @keys = keys %{$tags};
  my $osm = get(sprintf("https://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $hash->{osm}->{id}));
#
  $osm = $self->{oOSM}->modify_tags($osm, $tags, @keys);
#    warn $osm;
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');
}
sub illenoo_masters_txt_verif {
  my $self = shift;
  warn "illenoo_masters_txt_verif()";
  my $network = $self->{network};
  my $masters = $self->txt_masters_lire();
  for my $id (keys %{$masters} ) {
#    confess Dumper $refs->{$id};
    my $r = $masters->{$id};
    my $osm = get(sprintf("https://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $id));
#    confess $osm;
    delete $r->{'id'};
    $r->{name} = xml_escape($r->{name});
    $r->{description} = xml_escape($r->{description});
    $r->{type} = 'route_master';
    $r->{'route_master'} = 'bus';

    my @keys = keys %{$r};
    $osm = $self->{oOSM}->modify_tags($osm, $r, @keys);
#    warn $osm;
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');
  }
#  confess Dumper $refs;
}
#
# vérification des routes par rapport au gtfs
# perl scripts/keolis.pl --DEBUG 0 --DEBUG_GET 1 illenoo illenoo_routes_verif
sub illenoo_routes_verif {
  my $self = shift;
  warn "illenoo_routes_verif()";
  my $network = $self->{network};
  my $hash = $self->oapi_get("relation[network='${network}'][type=route];out meta;", "$self->{cfgDir}/relations_route.osm");
  my $routes = $self->gtfs_routes_get();
#  confess Dumper $routes;
  my $refs = {};
  for my $ref ( sort keys %{$routes} ) {
#    warn "ref:$ref";
    $refs->{$ref}->{gtfs} = $routes->{$ref}
  }
  my $k_ref = 'ref';
  foreach my $relation (sort @{$hash->{relation}} ) {
    if ( ! defined $refs->{$relation->{tags}->{ref}} ) {
      warn "illenoo_routes_verif() ***";
      next;
    }
    $refs->{$relation->{tags}->{ref}}->{osm} = $relation;
    $self->illenoo_route_verif($refs->{$relation->{tags}->{ref}});
  }
}
sub illenoo_route_verif {
  my $self = shift;
  warn "illenoo_route_verif()";
  my $hash = shift;
  my $tags;
  $tags->{network} = $self->{network};
  $tags->{"public_transport:version"} =  "2";
  $tags->{type} = 'route';
  $tags->{'route'} = 'bus';
  $tags->{'service'} = 'busway';
#  $tags->{description} = xml_escape($nomlong);
#  $tags->{name} = $self->{reseau_ligne}. " " . xml_escape($nomlong);
#  $tags->{ref} =  $ref;
  $tags->{text_colour} = '#' . uc($hash->{gtfs}->{route_text_color});
  $tags->{colour} = '#' . uc($hash->{gtfs}->{route_color});
  my @keys = keys %{$tags};
  my $osm = get(sprintf("https://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $hash->{osm}->{id}));
#
  $osm = $self->{oOSM}->modify_tags($osm, $tags, @keys);
#    warn $osm;
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');
}
#
# création du fichier texte
sub illenoo_routes_txt_ecrire {
  my $self = shift;
  warn "illenoo_routes_txt_ecrire()";
  my ($f_txt, $ligne, $masters);
  $f_txt = "$self->{cfgDir}/masters.txt";
  my $csv = 'id;ref;name;description;from;to';

  open(TXT, "< :utf8", $f_txt) or die;
  $ligne = <TXT>;
  while( my $ligne = <TXT>) {
    chomp($ligne);
    my ($id, $ref, $description, $colour, $text_colour) = split(";", $ligne);
#    $name =~ s{(\S)<}{$1 <}g;
#    warn "$ref => $name";
    $masters->{$ref} = {
      id => $id,
      ref => $ref,
      description => $description,
      colour => uc($colour),
      text_colour => uc($text_colour),
      name => sprintf("%s %s", $self->{reseau_ligne}, $ref)
    };
  }
  close(TXT);
  $f_txt = "$self->{cfgDir}/route_osm2txt.csv";
  open(TXT, "< :utf8", $f_txt) or die;
  $ligne = <TXT>;
  while( my $ligne = <TXT>) {
    chomp($ligne);
    warn $ligne;
    my ($id, $ref, $name, $description, $from, $to) = split(";", $ligne);
    $ref = lc($ref);
    if ( ! defined $masters->{$ref} ) {
      warn "***";
      next;
    }
#    warn Dumper $masters->{$ref};
    my $master =  $masters->{$ref};
    my @via = split(/ <> /, $master->{description});
    $from = $via[0];
    $to = $via[-1];
    $csv .= sprintf("\n%s;%s;%s;%s;%s;%s", $id, $ref, $master->{name}, $master->{description}, $from, $to);
  }
  close(TXT);
  my $dsn = "$self->{cfgDir}/routes.csv";
  open(CSV, "> :utf8", $dsn) or die;
  print CSV $csv;
  close(CSV);
  warn "dsn: $dsn";
}
#
# la mise en place des tags à partir du fichier routes.txt
sub illenoo_routes_txt_verif {
  my $self = shift;
  warn "illenoo_routes_txt_verif()";
  my $refs = $self->txt_routes_lire();
  for my $id (keys %{$refs} ) {
#    confess Dumper $refs->{$id};
    my $r = $refs->{$id};
    my $osm = get(sprintf("https://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $id));
#    confess $osm;
    delete $r->{'id'};
    $r->{name} = xml_escape($r->{name});
    $r->{description} = xml_escape($r->{description});
    $r->{'public_transport:version'} = '2';

    my @keys = keys %{$r};
    $osm = $self->{oOSM}->modify_tags($osm, $r, @keys);
#    warn $osm;
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');
  }
}
#
# la création des retours à partir du fichier routes.txt
sub illenoo_routes_txt_retour {
  my $self = shift;
  warn "illenoo_routes_txt_verif()";
  my $refs = $self->txt_routes_lire();
  for my $id (sort keys %{$refs} ) {
    if ($id !~ m{^\d+$} ) {
      next;
    }

#    confess Dumper $refs->{$id};
    my $r = $refs->{$id};
    warn $r->{ref};
    my $osm = get(sprintf("https://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $id));
#    warn $osm;
    my @lignes = split("\n", $osm);
    my @ways = grep(/<member.*role=""/, @lignes);
    my @stops = grep(/<member.*role="\S+"/, @lignes);
    my $ways = join("\n", reverse(@ways));
    my $stops = join("\n", reverse(@stops));
    $osm = <<EOF;
<relation id="-1" timestamp="0" changeset="1" version="1">
$stops
$ways
</relation>
EOF
    $r->{name} = xml_escape($r->{name});
    $r->{description} = xml_escape($r->{description});
    $r->{'public_transport:version'} = '2';
    $r->{id} = $r->{from};
    $r->{from} = $r->{to};
    $r->{to} = $r->{id};
    delete $r->{'id'};

    my @keys = keys %{$r};
    $osm = $self->{oOSM}->modify_tags($osm, $r, @keys);
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'create');
#    exit;
  }
}
sub illenoo_routes_bug {
  my $self = shift;
  warn "illenoo_routes_bug()";
  my $network = $self->{network};
  my $hash = $self->oapi_get("relation['public_transport:version'='2'][name~'Bus Illenoo'];out meta;", "$self->{cfgDir}/relations_route_bug.osm");
#  exit;
  foreach my $relation (sort @{$hash->{relation}}) {
    my $osm = get(sprintf("https://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
    my $r = {
      'route' => 'bus',
      'type' => 'route',
      'network' => 'fr_illenoo',
    };

    my @keys = keys %{$r};
    $osm = $self->{oOSM}->modify_tags($osm, $r, @keys);
#    warn $osm;
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');

  }
}
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