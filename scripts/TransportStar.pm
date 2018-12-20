# <!-- coding: utf-8 -->
#
# les infostarions du Réseau Malo Agglomération Transport
# http://www.star.fr/fileadmin/Sites/star/documents/timeo/Liste_des_codes_TIMEO_hiver_au_2604.pdf
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
use JSON qw(decode_json);
our ( $gtfs_iti, $ref, $hash, $relation_stops);
#
#
sub star_nodes_stops_old {
  my $self = shift;
  warn "star_nodes_stops_diff() debut";
  my $table = 'star_pointsarret';
  my $network = $self->{network};
  my $hash_node = $self->{oOAPI}->osm_get("node(area:3602005861)['highway'=bus_stop]['ref:FR:STAR']->.a;.a << ->.relations;.relations >> ->.b;(.a; - .b;)->.c;.c;out meta;", "$self->{cfgDir}/nodes_stops_old.osm");
  my $osm_delete = '';
  my $nb_delete = 0;
  my $josm = '';
  foreach my $node (sort @{$hash_node->{node}} ) {
    $osm_delete .= $self->{oOSM}->node_delete($node);
    $josm .= ',n' . $node->{id};
  }
#  $self->{oAPI}->changeset($osm_delete, $self->{source}, 'delete');
  warn $josm;
}
#
# pour les stops : différence entre osm et l'open data
#
#  ref:FR:STAR =
# perl scripts/keolis.pl --DEBUG 0 --DEBUG_GET 1 star star_nodes_stops_diff
sub star_nodes_stops_diff {
  my $self = shift;
  warn "star_nodes_stops_diff() debut";
  my $table = 'star_pointsarret_stop';
  my $network = $self->{network};
  my $hash_node = $self->{oOAPI}->osm_get("node['public_transport'='platform']['name']['$self->{k_ref}'];out meta;", "$self->{cfgDir}/star_relations_platform.osm");

  $self->{oDB}->table_select($table, '', 'ORDER BY code');
#
# on indexe
  warn "star_nodes_stops_diff() indexation osm nodes";
  foreach my $node (sort @{$hash_node->{node}} ) {
    my $ref =  $node->{tags}->{$self->{k_ref}};
    if ( $ref =~ m{^#\d+$} ) {
      warn "star_relations_stops_diff() ***ref";
      next;
    }
    if ( $ref !~ m{^\d+$} ) {
      warn "star_relations_stops_diff() indexation osm k_ref non numérique";
#      warn Dumper $node;
      next;
    }
    if ( defined $self->{stops}->{$ref}->{osm} ) {
      warn "*** meme ref n" . $node->{id} . ',n' . $self->{stops}->{$ref}->{osm}->{id};
      warn Dumper $node;
      warn Dumper $self->{stops}->{$ref}->{osm};
      next;
    }
    $self->{stops}->{$ref}->{osm} = $node;
  }
  warn "star_nodes_stops_diff() indexation star";
  for my $row ( @{$self->{oDB}->{table}->{$table}} ) {
    my $ref = $row->{'code'};
    $self->{stops}->{$ref}->{star} = $row;
  }
#
# on recherche les différences
  my $osm_create = '';
  my $osm_delete = '';
  my $osm_modify = '';
  my $nb_create = 0;
  my $nb_delete = 0;
  my $nb_modify = 0;
  my $josm = '';
  for my $ref ( sort keys %{$self->{stops}} ) {
#    warn $ref;
    if ( defined $self->{stops}->{$ref}->{osm} && defined $self->{stops}->{$ref}->{star}) {
      my $node = $self->{stops}->{$ref}->{osm};
      my $star = $self->{stops}->{$ref}->{star};
      my $coordonnees =  $star->{coordonnees};
      my ($lat, $lon) = ( $coordonnees =~ m{(\S+),\s(\S+)} );
      my $d = haversine_distance_meters($node->{lat}, $node->{lon}, $lat, $lon);
      if ( $d > 50 ) {
        warn "*** distance: $d";
        warn Dumper $self->{stops}->{$ref};
        $nb_modify++;
        my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{id}));
        $osm_modify .= $self->{oOSM}->modify_latlon($node_osm, $lat, $lon) . "\n";
      }
      if ( $node->{tags}->{name} ne $star->{nom} ) {
#        warn "n$node->{id} $node->{tags}->{name} ne $star->{nom}";
#        confess Dumper $self->{stops}->{$ref};
      }
      next;
    }
  }
  $self->{oAPI}->changeset($osm_modify, $self->{source}, 'modify');
  return;
  for my $ref ( sort keys %{$self->{stops}} ) {
#    warn $ref;
    if ( defined $self->{stops}->{$ref}->{osm} && defined $self->{stops}->{$ref}->{star}) {
      next;
    }
    if ( defined $self->{stops}->{$ref}->{osm} ) {
      my $node = $self->{stops}->{$ref}->{osm};
      warn "*** pas de star n". $node->{id};
      warn Dumper $self->{stops}->{$ref};
      $osm_delete .= $self->{oOSM}->node_delete($node);
      $josm .= ',n' . $node->{id};
      next;
    }
  }
