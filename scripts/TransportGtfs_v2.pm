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
  warn$josm;
}
#
# pour les stops : différence entre osm et l'open data
#
#  ref:FR:STAR =
# perl scripts/keolis.pl --DEBUG 0 --DEBUG_GET 0 star star_nodes_stops_diff
sub star_nodes_stops_diff {
  my $self = shift;
  warn "star_nodes_stops_diff() debut";
  my $table = 'star_pointsarret';
  my $network = $self->{network};
  my $hash_node = $self->{oOAPI}->osm_get("node['public_transport'='platform']['name']['$self->{k_ref}'];out meta;", "$self->{cfgDir}/star_relations_platform.osm");
  my $hash_stop = $self->{oOAPI}->osm_get("node(area:3602005861)['highway'='bus_stop'];out meta;", "$self->{cfgDir}/star_relations_bus_stop.osm");

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
#        warn Dumper $node;
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
        warn "n$node->{id} $node->{tags}->{name} ne $star->{nom}";
#        confess Dumper $self->{stops}->{$ref};
      }
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
    if ( $ref =~ m{^[4569]} ) {
      next;
    }
    next;
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
    my $osm = $self->star_node_stop_create($hash);
    $osm_create .=  $osm;
  }
  warn "star_nodes_stops_diff() difference nb_create:$nb_create nb_delete:$nb_delete nb_modify:$nb_modify";
#  $self->{oAPI}->changeset($osm_create, 'maj Keolis aout 2018', 'create');
#  $self->{oAPI}->changeset($osm_delete, $self->{source}, 'delete');
  $self->{oAPI}->changeset($osm_modify, $self->{source}, 'modify');
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
#  warn Dumper $parcours;
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
    printf("%s r%s\n", $star->{id}, $osm->{id});
    $tags->{description} = xml_escape($tags->{description});
    my $xml = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $osm->{id}));
    $xml = $self->{oOSM}->modify_tags($xml, $tags, keys %{$tags});
    $self->{oAPI}->changeset($xml, "mise a jour des tags", 'modify');
