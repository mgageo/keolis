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
#  $self->replace_relation_route_member_platform($osm->{id}, $osm_members);
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
  confess;
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