# les arrêts inconnus d'osm
  my $hash_stop = $self->{oOAPI}->osm_get("node(area:3602005861)['highway'='bus_stop'];out meta;", "$self->{cfgDir}/star_relations_bus_stop.osm");
  for my $ref ( sort keys %{$self->{stops}} ) {
    if ( defined $self->{stops}->{$ref}->{osm} && defined $self->{stops}->{$ref}->{star}) {
      next;
    }
    if ( defined $self->{stops}->{$ref}->{osm} ) {
      next;
    }
    if ( $ref =~ m{^[4569]} ) {
      next;
    }
    warn $ref;
# pour empecher la creation des nodes
#    next;
#    warn Dumper $self->{stops}->{$ref};
    my $coordonnees =  $self->{stops}->{$ref}->{star}->{coordonnees};
    warn "$ref $coordonnees";
    my ($lat, $lon) = ( $coordonnees =~ m{(\S+),\s(\S+)} );
# on recherchde dans les stops proches
    foreach my $node (sort @{$hash_stop->{node}} ) {
      if ( defined $node->{tags}->{'ref:FR:STAR'} ) {
        next;
      }
      my $d = haversine_distance_meters($node->{lat}, $node->{lon}, $lat, $lon);
      if ( $d < 50 ) {
        printf("%s,%s %s,%s d: %s\n", $node->{lat}, $node->{lon}, $lat, $lon, $d);
        warn Dumper $self->{stops}->{$ref}->{star};
        warn Dumper $node;
      }
    }
    my $hash = {
      lon => $lon,
      lat => $lat,
      id => $self->{stops}->{$ref}->{star}->{code},
      name => $self->{stops}->{$ref}->{star}->{nom},
    };
    if (  $self->{stops}->{$ref}->{star}->{code} !~ m{^[0123]} ) {
      next;
    }
    my $osm = $self->star_node_stop_create($hash);
    $osm_create .=  $osm;
    $nb_create++;
  }
  warn "star_nodes_stops_diff() difference nb_create:$nb_create nb_delete:$nb_delete nb_modify:$nb_modify";
  $self->{oAPI}->changeset($osm_create, 'maj Keolis 2018', 'create');