#    exit;
  }
}
#
# pour mettre en place les stops sur les relations
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
      printf("\t%s\n", "absente osm");
      next;
    }
    if ( ! defined $idlignes->{$idligne}->{'star'}) {
      printf("\t%s\n", "absente star");
      confess;
    }
    if ( defined $idlignes->{$idligne}->{'osm'} && defined $idlignes->{$idligne}->{'star'}) {
      $self->star_stops_diff_stops($idlignes->{$idligne});
    }
  }
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
      confess "star_stops_diff_stops() *** stop: $stop";
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
  if ( $relation_osm !~ m{role="platform"} ) {
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
# pour les différentes lignes
sub star_routes_shapes_diff {
  my $self = shift;
  warn "routes_shapes_diff() debut";
  $self->{oDB}->table_select('star_parcours_stops_lignes');
  my $star_parcours = $self->{oDB}->{table}->{'star_parcours_stops_lignes'};
  my $gtfs_stops = $self->gtfs_stops_getid();
  my ($shapes, $routes);
#  confess Dumper $trips;
#
# on indexe
  for my $parcours ( @{$star_parcours} ) {
    if ( $parcours->{'idligne'} >= 200 ) {
#      next;
    }
    $shapes->{$parcours->{'code'}}->{star} = $parcours;
    my $route = substr($parcours->{'code'}, 0, 4);
    push @{$routes->{$route}}, $parcours->{'code'};
  }
#
# on vérifier l'indexation
#
# la liste par shape_id
  foreach my $shape_id ( sort keys %{$shapes} ) {
    my $nb = scalar(keys(%{$shapes->{$shape_id}}));
    if ( $nb != 1 ) {
      printf("%-30s %d\n", $shape_id, $nb);
      warn Dumper $shapes->{$shape_id};
    }
  }
#  confess Dumper $routes->{'0011'};
  my $network = $self->{network};
  $self->{hash_route} = $self->{oOAPI}->osm_get("relation[network='${network}'][type=route][route=bus];>>;out meta;", "$self->{cfgDir}/relation_routes_bus.osm");
#
# on fait plusieurs passes
# - on détermine les stops osm
  foreach my $relation (sort tri_tags_refstar @{$self->{hash_route}->{relation}}) {
#    if ( $relation->{user} ne 'mga_geo' ) {
#      next;
#    }
#    if ( $relation->{timestamp} !~ m{^2017\-10\-17T05} ) {
#      next;
#    }
#    warn "relation : " . $relation->{id};
#    warn Dumper $relation->{tags};
#    next;
    my $tags = $relation->{tags};
    if ( $tags->{'ref'} =~ /^2\d\d/ ) {
#      warn sprintf("*** ref %s", $tags->{'ref:FR:STAR'});
#      next;
    }
    if ( not defined $tags->{'ref:FR:STAR'} ) {
      warn sprintf("*** ref r%s %s", $relation->{id}, $tags->{'ref'});
      $tags->{'ref:FR:STAR'} = sprintf("%04d", $tags->{'ref'});
      next;
    }
    if ( $tags->{'ref:FR:STAR'} =~ /^02\d\d/ ) {
#      warn sprintf("*** ref:FR:STAR %s", $tags->{'ref:FR:STAR'});
#      next;
    }
    if ( $tags->{'ref:FR:STAR'} =~ /^\d+\-[AB]/ ) {
      warn sprintf("*** ref %s", $tags->{'ref:FR:STAR'});
#      next;
    }
#    warn Dumper $tags;
    my $shape_id =  $tags->{'ref:FR:STAR'};
#    warn sprintf("r%s %s", $relation->{id}, $shape_id);
    my $nodes_ref = $self->route_stops_get($relation);
    $shapes->{$shape_id}->{osm}->{stops} = $nodes_ref;
#
# liste identique ?
    my $s = "ok";
    if (  $shapes->{$shape_id}->{star}->{stops} ne $nodes_ref ) {
      $s = "ko";
#    warn $shapes->{$shape_id}->{star}->{stops};
#    warn $nodes_ref;
#    confess Dumper  $shapes->{$shape_id};
#      next;
    }
    $shapes->{$shape_id}->{stops} = $s;
    push @{$shapes->{$shape_id}->{relations}}, $relation;
  }
#  confess;
#
# la liste par shape_id
  foreach my $shape_id ( sort keys %{$shapes} ) {
#    confess Dumper $shapes->{$shape_id};
    my $type = '???';
    if ( defined $shapes->{$shape_id}->{star} ) {
      $type = $shapes->{$shape_id}->{star}->{type};
    }
    my $nb = 0;
    my $s = "";
    my $relation = '';
    if ( defined $shapes->{$shape_id}->{relations} ) {
      $nb = scalar(@{$shapes->{$shape_id}->{relations}});
      $s = $shapes->{$shape_id}->{stops};
      $relation = $shapes->{$shape_id}->{relations}[0];
    }
    my $ok = '';
    if ( $nb == 0 && $type eq 'Principal') {
      $ok = '***';
    }
    printf("%-30s %d %s %s %s\n", $shape_id, $nb, $type, $ok, $s);
    if ( $nb == 1 && $s eq "ko" && $type ne "") {
      $self->{shape} = $shape_id;
      $self->star_route_shape_stops();
    }
    if ( $nb == 1 && $s eq "ko" && $type ne "") {
      warn "*** pb stops type:$type $shape_id " . $relation->{id};
      warn "gtfs : " . $shapes->{$shape_id}->{star}->{stops};
      warn "osm  : " . $shapes->{$shape_id}->{osm}->{stops};
#      confess Dumper $shapes->{$shape_id};
      if ( $shapes->{$shape_id}->{star}->{stops} =~ m{^08\d+} ) {
        $self->{shape} = $shape_id;
        $self->route_shape_stops();
      }
#       $self->route_shape_tags($relation, $shapes->{$shape_id}->{star});
    }
    if ( $nb == 1 && $s eq "ko" && $type eq "") {
      warn "*** pb stops type:$type $shape_id " . $relation->{id};
      warn "gtfs : " . $shapes->{$shape_id}->{star}->{stops};
      warn "osm  : " . $shapes->{$shape_id}->{osm}->{stops};
#      confess Dumper $shapes->{$shape_id};
      if ( $shapes->{$shape_id}->{star}->{stops} =~ m{^\d+} ) {
        $self->{shape} = $shape_id;
        $self->route_shape_stops();
      }
#       $self->route_shape_tags($relation, $shapes->{$shape_id}->{star});
    }
  }
  confess;
  foreach my $relation (sort tri_tags_refstar @{$self->{hash_route}->{relation}}) {
#  confess Dumper $shapes;
    my $tags = $relation->{tags};
    if ( $tags->{'ref'} =~ /^2\d\d/ ) {
#      warn sprintf("*** ref %s", $tags->{'ref:FR:STAR'});
#      next;
    }
    if ( not defined $tags->{'ref:FR:STAR'} ) {
      warn sprintf("*** ref r%s %s", $relation->{id}, $tags->{'ref'});
      $tags->{'ref:FR:STAR'} = sprintf("%04d", $tags->{'ref'});
      next;
    }
    if ( $tags->{'ref:FR:STAR'} !~ /^02\d\d/ ) {
#      warn sprintf("*** ref %s", $tags->{'ref:FR:STAR'});
      next;
    }
    if ( $tags->{'ref:FR:STAR'} =~ /^\d+\-[AB]/ ) {
#      warn sprintf("*** ref %s", $tags->{'ref:FR:STAR'});
#      next;
    }
#    warn Dumper $tags;
    if (not defined $shapes->{ $tags->{'ref:FR:STAR'}} ) {
      warn Dumper $tags;
#      next;
    }
#    warn Dumper $shapes->{ $tags->{'ref:FR:STAR'}};
    my $shape_id =  $tags->{'ref:FR:STAR'};
    warn sprintf("r%s %s",$relation->{id}, $shape_id);
    my $nodes_ref = $self->route_stops_get($relation);
    if (  $shapes->{$shape_id}->{star}->{stops} eq $nodes_ref ) {
      next;
    }
    warn "\t" . $shapes->{$shape_id}->{star}->{stops};
    warn "\t" . $nodes_ref;
    my @arrets;
    my @stops = split(',', $shapes->{$shape_id}->{star}->{stops});
    my $i = 0;
    foreach my $stop (@stops) {
      $arrets[$i]->{gtfs} = $stop;
      $arrets[$i++]->{gtfs_name} = $gtfs_stops->{$stop}->{'stop_name'};
    }
    @stops = split(',', $nodes_ref);;
    $i = 0;
    foreach my $stop (@stops) {
      $arrets[$i]->{osm_name} = $gtfs_stops->{$stop}->{'stop_name'};
      $arrets[$i++]->{osm} = $stop;
    }
#
# la liste des shapes de cette route
    my $j = 0;
    my $route = substr($shape_id, 0, 4);
    my @routes;
    foreach my $route ( @{$routes->{$route}} ) {
#      warn "route:$route shape_id:$shape_id";
      if ( $route eq $shape_id ) {
        next;
      }
      if ( scalar(@{$shapes->{$route}->{relations}}) > 0 ) {
        next;
      }
#      warn "route:$route";
      push @routes, $route;
    }
#    confess Dumper \@routes;
    foreach my $route (@routes) {
      $i = 0;
      @stops = split(',', $shapes->{$route}->{star}->{stops});
      foreach my $stop (@stops) {
        $arrets[$i]->{"osm_name_$j"} = $gtfs_stops->{$stop}->{'stop_name'};
        $arrets[$i++]->{"osm_$j"} = $stop;
      }
      $j++;
    }
#    confess Dumper \@arrets;
    printf("\t%4s %4s % 25s % 25s", "osm", "gtfs", $shape_id, $shape_id);
#    warn "j:$j";
    for $i ( 0 .. $j-1 ) {
      printf(" %25s",  $routes[$i]);
    }
    printf("\n");
    foreach my $arret (@arrets) {
#      confess Dumper $arret;
      printf("\t%4s %4s % 25s % 25s", $arret->{osm}, $arret->{gtfs}, $arret->{osm_name}, $arret->{gtfs_name});
      for $i ( 0 .. $j-1 ) {
        printf(" %25s",  $arret->{"osm_name_$i"});
      }
      printf("\n");
    }
#    last;
  }
}

#
# pour mettre en place les stops sur une relation
sub star_route_shape_stops {
  my $self = shift;
  warn "route_shape_stops() debut";
#  confess Dumper $self;
  $self->{oDB}->table_select('star_parcours_stops_lignes');
  my $star_parcours = $self->{oDB}->{table}->{'star_parcours_stops_lignes'};
  my $gtfs_stops = $self->gtfs_stops_getid();
  my ($shapes, $routes);
#  confess Dumper $trips;
  for my $parcours ( @{$star_parcours} ) {
    $shapes->{$parcours->{'id'}} = $parcours;
  }
  if ( not defined $shapes->{$self->{shape}} ) {
    warn "route_shape_stops() *** shape absent $self->{shape}";
    return;
  }
#  confess Dumper $routes->{'0011'};
  my $network = $self->{network};
  $self->{hash_route} = $self->{oOAPI}->osm_get("relation[network='${network}'][type=route][route=bus]['" . $self->{k_ref} . "'='" . $self->{shape} . "'];>>;out meta;", "$self->{cfgDir}/route_shape_stops.osm", 1);
  my $nb = scalar(@{$self->{hash_route}->{relation}});
  warn "route_shape_stops() " . $self->{shape} . " nb : $nb";
  if ( $nb == 0 ) {
    warn "route_shape_stops() relations nb : $nb";
    $self->{hash_route} = $self->{oOAPI}->osm_get("relation(" . $self->{id} . ");>>;out meta;", "$self->{cfgDir}/route_shape_stops.osm");
  }
  $nb = scalar(@{$self->{hash_route}->{relation}});
  if ( $nb != 1 ) {
    warn "route_shape_stops() relations nb : $nb";
    confess;
  }
#  exit;
  my $relation = @{$self->{hash_route}->{relation}}[0];
  my $tags = $relation->{tags};
  if (not defined $tags->{'ref:FR:STAR'} ) {
    warn Dumper $tags;
    confess;
  }
#  $self->route_shape_tags($relation,  $shapes->{$self->{shape}});  return;
  my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
  $relation_osm = $self->{oOSM}->delete_osm($relation_osm);
  if ($tags->{'ref:FR:STAR'} ne $self->{shape} ) {
    warn "route_shape_stops() ref ", $tags->{'ref:FR:STAR'}, $self->{shape};
    warn Dumper $tags;
    confess;
    my $t = {
      $self->{k_ref} => $self->{shape},
      'source' => $self->{source}
    };
    $relation_osm = $self->{oOSM}->modify_tags($relation_osm, $t, qw(ref:FR:STAR source)) . "\n";
#    confess Dumper $tags;
  }
  my $osm_stops = $self->get_relation_route_member_stops($relation);
  my $gtfs_stops = $shapes->{$self->{shape}}->{stops};
  warn "route_shape_stops() osm  $osm_stops";
  warn "route_shape_stops() gtfs $gtfs_stops";
  if ( $osm_stops eq $gtfs_stops ) {
    return;
  }
  warn "route_shape_stops() delta ***";
  $self->{hash_stops} = $self->oapi_get("node['highway'='bus_stop']['" . $self->{k_ref} . "'];out meta;", "$self->{cfgDir}/route_shape_stops_node.osm");
  my $refs;
  foreach my $node (@{$self->{hash_stops}->{node}}) {
    $refs->{$node->{tags}->{$self->{k_ref}}} = $node;
  }
  my @stops = split(',', $gtfs_stops);
  my $i = 0;
  my $osm = '';
  foreach my $stop (@stops) {
    if ( not defined $refs->{$stop} ) {
      warn "route_shape_stops() $stop";
      confess;
    }
    $osm .= '    <member type="node" ref="' . $refs->{$stop}->{id} . '" role="platform"/>' . "\n";
    $relation_osm = $self->{oOSM}->relation_replace_member($relation_osm, '<member type="node" ref="\d+" role="platform[^"]*"/>', $osm);
  }
#  confess "route_shape_stops()\n $osm";
  $self->{oAPI}->changeset($relation_osm, $self->{osm_commentaire}, 'modify');
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
# pour mettre en place "ref:star"
sub star_parcours_diff_v2 {
  my $self = shift;
  warn "star_parcours_diff() debut";
  my $table = 'star_parcours';
  my $network = $self->{network};
  my $hash_route = $self->{oOAPI}->osm_get("relation[network=${network}][type=route][route=bus];out meta;", "$self->{cfgDir}/relation_routes_bus.osm");
  $self->start_parcours_get($table);
  my $osm = '';
  foreach my $relation (@{$hash_route->{relation}}) {
#    confess Dumper $relation;
    my $tags = $relation->{tags};
    if ( $tags->{ref} =~ /^Ts/ ) {
      next;
    }
    if ( $tags->{ref} !~ /^C4/ ) {
#      next;
    }
    if ( not defined $tags->{'description'} or not defined $tags->{'description'} ) {
      confess Dumper $tags;
    }
    warn sprintf("%s %s from:%s to:%s id:%s", $tags->{'ref'}, $tags->{'description'}, $tags->{'from'}, $tags->{'to'}, $relation->{'id'});
    for my $row ( @{$self->{oDB}->{table}->{$table}} ) {
      if ( $tags->{'ref'} ne $row->{'nomcourtlig'} ) {
        next;
      }
      if ( $tags->{'from'} ne $row->{'nomarretdep'} ) {
        next;
      }
      if ( $tags->{'to'} ne $row->{'nomarretarr'} ) {
        next;
      }
      if (  $tags->{'ref:star'} && $tags->{'ref:star'} eq $row->{'code'} ) {
        next;
      }
      if (  $row->{'code'} !~ m{\-01\-[AB]$} ) {
        next;
      }
      warn sprintf("\t%s %s from:%s to:%s", $tags->{'ref'}, $tags->{'ref:star'}, $tags->{'from'}, $tags->{'to'});
      warn sprintf("\t%s %s from:%s to:%s", $row->{'code'}, $row->{'libellelong'}, $row->{'nomarretdep'}, $row->{'nomarretarr'});
      next;
      my $relation_id = $relation->{'id'};
      my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation_id));
      $tags->{'ref:star'} =  $row->{'code'};
      $tags->{'source'} =  $self->{'source'};
      $osm .= $self->{oOSM}->modify_tags($relation_osm, $tags, qw(ref:star source)) . "\n";
      $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' modification ref:star', 'modify');
      $osm = '';
      next;
      Dump $tags->{'to'};
      Dump $row->{'nomarretarr'};
      confess Dumper $row;
    }
  }
