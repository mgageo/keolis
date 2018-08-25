# <!-- coding: utf-8 -->
#
# les infostarions du Réseau Malo Agglomération Transport
# http://www.star.fr/fileadmin/Sites/star/documents/timeo/Liste_des_codes_TIMEO_hiver_au_2604.pdf
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
#
# pour les stops : diffrénce entr osm et l'open data
#
#  ref:FR:STAR =
sub star_nodes_stops_diff {
  my $self = shift;
  warn "star_nodes_stops_diff() debut";
  my $table = 'star_pointsarret';
  my $network = $self->{network};
  my $hash_node = $self->{oOAPI}->osm_get("node['public_transport'='platform']['name']['$self->{k_ref}'];out meta;", "$self->{cfgDir}/star_relations_platform.osm");
  my $hash_stop = $self->{oOAPI}->osm_get("node(area:3602005861)['highway'='bus_stop'];out meta;", "$self->{cfgDir}/star_relations_bus_stop.osm");

  $self->{oDB}->table_select($table, '', 'ORDER BY code');
  my $osm_create = '';
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
    $self->{stops}->{$ref}->{osm} = $node;
  }
  warn "star_nodes_stops_diff() indexation star";
  for my $row ( @{$self->{oDB}->{table}->{$table}} ) {
    my $ref = $row->{'code'};
    $self->{stops}->{$ref}->{star} = $row;
  }
  for my $ref ( sort keys %{$self->{stops}} ) {
    if ( defined $self->{stops}->{$ref}->{osm} ) {
      next;
    }
    if ( $ref =~ m{^[4569]} ) {
      next;
    }
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
  $self->{oAPI}->changeset($osm_create, 'maj Keolis aout 2018', 'create');
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
#mise à jour de la relation route à partir des données open data
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
1;