#  $self->{oAPI}->changeset($osm_delete, $self->{source}, 'delete');
  warn "josm:\n$josm";

}
#
# création d'un node bus_stop à partir des données Keolis opendata
sub star_node_stop_create {
  my $self = shift;
  my $hash = shift;
  my $format = <<'EOF';
  <node lat="%s" lon="%s" id="%s" timestamp="0" changeset="1" version="1">
    <tag k="highway" v="bus_stop"/>
    <tag k="public_transport" v="platform"/>
    <tag k="name" v="%s"/>
    <tag k="ref:%s" v="%s"/>
  </node>
EOF
  $self->{node_id}--;
  return sprintf($format, $hash->{lat}, $hash->{lon}, $self->{node_id}, $hash->{name}, $self->{network}, $hash->{id});
}
#
# pour les relations route : différence entre osm et open data
sub star_parcours_diff {
  my $self = shift;
  warn "star_parcours_diff() debut";
  my $table = 'star_parcours';
  $table = 'star_parcours_stops_lignes';
  my $network = $self->{network};
  my $hash_route = $self->{oOAPI}->osm_get("relation[network='${network}'][type=route][route=bus];out meta;", "$self->{cfgDir}/relation_routes_bus.osm");
  $self->{oDB}->table_select($table, '', 'ORDER BY code');
  my $osm = '';
  my ( $parcours, $idlignes );
#
# on indexe
  foreach my $relation (@{$hash_route->{relation}}) {
#    confess Dumper $relation;
    my $tags = $relation->{tags};
    $tags->{id} = $relation->{id};
    if ( defined $tags->{FIXME} ) {
      next;
    }
    my $code = $tags->{'ref:FR:STAR'};
    if ( $code !~ m{^0[01]} ) {
      next;
    }
    my ( $idligne ) = ( $code =~ m{^(\d+)} );
    if ( defined $idlignes->{$idligne}->{$code}->{osm} ) {
      warn Dumper $idlignes->{$idligne}->{$code}->{osm};
      warn Dumper $tags;
      next;
    }
    $idlignes->{$idligne}->{$code}->{osm} = $tags;
  }
  for my $row ( @{$self->{oDB}->{table}->{$table}} ) {
    my $code = $row->{'code'};
    my $idligne = $row->{'idligne'};
    if ( $row->{'type'} !~ m{Principal} ) {
#      next;
    }
    if ( $row->{'idligne'} =~ m{[A-Z]}i ) {
      next;
    }
    if ( $row->{'idligne'} !~ m{^0[01]} ) {
      next;
    }
    $idlignes->{$idligne}->{$code}->{star} = $row;
  }
  for my $idligne ( sort keys %{$idlignes} ) {
    if ( $idligne !~ m{^0[01]} ) {
      next;
    }
    printf("%s\n", $idligne);
    my $lignes = '';
    my $ko = 0;
    $parcours =  $idlignes->{$idligne};
    for my $code ( sort keys %{$parcours} ) {
      $lignes .= sprintf("\t%s", $code);
      if ( not defined $parcours->{$code}->{'osm'} ) {
        $lignes .= sprintf(" star %s", $parcours->{$code}->{star}->{libellelong});
#        warn Dumper $parcours->{$code};
      }
      if ( not defined $parcours->{$code}->{'star'} ) {
        $lignes .= sprintf(" *osm %s r%s", $parcours->{$code}->{osm}->{description}, $parcours->{$code}->{osm}->{id});
        $ko++;
#        warn sprintf("%s", $code);
#        warn Dumper $parcours->{$code};
      }
      if ( defined $parcours->{$code}->{'osm'} && defined $parcours->{$code}->{'star'}) {
        $self->star_parcours_diff_parcours($parcours->{$code});
      }
      $lignes .= sprintf("\n");
    }
    if ( $ko > 0 ) {
      print $lignes;
    }
  }
}
#
# mise à jour de la relation route à partir des données open data
sub star_parcours_diff_parcours {
  my $self = shift;
  warn "star_parcours_diff_parcours() debut";
  my $parcours = shift;
  my $star = $parcours->{star};
  my $osm = $parcours->{osm};
  my ( $desc, $from, $to);
  $desc = $star->{libellelong};
  ($from ) = ($desc =~ m{(^.*?)\s\-\>} );
  $to = $desc;
  $to =~ s{ via .*$}{};
  $to =~ s{.* \-> }{};
  my $tags = {
   'ref:FR:STAR' => $star->{id},
   'from' => $from,
   'route' => 'bus',
   'public_transport:version' => '2',
   'description' => $star->{libellelong},
   'colour' => uc($star->{couleurtrac}),
   'ref' =>  $star->{nomcourtlig},
   'type' => 'route',
   'text_colour' => uc($star->{couleurtexteligne}),
   'name' => "Bus Star Ligne " . $star->{nomcourtlig} . " Direction " . $to,
   'operator' => 'Keolis Rennes',
   'network' => 'FR:STAR',
   'to' => $to
  };
  my $ko = 0;
  for my $k ( sort keys %{$tags} ) {
    if ( $tags->{$k} ne $osm->{$k} ) {
      printf("\t% 15s %s # %s\n", $k, $tags->{$k}, $osm->{$k});
      $ko++;
    }
  }
  if ( $ko > 0 ) {
#    confess Dumper $parcours;
    printf("%s r%s\n", $star->{id}, $osm->{id});
    $tags->{description} = xml_escape($tags->{description});
    my $xml = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $osm->{id}));
    $xml = $self->{oOSM}->modify_tags($xml, $tags, keys %{$tags});
    $self->{oAPI}->changeset($xml, "mise a jour des tags", 'modify');