#  confess $osm;
}
#
#
# pour mettre en place "ref:FR:STAR"
sub star_parcours_ref_v2 {
  my $self = shift;
  warn "star_parcours_ref_v2() debut";
  my $table = 'star_parcours';
  $table = 'shapes2routes';
  my $network = $self->{network};
#  my $hash = $self->{oOAPI}->osm_get("relation[network='${network}'][type=route][route=bus];>>;out meta;", "$self->{cfgDir}/relation_routes_bus.osm");
  my $hash = $self->{oOAPI}->osm_get("relation[network='${network}'][type=route][route=bus]['ref:FR:STAR'!~'0'];>>;out meta;", "$self->{cfgDir}/relation_routes_bus.osm");
  $self->star_parcours_get_v2($table);
  my $osm = '';
  foreach my $relation (@{$hash->{relation}}) {
    @{$relation->{nodes}} = ();
    @{$relation->{ways}} = ();
    my $nb_nodes = 0;
    my $nb_ways = 0;
# vérification du type des "member"
    for my $member ( @{$relation->{member}} ) {
      if ( $member->{type} eq 'node' ) {
        push @{$relation->{nodes}}, $member->{ref};
        $nb_nodes++;
        next;
      };
      if ( $member->{type} eq 'way' ) {
        push @{$relation->{ways}}, $member->{ref};
        next;
      };
    }
    if ( $nb_nodes < 3 ) {
      next;
    }
# départ / arrivée
    my $node_from = find_node($relation->{nodes}[0], $hash);
    my $node_to = find_node($relation->{nodes}[-1], $hash);
#   confess Dumper $node;
#   confess Dumper $relation;
    my $tags = $relation->{tags};
    $tags->{'node_from'} = $node_from->{'tags'}->{'ref:FR:STAR'};
    $tags->{'node_to'} = $node_to->{'tags'}->{'ref:FR:STAR'};
    if ( not defined $tags->{'description'} or not defined $tags->{'ref'} or not defined $tags->{'ref:FR:STAR'} ) {
      warn "parcours_ref_v2() description ...";
#      warn Dumper $tags;
#      next;
    }
    if ( $tags->{ref} =~ /^T/ ) {
#      next;
    }
    if ( $tags->{ref} =~ /^2\d\d/ ) {
#      next;
    }
    if ( $tags->{'ref:FR:STAR'} =~ /^\d+\-[AB]/ ) {
      warn sprintf("*** ref %s %s", $tags->{'ref:FR:STAR'}, $tags->{'description'});
      next;
    }
#    next;

    if ( $tags->{ref} !~ /^C4/ ) {
#      next;
    }

    warn sprintf("%s %s from:%s to:%s id: r%s", $tags->{'ref'}, $tags->{'description'}, $tags->{'from'}, $tags->{'to'}, $relation->{'id'});
    warn sprintf("ref %s from : % s to : %s", $tags->{'ref:FR:STAR'}, $relation->{nodes}[0], $relation->{nodes}[-1]);
    warn sprintf("ref %s from : % s to : %s", $tags->{'ref:FR:STAR'}, $node_from->{'tags'}->{'ref:FR:STAR'}, $node_to->{'tags'}->{'ref:FR:STAR'});
    warn sprintf("ref %s from : % s to : %s", $tags->{'ref:FR:STAR'}, $node_from->{'tags'}->{'name'}, $node_to->{'tags'}->{'name'});
    for my $row ( @{$self->{oDB}->{table}->{$table}} ) {
      if ( $tags->{'ref'} ne $row->{'route_short_name'} ) {
        next;
      }
#      warn Dumper $row;
      warn sprintf("\tref:FR:STAR=%s from:%s to:%s", $row->{'shape_id'}, $row->{'depart_name'}, $row->{'arrivee_name'});
#      confess;
      if ( $tags->{'node_from'} ne $row->{'depart_id'} ) {
        next;
      }
      if ( $tags->{'node_to'} ne $row->{'arrivee_id'} ) {
        next;
      }
      if (  $tags->{'ref:star'} && $tags->{'ref:star'} eq $row->{'code'} ) {
#        next;
      }
      if (  $row->{'code'} !~ m{\-01\-[AB]$} ) {
#        next;
      }
      warn sprintf("\t%s %s from:%s to:%s", $tags->{'ref'}, $tags->{'ref:FR:STAR'}, $tags->{'from'}, $tags->{'to'});
      warn sprintf("\t%s %s from:%s to:%s", $row->{'shape_id'}, $row->{'route_long_name'}, $row->{'depart_name'}, $row->{'arrivee_name'});
#      warn Dumper $tags;
#      next;
      my $relation_id = $relation->{'id'};
      my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation_id));
      $tags->{'ref:FR:STAR'} =  $row->{'shape_id'};
      $tags->{'source'} =  $self->{'source'};
      $osm .= $self->{oOSM}->modify_tags($relation_osm, $tags, qw(ref:FR:STAR source)) . "\n";
      $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' modification ref:FR:STAR', 'modify');
      $osm = '';
      next;
      Dump $tags->{'to'};
      Dump $row->{'nomarretarr'};
      confess Dumper $row;
    }
  }