#    exit;
  }
}
#
# pour mettre en place les members platform sur les relations
sub star_relations_stops_diff {
  my $self = shift;
  warn "star_relations_stops_diff() debut";
  my $table = 'star_parcours_stops_lignes';
  my $network = $self->{network};
  my $hash_route = $self->{oOAPI}->osm_get("relation[network='${network}'][type=route][route=bus];>>;out meta;", "$self->{cfgDir}/star_relations_routes_bus.osm");
  $self->{hash} = $hash_route;
  my $hash_node = $self->{oOAPI}->osm_get("node['public_transport'='platform']['name']['$self->{k_ref}'];out meta;", "$self->{cfgDir}/star_relations_stops.osm");;
  $self->{oDB}->table_select($table, '', 'ORDER BY code');
#  confess Dumper $star_parcours;
  my $osm = '';
  my ( $idlignes );
#
# on indexe
  warn "star_relations_stops_diff() indexation osm nodes";
  foreach my $node (sort @{$hash_node->{node}} ) {
    my $ref =  $node->{tags}->{$self->{k_ref}};
    if ( $ref =~ m{^#\d+$} ) {
      warn "star_relations_stops_diff() ***ref";
      next;
    }
    if ( $ref !~ m{^\d+$} ) {
      warn "star_relations_stops_diff() indexation osm k_ref non numérique";
#        warn Dumper $node;
      next;
    }
    $self->{stops}->{$ref} = $node->{id};
  }
  warn "star_relations_stops_diff() indexation osm relations";
  foreach my $relation (@{$hash_route->{relation}}) {
#    confess Dumper $relation;
    my $tags = $relation->{tags};
    my $idligne = $tags->{'ref:FR:STAR'};
    if ( $idligne !~ m{^0[01]} ) {
      next;
    }
    $idlignes->{$idligne}->{osm} = $relation;
  }
  warn "star_relations_stops_diff() indexation star";
  for my $row ( @{$self->{oDB}->{table}->{$table}} ) {
    my $idligne = $row->{'code'};
    $idlignes->{$idligne}->{star} = $row;
  }
#  exit;
#
# on parcourt ligne par ligne
  for my $idligne ( sort keys %{$idlignes} ) {
    if ( $idligne !~ m{^0[01]} ) {
      next;
    }
    printf("%s\n", $idligne);
    if ( ! defined $idlignes->{$idligne}->{'osm'}) {
      printf("\t%s type: %s\n", "absente osm", $idlignes->{$idligne}->{star}->{type});
#      warn Dumper $idlignes->{$idligne};
      next;
    }
    if ( ! defined $idlignes->{$idligne}->{'star'}) {
      printf("\t%s %s\n", "absente star");
      next;
    }
    if ( defined $idlignes->{$idligne}->{'osm'} && defined $idlignes->{$idligne}->{'star'}) {
      $self->star_stops_diff_stops($idlignes->{$idligne});
    }
  }
  warn "star_relations_stops_diff() fin";
}
#
# mise en place des stops si besoin
sub star_stops_diff_stops {
  my $self = shift;
#  warn "star_stops_diff_stops() debut";
  my $idligne = shift;
#  confess Dumper $idligne;
  my $star = $idligne->{star};
  warn "star: " . $star->{stops};
  my @stops = split(/,/, $star->{stops});
  my $osm_members = '';
  for my $stop ( @stops ) {
    my $id = $self->{stops}->{$stop};
    if ( $id !~ m{^\d+$} ) {
      confess "star_stops_diff_stops() *** stop: $stop inconnu dans osm";
    }
    $osm_members .= '    <member type="node" ref="' . $id . '" role="platform"/>' . "\n";
  }
  my $osm = $idligne->{osm};
#  confess Dumper $osm;
  my @nodes = $self->get_relation_route_member_platform($osm);
  my @refs = ();
#  warn "star_stops_diff_stops() nb nodes: " . scalar(@nodes);
  for my $node_id ( @nodes ) {
    my $node = $self->{hash}->{osm}->{node}->{$node_id};
#    warn Dumper $self->{hash}->{osm}->{node}->{$node_id};
    push @refs, $node->{tags}->{'ref:FR:STAR'};
  }
  my $refs = join(',', @refs);
  warn  "osm:  " . $refs;
  if ( $refs eq $star->{stops} && $refs eq '') {
    warn  "****";
    return;
  }
# rien à faire si identique
  if ( $refs eq $star->{stops} ) {
    return;
  }
  warn "star_stops_diff_stops() ***";
  $self->replace_relation_route_member_platform($osm->{id}, $osm_members);
}
sub replace_relation_route_member_platform {
  my $self = shift;
  my $id = shift;
  my $osm_members = shift;
  warn "replace_relation_route_member_platform r$id";
#  warn $osm_members;

  my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $id));
  if ( $relation_osm !~ m{role="(stop|platform)"} ) {
    confess '*** role="platform"' . $relation_osm;
  }
  my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $id));
  my $osm = $self->{oOSM}->relation_replace_member($relation_osm, '<member type="node" ref="\d+" role="platform[^"]*"/>', $osm_members);
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');
#  confess;
}
sub get_relation_route_member_platform {
  my $self = shift;
  my $relation = shift;
#  confess Dumper $relation;
  my @nodes = ();
  if ( not defined $relation->{member} ) {
    return @nodes;
  }
# vérification du type des nodes
  for my $member ( @{$relation->{member}} ) {
    if ( $member->{type} ne 'node' ) {
      next;
    };
    if ( $member->{'role'} =~ m{^stop} ) {
#      warn "get_relation_route_member_nodes() member stop " . $member->{ref};
      next;
#      warn Dumper $member;
    }
    push @nodes, $member->{ref};
  }
  return @nodes;
}
#
# pour mettre en place les tags sur une relation
sub star_route_shape_tags {
  my $self = shift;
  my $relation = shift;
  my $shape = shift;
#  warn "route_shape_tags() debut";
#  confess Dumper $shape;
#
# comparaison avec les tags
  my $ko = 0;
  my ($tags, $from, $to, $desc, $osm);
  my $desc = $shape->{libellelong};
  ($from ) = ($desc =~ m{(^.*?)\s\-\>} );
  $to = $desc;
  $to =~ s{ via .*$}{};
  $to =~ s{.* \-> }{};
  $tags->{from} = $from;
  $tags->{to} = $to;
  $tags->{description} =  $shape->{libellelong};
  $tags->{name} =  "Bus Rennes Ligne " . $shape->{nomcourtlig} . " Direction " . $to;
  $tags->{text_colour} =  uc($shape->{couleurtexteligne});
  $tags->{colour} =  uc($shape->{couleurligne});
  $tags->{text_colour} =~ s{[\x00-\x1F]}{}g;
#  confess Dumper $tags;
  for my $tag (sort keys %{$tags} ) {
    if ( not defined $relation->{tags}->{$tag} ) {
      $relation->{tags}->{$tag} = "???";
    }
    if ( $relation->{tags}->{$tag} ne $tags->{$tag} ) {
      $ko++;
      warn "\t *** $tag  osm:" . $relation->{tags}->{$tag}. "--gtfs:" . $tags->{$tag} . '--';
    }
  }
  if ( $ko == 0 ) {
    return;
  }
  $tags->{'source'} = $self->{source};
  my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
  $tags->{description} = xml_escape($tags->{description});
  $osm = $self->{oOSM}->modify_tags($relation_osm, $tags, keys %{$tags});
#  confess $osm;
#    warn Dumper $gtfs_routes->{$ref};exit;
   $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' modification tags', 'modify');