#  confess $osm;
}
# récupération d'une table
sub star_parcours_get {
  my $self = shift;
  my $table = shift;
  $self->{oDB}->table_select($table, '', 'ORDER BY shape_id');
  warn "star_parcours_get() nb:".scalar(@{$self->{oDB}->{table}->{$table}});
}
#
# avec les données gtfs de Keolis
# ================================================================================
#
#
# pour trouver les relations "route" non utilisées dans une relation route_master
sub star_valid_route_hors_master {
  my $self = shift;
  warn "valid_route_hors_master() debut";
  my $hash = $self->oapi_get("relation[network=fr_star][type=route][route=bus]->.all;relation[network=fr_star][type=route_master][route_master=bus];relation(r);( .all; - ._; );out meta;", "$self->{cfgDir}/route_hors_master.osm");
  my $gtfs_routes = $self->gtfs_routes_get();
  my $level0 = '';
  foreach my $relation (sort tri_tags_ref @{$hash->{relation}}) {
    warn sprintf("valid_route_hors_master() r%s;ref:%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp});
    if ( not defined $gtfs_routes->{$relation->{tags}->{ref}} ) {
      warn "\t hors gtfs";
      $level0 .= ",r". $relation->{id};
    }
  }
  warn $level0;
}
#
# cohérence des tags from to avec la première et dernière station
sub star_fromto_route {
  my $self = shift;
  warn "fromto_route() debut";
#  my $hash = $self->oapi_get("relation[network=fr_star][type=route]['route'='bus'];out meta;", "$self->{cfgDir}/route_bus.osm");
  my $hash = $self->oapi_get("(relation[network=fr_star][type=route]['route'='bus'];node(r));out meta;", "$self->{cfgDir}/route_bus.osm");
#  my $hash_nodes = $self->osm_nodes_bus_stop_get(0);
  my $gtfs_routes = $self->gtfs_routes_get();
  my $gtfs_stops = $self->gtfs_stops_getid();
  my ($id_name, $nodes);
#  foreach my $node (sort @{$hash_nodes->{node}}) {
  foreach my $node (sort @{$hash->{node}}) {
    $id_name->{$node->{id}} = $node->{tags}->{name};
    $nodes->{$node->{id}} = $node;
  }
#  confess Dumper $id_name;
  my $osm = '';
  foreach my $relation (sort @{$hash->{relation}}) {
    if ( $relation->{tags}->{ref} =~ m{^Ts\d+} ) {
      next;
    }
    my $ref = $relation->{tags}->{ref};
    if ( $ref =~ m{^\d+$} && $ref >= 200 ) {
      next;
    }
    if ( $ref != 233 ) {
#      next;
    }
    warn "fromto_route() r" . $relation->{id} . " ref:" . $ref;
    if ( not defined $gtfs_routes->{$ref} ) {
      warn "fromto_route() *** absent gtfs";
      next;
    }
#
# recherche des from to
    @{$relation->{nodes}} = ();
    @{$relation->{ways}} = ();
    if ( not defined $relation->{member} ) {
      warn "fromto_route() *** pas de memmbre";
      next;
    }
# vérification du type des "member"
    for my $member ( @{$relation->{member}} ) {
      if ( $member->{type} eq 'node' ) {
        push @{$relation->{nodes}}, $member->{ref};
        next;
      };
      if ( $member->{type} eq 'way' ) {
        push @{$relation->{ways}}, $member->{ref};
        next;
      };
    }
    if ( scalar(@{$relation->{nodes}}) <= 1 ) {
      warn "fromto_route() *** pas assez de stations r" . $relation->{id} . " ref:" . $relation->{tags}->{ref};
      next;
    }
#    confess Dumper $relation->{nodes}[0];
    my $id = $relation->{nodes}[0];
    if ( not defined $id_name->{$id} ) {
      warn "fromto_route() *** from id " . $id . " ref:" . $relation->{tags}->{ref};
      next;
    }
    my $from_id = $nodes->{$id}->{tags}->{ref};

    my $from = $id_name->{$id};
    $id = $relation->{nodes}[-1];
    if ( not defined $id_name->{$id} ) {
      warn "fromto_route() *** to id " . $id . " ref:" . $relation->{tags}->{ref};
      next;
    }
    my $to = $id_name->{$id};
    my $to_id = $nodes->{$id}->{tags}->{ref};
    if ( not defined  $gtfs_stops->{$from_id} ) {
      warn "fromto_route() *** gtfs_stops " . $from_id;
      next;
    }
    if ( not defined  $gtfs_stops->{$to_id} ) {
      warn "fromto_route() *** gtfs_stops " . $to_id;
      next;
    }
    my $dest = $to;
    if ( $gtfs_stops->{$from_id}->{'stop_desc'} ne $gtfs_stops->{$to_id}->{'stop_desc'} ) {
      my $ville = $gtfs_stops->{$from_id}->{stop_desc};
#      $from =~ s{$ville\s+}{};
#      $from = $ville . ' (' . $from . ')';
      $ville = $gtfs_stops->{$to_id}->{stop_desc};
      $dest =~ s{$ville\s+}{};
      $dest = $ville . ' (' . $to . ')';
    }
    if ( 2 == 1 ) {
      warn "from_id:$from_id";
      warn Dumper $gtfs_stops->{$from_id};
      warn "to_id:$to_id";
      warn Dumper $gtfs_stops->{$to_id};
      warn "to:$to " . $gtfs_stops->{$to_id}->{'stop_desc'};
    }

#
# comparaison avec les tags
    my $ko = 0;
    my $tags;
    $tags->{from} =  $from;
    $tags->{to} =  $to;
    $tags->{description} =  $gtfs_routes->{$ref}->{route_long_name};
    $tags->{name} =  "Bus Rennes Ligne " . $gtfs_routes->{$ref}->{route_short_name} . " Direction " . $dest;
    $tags->{text_color} =  '#' . $gtfs_routes->{$ref}->{route_text_color};
    $tags->{colour} =  '#' . $gtfs_routes->{$ref}->{route_color};
    for my $tag (sort keys %{$tags} ) {
      if ( not defined $relation->{tags}->{$tag} ) {
        $relation->{tags}->{$tag} = "???";
      }
      if ( $relation->{tags}->{$tag} ne $tags->{$tag} ) {
        $ko++;
        warn "\t *** $tag  osm:" . $relation->{tags}->{$tag}. "--gtfs:" . $tags->{$tag} . '--';
      }
    }
    if ( $ko > 0 ) {
      my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
      $tags->{description} = xml_escape($gtfs_routes->{$ref}->{route_long_name});
      $osm = $self->{oOSM}->modify_tags($relation_osm, $tags, qw(name description text_color colour from to));
#      warn Dumper $gtfs_routes->{$ref};exit;
      $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' modification tags', 'modify');
#      confess;
    }
    next;
    my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
    $osm .= $self->{oOSM}->relation_disused($relation_osm);
  }

}
#
# pour trouver les meilleures relations
sub star_valid_route_type {
  my $self = shift;
  my $ref = $self->{ref};
  warn "valid_route_type() debut";
  $hash = $self->oapi_get("(relation[network=fr_star][type=route][route=bus][ref=$ref];node(r));out meta;", "$self->{cfgDir}/relation_type_${ref}.osm");
# indexationdes nodes
  my $id_name;
  foreach my $node (sort @{$hash->{node}}) {
    $id_name->{$node->{id}} = $node->{tags}->{name}
  }
  my $csv = "";
  $csv = join(";", qw(ref description name destination from to id user timestamp));
  foreach my $relation (@{$hash->{relation}}) {
    $csv .= "\n";
    @{$relation->{nodes}} = ();
    @{$relation->{ways}} = ();
    if ( not defined $relation->{member} ) {
      warn "valid_route_type() *** member";
      next;
    }
# vérification du type des nodes
    for my $member ( @{$relation->{member}} ) {
      if ( $member->{type} eq 'node' ) {
        push @{$relation->{nodes}}, $member->{ref};
        next;
      };
      if ( $member->{type} eq 'way' ) {
        push @{$relation->{ways}}, $member->{ref};
        next;
      };
    }
    undef $relation->{member};
#    confess Dumper $relation->{nodes}[0];
    my $id = $relation->{nodes}[0];
    if ( not defined $id_name->{$id} ) {
      warn "valid_route_type() *** from id " . $id . " ref:" . $relation->{tags}->{ref};
      next;
    }
    my $from = $id_name->{$id};
    $id = $relation->{nodes}[-1];
    if ( not defined $id_name->{$id} ) {
      warn "valid_route_type() *** to id " . $id . " ref:" . $relation->{tags}->{ref};
      next;
    }
    my $to = $id_name->{$id};
#    confess Dumper $relation;
    for my $k ( qw(ref route description name destination from to) ) {
      if ( exists $relation->{tags}->{$k} ) {
        $csv .= $relation->{tags}->{$k};
      }
      $csv .= ';';
    }
    $csv .=  $relation->{id} . ";";
    for my $k ( qw(user timestamp) ) {
      $csv .= $relation->{$k};
      $csv .= ';';
    }
    for my $k ( qw(nodes ways) ) {
      $csv .= scalar(@{$relation->{$k}});
      $csv .= ';';
    }
    chop $csv;
    $csv .= ";$from;$to"
#    last;
#    warn $tags;
  }
  print "$csv\n";
}
#
# pour preparer la suppression des disused
sub star_disused_route_desc {
  my $self = shift;
  warn "disused_route() debut";
  my $hash = $self->oapi_get("relation[network=fr_star]['disused:route'];out meta;", "$self->{cfgDir}/disused_route.osm");
  my $osm = '';
  foreach my $relation (@{$hash->{relation}}) {
    my @desc;
    for my $k ( qw(ref description name) ) {
      if ( exists $relation->{tags}->{$k} && $relation->{tags}->{$k} !~ m{^ZZZ }) {
        $relation->{tags}->{$k} = "ZZZ " . $relation->{tags}->{$k};
        push @desc, $k;
      }
    }
    if ( $#desc < 1 ) {
      next;
    }
    my $relation_id = $relation->{'id'};
    if ( $relation_id =~m{^140084} ) {
      warn $relation_id;
      next
    }
    if ( $relation_id =~m{^174333} ) {
      warn $relation_id;
      next;
    }
    if ( $relation_id =~m{^2294979} ) {
      next;
    }
    if ( $relation_id =~m{^2294980} ) {
      next;
    }
    if ( $relation_id =~m{^4037898} ) {
      next;
    }
    my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation_id));
    $osm .= $self->{oOSM}->modify_tags($relation_osm, $relation->{tags}, @desc) . "\n";
#    confess Dumper $osm;
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' modification disused', 'modify');
    $osm = '';
#    last;
  }
}
#
# pour passer en disused les routes sans ref:star
sub star_disused_route_star {
  my $self = shift;
  warn "disused_route() debut";
  my $hash = $self->oapi_get("relation[network=fr_star]['route'='bus'];out meta;", "$self->{cfgDir}/disused_route_star.osm");
  my $osm = '';
  foreach my $relation (@{$hash->{relation}}) {
    my @desc;
    if ( exists $relation->{tags}->{'ref:star'} ) {
      next;
    }
    if ($relation->{tags}->{'ref'} =~ m{^2\d\d$} ) {
      next;
    }
    if ($relation->{tags}->{'ref'} =~ m{^Ts} ) {
      next;
    }
    for my $k ( qw(description name) ) {
      if ( exists $relation->{tags}->{$k} && $relation->{tags}->{$k} !~ m{^ZZZ }) {
        $relation->{tags}->{$k} = "ZZZ " . $relation->{tags}->{$k};
        push @desc, $k;
      }
    }
    if ( $#desc < 1 ) {
      next;
    }
    my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
    $osm .= $self->{oOSM}->modify_tags($relation_osm, $relation->{tags}, @desc) . "\n";
#    confess Dumper $osm;
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' modification disused', 'modify');
    $osm = '';
#    last;
  }
}
#
# pour supprimer les disused:route
sub star_disused_route_delete {
  my $self = shift;
  warn "disused_route_delete() debut";
  my $hash = $self->oapi_get("relation[network=fr_star]['disused:route'='bus'];out meta;", "$self->{cfgDir}/disused_route_delete.osm");
  my $osm = '';
  warn "disused_route_delete() nb:" . scalar(@{$hash->{relation}});
  foreach my $relation (@{$hash->{relation}}) {
#    confess Dumper $relation;
    warn "disused_route_delete() ref:" . $relation->{tags}->{ref};
    $osm = $self->{oOSM}->relation_delete($relation);
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' supression disused', 'delete');
#    last;
  }
}