# confess;
}
#
# pour créer une relation "route"
sub start_relation_route_creer {
  my $self = shift;
  $self->{oDB}->table_select('star_parcours_stops_lignes');
  my $star_parcours = $self->{oDB}->{table}->{'star_parcours_stops_lignes'};
  my $parcours;
  for my $ligne ( @{$star_parcours} ) {
    $parcours->{$ligne->{'id'}} = $ligne;
#    warn $ligne->{'id'};
  }
  if ( not defined $parcours->{$self->{ref}} ) {
    confess "route_creer() ligne:$self->{ref}";
  }
  my $ligne = $parcours->{$self->{ref}};
#  confess Dumper  $ligne;
  $self->{relation_id}--;
  my $osm = sprintf('
  <relation id="%s" version="1"  changeset="1">
    <tag k="route" v="bus"/>
    <tag k="service" v="busway"/>
    <tag k="type" v="route"/>
  </relation>' , $self->{relation_id});
  my ($tags, $from, $to, $desc);
  my $desc = $ligne->{libellelong};
  ($from ) = ($desc =~ m{(^.*?)\s\-\>} );
  $to = $desc;
  $to =~ s{ via .*$}{};
  $to =~ s{.* \-> }{};
  $tags->{network} = $self->{network};
  $tags->{from} = $from;
  $tags->{to} = $to;
  $tags->{description} =  $ligne->{libellelong};
  $tags->{name} =  "Bus Rennes Ligne " . $ligne->{nomcourtlig} . " Direction " . $to;
  $tags->{"public_transport:version"} =  "2";
  $tags->{description} =  $ligne->{nomlong};
  $tags->{text_colour} =  uc($ligne->{couleurtexteligne});
  $tags->{colour} = uc($ligne->{couleurligne});
  $tags->{text_colour} =~ s{[\x00-\x1F]}{}g;
  $tags->{'ref:FR:STAR'} =  sprintf("%04d", $ligne->{id});
  $tags->{description} = xml_escape($tags->{description});
  $tags->{'source'} = $self->{source};
  $osm = $self->{oOSM}->modify_tags($osm, $tags, keys %{$tags}) . "\n";
  warn $osm;
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'create');
}
#
# pour lire les parcours en format geojson
sub star_parcours_geojson_lire {
  my $self = shift;
  my $dsn ='d:/web.var/geo/STAR/tco-bus-topologie-parcours-td.geojson';
  my $content = do { open my $fh, '<', $dsn or die $!; local $/; <$fh> };
  my $decoded_json = decode_json($content);
#  confess Dumper $decoded_json;
  my $features = $decoded_json->{features};
  for my $feature ( @{$features} ) {
#    confess Dumper $feature->{properties};
    $self->{geojson}->{$feature->{properties}->{code}} = $feature;
  }
  warn "star_parcours_geojson_lire() nb:" .scalar(keys %{ $self->{geojson}});

}
#
# pour les relations route : lecture osm
sub star_relations_routes_lire {
  my $self = shift;
  my $network = $self->{network};
  $self->{hash} = $self->{oOAPI}->osm_get("relation[network='${network}'][type=route][route=bus];>>;out meta;", "$self->{cfgDir}/star_relations_routes.osm");
#  confess Dumper $self->{hash};
}
#
# pour les relations route : différence entre osm et open data pour le parcous
sub star_relations_parcours_diff {
  my $self = shift;
  $self->star_parcours_geojson_lire();
  $self->star_relations_routes_lire();
  my ( $codes );
  my $josm = '';
#
# on indexe
  foreach my $relation (@{$self->{hash}->{relation}}) {
#    confess Dumper $relation;
    my $tags = $relation->{tags};
    $tags->{id} = $relation->{id};
    if ( defined $tags->{FIXME} ) {
      next;
    }
    my $code = $tags->{'ref:FR:STAR'};
 #   warn $code;
    if ( $code !~ m{^0[01]} ) {
      next;
    }
    $self->{codes}->{$code}->{osm} = $relation;
  }
  for my $code (sort keys %{ $self->{geojson}} ) {
    $self->{codes}->{$code}->{geojson} = $self->{geojson}->{$code};
  }
  for my $code (sort keys %{$self->{codes}} ) {
    if ( $code !~ m{^0[01]} ) {
#    if ( $code !~ m{^00[23456789]} ) {
#    if ( $code !~ m{^01[0123456789]} ) {
      next;
    }
    warn $code;
    if ( not defined $self->{codes}->{$code}->{geojson} ) {
      warn "*** geojson";
      next;
    }
    if ( not defined $self->{codes}->{$code}->{osm} ) {
      warn "*** osm";
      next;
    }
    $josm .= $self->star_relation_parcours_diff($code);
  }
  warn $josm;
}
sub star_relation_parcours_diff {
  my $self = shift;
  my $code = shift;
  my $relation = $self->{codes}->{$code}->{osm};
  my $parcours = $self->{codes}->{$code}->{geojson};
#  confess Dumper $osm;
  my @ways = ();
  if ( not defined $relation->{member} ) {
    confess;
  }
# liste des ways
  for my $member ( @{$relation->{member}} ) {
    if ( $member->{role} ne '' ) {
      next;
    };
    push @ways, $member->{ref};
  }
  my $lignes = '';
  my $josm = '';
  for my $way_id ( @ways ) {
    my $distance = 0;
    my $way =  $self->{hash}->{osm}->{way}->{$way_id};
#    confess Dumper $way;
    for my $node_id ( @{$way->{nodes}} ) {
      my $node =  $self->{hash}->{osm}->{node}->{$node_id};
#      confess Dumper $node;
      my $d = $self->star_node_parcours_distance($node, $parcours);
      if ( $d > $distance ) {
        $distance = $d;
      }
    }
    $lignes .= sprintf("\t%4d %s\n", $distance, $way->{tags}->{name});
    if ( $distance > 500 ) {
      warn "star_node_parcours_distance() distance: $distance";
      warn Dumper $way;
      printf("\n$lignes\n========================================\n");
      $josm .= ' r' . $relation->{id} . ' ' . $relation->{tags}->{$self->{k_ref}} . '.gpx';
      last;
    }
  }
  warn "josm: $josm";
  return $josm;
}
sub star_node_parcours_distance {
  my $self = shift;
  my $node = shift;
  my $parcours = shift;
#  confess Dumper $parcours;
  my $coordinates = $parcours->{'geometry'}->{'coordinates'};
#  confess Dumper $coordinates;
  my $distance = 100000;
  for my $coor ( @$coordinates ) {
    my ( $lon, $lat ) = @$coor;
#    warn " $lon, $lat";
    my $d = haversine_distance_meters($node->{lat}, $node->{lon}, $lat, $lon);
    if ( $d < $distance ) {
      $distance = $d;
    }
  }
  return $distance;
}
1;