#
# pour mettre en disused les line
sub star_line_disused_route {
  my $self = shift;
  warn "line_disused_route() debut";
  my $hash = $self->oapi_get("relation[network=fr_star][type=route][line=bus];out meta;", "$self->{cfgDir}/unused_route.osm");
  my $osm = '';
  warn  "line_disused_route() nb:" . scalar(@{$hash->{relation}});
  foreach my $relation (@{$hash->{relation}}) {
    my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
    $osm .= $self->{oOSM}->relation_disused($relation_osm);
  }
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' passage en disused', 'modify');
}
# pour les différentes lignes
sub star_diff_routes {
  my $self = shift;
  warn "diff_routes() debut";
  my $gtfs_routes = $self->gtfs_routes_get();
  $self->{'log'} = '';
  for $ref (sort tri_ref keys %{$gtfs_routes}) {
#  for $ref ( 10 .. 49 ) {
#  for $ref ( 50.. 99 ) {
#  for $ref ( 100 .. 199 ) {
#  for $ref ( 200 .. 250 ) {
#  for $ref ( qw(Ts55 Ts56 Ts57 Ts58) ) {
# a : la ligne du métro
    if ( $ref =~ m{^(a)$} ) {
      next;
    }
    if ( $ref !~ m{^\d\d$} ) {
 #     next;
    }
    if ( $self->{network} eq 'fr_star' && ( $ref =~ m{^T} || $ref =~ m{^\d\d\d$} ) ) {
      next;
    }
    if ( $self->{network} eq 'fr_star' && ( $ref !~ m{^[\dC]} ) ) {
      next;
    }
    warn "\n\n\ndiff_routes() ref:$ref\n\n\n";
    $self->{'log'} .= "\n==============\ndiff_routes() ref:$ref\n";
    $self->{'ref'} = $ref;
    $self->star_diff_route();
  }
  warn "diff_routes() fin";
}
#
# pour les itinéraires d'une ligne
sub star_diff_route {
  my $self = shift;
  $self->{mode} = 'relation_tags';
  $self->{mode} = 'relation_node,relation_create';
  $ref = $self->{ref};
  warn "diff_route() ref:$ref";
  $gtfs_iti = $self->gtfs_keolis_iti_get($ref);
#  confess Dumper $gtfs_iti;
  if ( ! $gtfs_iti ) {
    $self->{'log'} .= "\tdiff_routes() *** gtfs_iti\n";
    return;
  }
#  confess Dumper $gtfs_iti;
# pas top, sur la variable globale
  $hash = $self->osm_route_get($ref);
  $self->relations_route();
  if ( scalar(@{$hash->{relation}}) > 12 ) {
    warn "diff_route *** ref:$ref trop de relations nb:".scalar(@{$hash->{relation}});
    print "diff_route *** ref:$ref trop de relations";
    $self->{'log'} .= "\tdiff_routes() *** trop de relations\n";
    print "\n\n\n";
    for my $relation ( @{$hash->{relation}} ) {
#      confess Dumper $relation;
    }
    return;
  }
  $self->relations_route_gtfs();
  warn "diff_route() ref:$ref fin";
}
#
# comparaison des relations type=route avec gtfs
sub star_relations_route_gtfs {
  my $self = shift;
#  my $hash = $self->oapi_get("relation[network=fr_star][type=route][route=bus];out meta;", "$self->{cfgDir}route_bus.osm");
  warn "relations_route_gtfs() debut nb relations:" . scalar(@{$hash->{relation}});
  if ( scalar(@{$hash->{relation}}) == 0 ) {
    $self->relations_route_gtfs_create();
    return;
  }
  my $i_relation = 0;
  foreach my $relation (sort @{$hash->{relation}}) {
    $i_relation++;
    warn sprintf("\n\nrelations_route_gtfs() ref:%s;%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp});
    $self->star_relation_route_gtfs($relation, $i_relation);
  }
#
# on crée les relations inexistantes
  $self->star_relations_route_gtfs_create();
  warn "relations_route_gtfs() fin";
}
#
# création des relations à partir des données gtfs
sub relations_route_gtfs_create {
  my $self = shift;
  warn "relations_route_gtfs_create() debut";
#  confess Dumper $gtfs_iti;
  my $osm = '';
  for my $iti ( sort keys %{$gtfs_iti} ) {
#    confess Dumper $gtfs_iti->{$iti};
    if ( defined $gtfs_iti->{$iti}->{id_relation} ) {
      next;
    }
    if ( $gtfs_iti->{$iti}->{nb} < $self->{seuil} ) {
      next;
    }
    if ($self->{mode} !~ m{relation_create} ) {
      confess "relations_route_gtfs_create()"
    }
    warn "relations_route_gtfs_create() $iti  $gtfs_iti->{$iti}->{nb} seuil:$self->{seuil}";
    next;
#    confess Dumper $gtfs_iti->{$iti};
    $osm = $self->{oOSM}->relation_route_bus($gtfs_iti->{$iti});
    my @trip = @{$gtfs_iti->{$iti}->{'trip'}};
#    confess Dumper \@trip;
    my $members = "";
    for my $stop ( @trip ) {
      my $stop_id = $stop->{stop_id};
      my $n = $self->osm_nodes_bus_stop_ref( $stop_id );
#        confess Dumper $n;
      my $id = $n->{id};
      $members .= sprintf('    <member type="node" ref="%s" role="platform"/>' ."\n", $id);
    }
    $osm =~ s{(\s*</relation>)}{$members$1};
#    confess $osm;
    $self->{oAPI}->changeset($osm, $self->{source}, 'create');
#    $osm .= $gtfs_iti->{$iti}->{osm};
#    warn $osm;
#
  }
  warn "relations_route_gtfs_create() fin";
}
#
# recherche de la correspondance gtfs osm
# on utilise le champ to
sub star_relation_route_gtfs {
  my $self = shift;
  my $relation = shift;
  my $i_relation = shift;
#  confess Dumper $gtfs_iti;
  warn sprintf("relation_route_gtfs() r%s;%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp});
#  confess Dumper $relation_stops->{$relation};
  my ( $i, @nodes, @nodes_ref, @stops, $arrets, @refs);
  $i = 0;
  @nodes = ();
  @nodes_ref = ();
  if ( not defined $relation_stops->{$relation} ) {
    warn "relation_route_gtfs() *** pas de node";
    warn Dumper $relation;
    if ( defined $relation->{tags}->{to} ) {
      warn "relation_route_gtfs() *** to:" . $relation->{tags}->{to};
      $nodes[0] = 'from';
      $nodes[1] =  $relation->{tags}->{to};
    }
    if ( scalar(@nodes) == 0 && defined $relation->{tags}->{direction} ) {
      warn "relation_route_gtfs() *** direction:";
      $nodes[0] = 'from';
      $nodes[1] =  $relation->{tags}->{direction};
    }
  }
  for my $node ( @{$relation_stops->{$relation}} ) {
    $i++;
    $arrets->{$i}->{node} = $node;
    if ( ! defined $node->{tags}->{ref} && defined $node->{tags}->{$self->{k_ref}}) {
#      warn "bus_stop() n$node->{id} *** k_ref $node->{tags}->{name} " . $node->{tags}->{$self->{k_ref}};
      $node->{tags}->{ref} = $node->{tags}->{$self->{k_ref}};
    }
#    warn "relation_route_gtfs() $i node:" . $node->{tags}->{name};
    push @nodes, $node->{tags}->{name};
    push @nodes_ref, $node->{tags}->{ref};
  }
  warn "relation_route_gtfs() nodes:" . join(";", @nodes);
  warn "relation_route_gtfs() nodes:" . join(";", @nodes_ref);
#  warn Dumper $relation->{tags};
  warn sprintf("relation_route_gtfs() from: %s to: %s", $relation->{tags}->{from}, $relation->{tags}->{to});
  if ( defined $relation->{tags}->{to} ) {
    if ( name_norm($relation->{tags}->{to}) ne name_norm($nodes[-1]) ) {
      warn 'relation_route_gtfs() *** to#nodes[-1] ' . $relation->{tags}->{to} . "#" . $nodes[-1];
      warn Dumper $relation->{tags};
    }
    if ( name_norm($relation->{tags}->{to}) eq name_norm($nodes[0]) ) {
      warn 'relation_route_gtfs() *** to#nodes[0] ' .$relation->{tags}->{to} . " eq " . $nodes[0];
      warn 'relation_route_gtfs() *** inverse ***' .join(",", @nodes);
      @nodes = reverse(@nodes);
    }
  }
  my $nb_nodes = $i;
#  confess Dumper $gtfs_iti;
#
  my ($osm_gtfs, $iti_ok, $itis_ok, $nb_itis);
  warn sprintf("relation_route_gtfs() ref: %s", $relation->{tags}->{'ref:FR:STAR'});
  $nb_itis = 0;
  for my $iti ( sort keys %{$gtfs_iti} ) {
    warn "relation_route_gtfs() iti:$iti";
    @stops = ();
    @refs = ();
    $i = 0;
    confess Dumper $gtfs_iti->{$iti};
    if ( defined $gtfs_iti->{$iti}->{id_relation} ) {
      warn "relation_route_gtfs() iti:$iti *** relation:";
      next;
    }
#
# normalement, on n'a plus que 2 itinéraires
    if ( $gtfs_iti->{$iti}->{nb} < 200 ) {
#      next;
    }

    for my $stop ( @{$gtfs_iti->{$iti}->{trip}} ) {
      $i++;
      $arrets->{$i}->{stop} = $stop;

#      warn "$i stop: " . $stop->{stop_name};
      push @stops, $stop->{stop_name};
      push @refs, $stop->{stop_id};
    }
    warn 'relation_route_gtfs() gtfs @stops:' . join(";", @stops);
    warn 'relation_route_gtfs() gtfs @refs:' . join(";", @refs);

    $osm_gtfs = $gtfs_iti->{$iti}->{osm};
#
# même départ et même arrivée ?
    warn sprintf('relation_route_gtfs() ref from : %s#%s to %s#%s', $nodes[0], $stops[0], $nodes[-1], $stops[-1] );
    if ( name_norm($nodes[0]) eq name_norm($stops[0]) && name_norm($nodes[-1]) eq name_norm($stops[-1]) ) {
      @{$itis_ok->{$iti}} = @stops;
      $iti_ok = $iti;
      $nb_itis++;
      next;
    }
    warn sprintf('relation_route_gtfs() ref from : %s#%s to %s#%s', $nodes_ref[0], $refs[0], $nodes_ref[-1], $refs[-1] );
    if ( $nodes_ref[0] eq $refs[0] && $nodes_ref[-1] eq $refs[-1] ) {
      warn 'relation_route_gtfs() par les ref';
      @{$itis_ok->{$iti}} = @stops;
      $iti_ok = $iti;
      $nb_itis++;
      next;
    }
    next;
    warn sprintf("relation_route_gtfs() %s # %s or %s # %s", $nodes[0], $stops[0], $nodes[-1], $stops[-1]);
    if ( name_norm($nodes[0]) eq name_norm($stops[0]) ) {
      $iti_ok = $iti;
      last;
    }
    if ( name_norm($nodes[-1]) eq name_norm($stops[-1]) ) {
      $iti_ok = $iti;
      last;
    }


#    if ( $i_relation == 1 && $nodes[-1] eq $stops[-1] ) {
#      $gtfs_iti->{$iti}->{id_relation} =  $relation->{id};
#      last;
#    }
# il faut inverser l'ordre des nodes
#    if ( $i_relation == 2 && $nodes[-1] eq $stops[0] ) {
#      $gtfs_iti->{$iti}->{id_relation} =  $relation->{id};
#      last;
#    }
  }
  if ( $nb_itis == 0 ) {
    warn "relation_route_gtfs() *** iti_ok " . $relation->{id};
#    confess;
    return;
  }
  if ( $nb_itis > 0 ) {
    my $n = scalar(@nodes);
    warn "$n;osm => " . join(";", @nodes);
    my $diff = 100;
    for my $iti ( keys %{$itis_ok} ) {
      my $n_iti = scalar(@{$itis_ok->{$iti}});
      if ( abs($n - $n_iti) < $diff ) {
        $iti_ok = $iti;
        $diff = abs($n - $n_iti);
      }
      warn "$iti => ". join(";",  @{$itis_ok->{$iti}});
    }
    warn "relation_route_gtfs() nb_itis($nb_itis) > 0 $iti_ok";
  }
  $gtfs_iti->{$iti_ok}->{id_relation} =  $relation->{id};
  my $nb_stops = scalar(@nodes);
# au moins un départ et une arrivée
  if ( $nb_stops < 2 ) {
    warn "relation_route_gtfs() *** pas assez de stops $nb_stops r" .  $relation->{id};
    return;
  }
  warn "relation_route_gtfs() nb_stops: $nb_stops nb_nodes: $nb_nodes";
  @stops = ();
  @refs = ();
  $i = 0;
  for my $stop ( @{$gtfs_iti->{$iti_ok}->{trip}} ) {
    $i++;
    $arrets->{$i}->{stop} = $stop;
#     warn "$i stop: " . $stop->{stop_name};
    push @stops, $stop->{stop_name};
    push @refs, $stop->{stop_id};
  }
  warn "nodes " .join(";", @nodes);
  warn "stops " .join(";", @stops);
  warn "refs " .join(";", @refs);
#  return;
# on met en cohérence la configuration par rapport au gtfs
# la partie tags
  if ($self->{mode} eq 'relation_tags') {
#    confess Dumper $osm_gtfs;
    my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
#    confess Dumper  $osm_gtfs;
    my $osm = $self->{oOSM}->relation_replace_tags($relation_osm, $osm_gtfs);
    if ( ! $self->{DEBUG} ) {
      $self->{oAPI}->changeset($osm, $self->{source}, 'modify');
    } else {
      warn $osm;
    }
    return;
  }
  if ($self->{mode} !~ m{relation_node}) {
    return;
  }
# la partie node
  my $osm = '';
  my $osm_node = '';
  my $nb_ok = 0;
  my $nb_ordre = 0;
  my $osm_ref = '';
  my $nb_ref = 0;
  $nb_stops = scalar(@stops);
  $nb_nodes = scalar(@nodes);
  $self->{DEBUG} = 1;
  for $i ( 1 .. $nb_stops ) {
    if ( ! $arrets->{$i}->{stop}->{stop_name} or $arrets->{$i}->{stop}->{stop_name} =~ m{^\s*$} ) {
      confess "relation_route_gtfs() name absent";
    }
    my $stop_name = name_norm($arrets->{$i}->{stop}->{stop_name});
    my $stop_ref = $arrets->{$i}->{stop}->{stop_id};
# recherche dans les nodes de la relation
    my $i_node = 0;
    for my $j ( 1 .. $nb_nodes ) {
#      confess Dumper $arrets->{$j}->{node}->{tags};
      my $node_name = name_norm($arrets->{$j}->{node}->{tags}->{name});
      my $node_ref = $arrets->{$j}->{node}->{tags}->{ref};
      if ( ! defined $node_ref ) {
        $node_ref = $arrets->{$j}->{node}->{tags}->{$self->{k_ref}};
      }
#      warn "bus_stop() n$node->{id} *** k_ref $node->{tags}->{name} " . $node->{tags}->{$self->{k_ref}};

#      warn "node $j " . $arrets->{$j}->{node}->{tags}->{ref} . " $node_name";
      if ( $stop_ref eq $node_ref ) {
        $i_node = $j;
        last;
      }
      if ( $stop_name eq $node_name && $stop_ref eq $node_ref ) {
        $i_node = $j;
        last;
      }
    }
#    warn "stops $i $i_node $stop_ref $stop_name"; exit;
# on l'a trouvé ?
    if ( $i_node > 0 ) {
      if ( $self->{DEBUG} > 1 ) {
        warn "node === name:" . $arrets->{$i}->{stop}->{stop_name} . " $i # " . $i_node . " ref:" . $arrets->{$i}->{stop}->{stop_id} . " n" . $arrets->{$i_node}->{node}->{id};
      }
      $nb_ok++;
      if ( $i_node == $i ) {
        $nb_ordre++;
      }
# meme ref
      my $id = '';
      if ( defined $arrets->{$i_node}->{node}->{tags}->{ref}
        && $arrets->{$i_node}->{node}->{tags}->{ref} eq $arrets->{$i}->{stop}->{stop_id}
        && $arrets->{$i_node}->{node}->{tags}->{'highway'} eq 'bus_stop'
      ) {
        $id = $arrets->{$i_node}->{node}->{id};
      } else {
        warn "osm: " . $arrets->{$i_node}->{node}->{tags}->{ref} . " gtfs " . $arrets->{$i}->{stop}->{stop_id};
        warn Dumper $arrets->{$i_node}->{node};
        confess;
# modification du tag, très mauvaise idéee
#        my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $arrets->{$i_node}->{node}->{id}));
#        my $tags;
#        $tags->{ref} = $arrets->{$i}->{stop}->{stop_id};
#        $osm_ref .= $self->{oOSM}->modify_tags($node_osm, $tags, qw(ref)) . "\n";

        my $n = $self->osm_nodes_bus_stop_ref( $arrets->{$i}->{stop}->{stop_id} );
#        confess Dumper $n;
        $id = $n->{id};
        $nb_ref++;
      }
#      confess Dumper $arrets->{$i_node}->{node};
      $osm .= '    <member type="node" ref="' . $id . '" role="platform"/>' . "\n";
      next;
    }
#    confess Dumper $arrets->{$i}->{stop};
# on recherche le node avec cette référence
    warn "node recherche node " . $arrets->{$i}->{stop}->{stop_name} . ", " . $arrets->{$i}->{stop}->{stop_id};
    my $ok = 0;
    my $n = $self->osm_nodes_bus_stop_ref( $arrets->{$i}->{stop}->{stop_id} );
    if ( $n ) {
      my $id = $n->{id};
      $nb_ref++;
      $osm .= '    <member type="node" ref="' . $id . '" role="platform"/>' . "\n";
      $ok = 1;
    }

    if ( $ok == 0 ) {
#      confess Dumper $arrets->{$i}->{stop};
      $osm_node .= $self->{oOSM}->node_stop($arrets->{$i}->{stop});
    }
  }
  warn "relation_route_gtfs() nb_stops: $nb_stops nb_nodes: $nb_nodes nb_ordres: $nb_ordre nb_ok: $nb_ok nb_ref:$nb_ref";
  $self->{'log'} .= "relation_route_gtfs() ref:" . $relation->{tags}->{ref}  .  " iti:$iti_ok ref:$self->{network}:" . $relation->{tags}->{"ref:fr_star"}  . " r" . $relation->{id} . "\n";
  $self->{'log'} .= "relation_route_gtfs() " . "nb_stops: $nb_stops nb_nodes: $nb_nodes nb_ordres: $nb_ordre nb_ok: $nb_ok nb_ref:$nb_ref" . "\n";
#
# forcage de la ref dans les nodes
#  if ( $nb_ok == $nb_stops  && $nb_stops == $nb_nodes && $nb_ordre == $nb_stops && $osm_ref ne '' ) {
#    $self->{oAPI}->changeset($osm_ref, 'maj Keolis septembre 2014', 'modify');
#  }
#  return;
  if ( $nb_ok == $nb_stops  && $nb_stops == $nb_nodes && $nb_ordre == $nb_stops && $nb_ref == 0) {
    warn "\n\n\n*** identiques ref:" . $relation->{tags}->{ref}. " r" . $relation->{id}. "\n\n\n";
    print "ok " . $relation->{tags}->{ref} . " r" . $relation->{id} .   "\n";
    warn sprintf("relation_route_gtfs() fin");
    $self->{'log'} .= "relation_route_gtfs() identiques fin\n";
    return 0;
  }
  print "*** " . $relation->{tags}->{ref} . "\n";
  $self->{oAPI}->changeset($osm_node, $self->{osm_commentaire}, 'create');
  warn sprintf("relation_route_gtfs() ref:%s;%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp});
  if ( $osm ne '' ) {
    my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
    $osm = $self->{oOSM}->relation_replace_member($relation_osm, '<member type="node" ref="\d+" role="[^"]*"/>', $osm);
    if ( $osm !~ m{<relation} ) {
      confess "relation_route_gtfs() $relation_osm";
    }
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');
    $self->{'log'} .= "relation_route_gtfs() ***delta\n";
  }
  warn sprintf("relation_route_gtfs() fin");
#  confess;
  return 1;
}

1;