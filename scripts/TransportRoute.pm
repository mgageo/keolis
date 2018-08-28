# <!-- coding: utf-8 -->
#
# les traitements sur la relation route
#
# - différence avec le gtfs
# - validation avec remplacement des nodes
#
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
use LWP::Simple;
our ($ref, $hash);
#
# pour trouver les relations "route" avec un contenu non significatif, moins de 5 ways
sub supprime_route_vide {
  my $self = shift;
  my $network = $self->{network};
  warn "supprime_route_vide() debut";
#  my $hash = $self->oapi_get("area[name='Saint-Malo'];(relation[network!~'fr_'][type=route][route=bus](area));out meta;", "$self->{cfgDir}/route_vide.osm");
  my $hash = $self->oapi_get("relation[network='$network'][type=route][route=bus];out meta;", "$self->{cfgDir}/route_vide.osm");
  my $level0 = '';
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
    if ( scalar(@{$relation->{nodes}}) > 3 ) {
      next:
    }
    if ( scalar(@{$relation->{ways}}) > 5 ) {
      next:
    }
#    warn sprintf("supprime_route_vide() r%s ;ref:%s;%s;%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp}, scalar(@{$relation->{nodes}}), scalar(@{$relation->{ways}}));
    $level0 .= 'r' . $relation->{id} . ',';
    $self->{id} = $relation->{id};
    $self->{'tags'} = $relation->{tags};
    $self->gpx_relation_ways();

#    confess Dumper $relation;
  }
  chop $level0;
  warn "supprime_route_vide() level0: $level0";
}
#
# pour trouver les relations "route" avec une référence network
sub ref_network_routes {
  my $self = shift;
  warn "ref_network_routes() debut";
  my $network = $self->{network};
  my $net = $network;
  $net =~ s{^fr_}{};
  my $hash = $self->oapi_get("relation[network='$network'][type=route][route=bus]['ref:$net'];out meta;", "$self->{cfgDir}/ref_network_routes.osm");
  my $osm = $self->{oOAPI}->{osm};
  $osm =~ s{.*?(<relation)}{$1}sm;
  $osm =~ s{</osm>.*}{}sm;
  $osm =~ s{ref:$net}{ref:$network}gsm;
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' modification tag ref:$net', 'modify');
  warn "ref_network_routes() fin";
}



#
# la validation des données OSM
sub valid_relation {
  my $self = shift;
  my $osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s/full", 'relation', $ref));
#  confess $osm;
  $hash = osm2hash($osm);
  relations_route();
}
#
# vérification des relations type=route
# on en profite pour constituer la liste des stops
our $relation_stops;
sub relations_route {
  my $self = shift;
  warn "relations_route() debut";
  foreach my $relation (sort @{$hash->{relation}}) {
    warn sprintf("relations_route() r%s;ref:%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp});
#    confess Dumper $relation;
    if ( not defined $relation->{member} ) {
      next;
    }
#    confess Dumper @{$relation->{member}};
# vérification du type des nodes
    for my $member ( @{$relation->{member}} ) {
      if ( $member->{type} ne 'node' ) {
        next;
      };
      if ( $member->{role} !~ m{platform} ) {
        next;
      };
#      warn Dumper $member;
      my $node = find_node($member->{ref}, $hash);
      my $ ok = 0;
      if ( defined $node->{tags}->{'highway'} ) {
        if ( $node->{tags}->{'highway'} eq 'mini_roundabout' ) {
          next;
        }
        if ( $node->{tags}->{'highway'} ne 'bus_stop' ) {
          warn "relations_route() highway#bus_stop ";
          warn Dumper $node;
          warn Dumper $member;
        }
        $ok = 1;
#        next:
      }
      if ( defined $node->{tags}->{'public_transport'} ) {
        if ( $node->{tags}->{'public_transport'} !~ m{(platform|stop_position)} ) {
          warn "relations_route() public_transport " . Dumper $node;
        }
        $ok = 1;
#        next:
      }
      if ( $ok == 0 ) {
        warn "relations_route() ok: $ok " . Dumper $node;
        exit;
      }
      push @{$relation_stops->{$relation}}, $node;
    }
#   warn Dumper $relation_stops->{$relation};
#   confess Dumper $relation;
    if ( defined  $relation_stops->{$relation} ) {
      warn sprintf("relations_route() %s;%s;%s", scalar(@{$relation_stops->{$relation}}), $relation_stops->{$relation}[0]->{tags}->{name}, $relation_stops->{$relation}[-1]->{tags}->{name});
    } else {
      warn "relations_route() pas de node";
    }
  }
  warn "relations_route() fin";
}


sub test_osm_bus_stop_around {
  my $self = shift;
  my( $ok, $i, $arrets, $osm);
    my $h = osm_bus_stop_around($arrets->{$i}->{stop}->{stop_lat}, $arrets->{$i}->{stop}->{stop_lon}, 50 );
# pas de réponse
    if ( scalar( @{$h->{node}} ) == 0 ) {
#      confess Dumper $arrets->{$i}->{stop};
#      $osm_node .= $self->{oOSM}->node_stop($arrets->{$i}->{stop});
    }
    foreach my $node (sort @{$h->{node}}) {
      if ( not defined  $node->{tags}->{name} ) {
        next;
      }
      if ( not defined  $node->{tags}->{ref} ) {
        next;
      }
      if ( $node->{tags}->{name} eq $arrets->{$i}->{stop}->{stop_name}
        and $node->{tags}->{ref} eq  $arrets->{$i}->{stop}->{stop_id}
      ) {
        warn "node around " . $node->{tags}->{name} . ", " . $node->{tags}->{ref};
        $osm .= '    <member type="node" ref="' . $node->{id} . '" role="platform"/>' . "\n";
        $ok++;
        last;
      }
#      confess Dumper $node;
    }
}
#
# recherche des nodes highway=bus_stop proche d'un point
sub osm_bus_stop_around {
  my $self = shift;
  my ( $lat, $lon ) = @_;
  my $distance = 5;
  if( @_ ) {
    $distance = shift;
  }
  if ( not $self->{oOAPI} ) {
    $self->{oOAPI} = new OsmOapi();
  }
  my $oapi = sprintf("node(around:${distance},%s,%s)[highway=bus_stop];out meta;", $lat, $lon);
  warn $oapi;
  my $osm = $self->{oOAPI}->get($oapi);
#  warn $osm;
  my $hash = osm2hash($osm);
#  warn Dumper $hash;
  return $hash;
}
sub toto {
  my $self = shift;
  my ( $i, @nodes, @stops, $arrets);

# http://www.perlmonks.org/?node_id=919422
  my %presence;
  my $b = 1;
  foreach my $a (\@stops, \@nodes) {
    foreach(@$a) {
      $presence{name_norm($_)} |= $b;
    }
    $b *= 2;
  }
  my @nodes_only = grep { $presence{$_} == 2 } keys %presence;
  my @stops_only = grep { $presence{$_} == 1 } keys %presence;
  if ( ( scalar(@nodes_only) + scalar(@stops_only) ) != 0) {
    warn "relation_route_gtfs() *** delta nodes " . $nodes[0] . " => " . $nodes[-1];
    warn "relation_route_gtfs() *** delta stops " . $stops[0] . " => " . $stops[-1];
    warn "nodes_only\n" . join(";", @nodes_only) . "\n";
    warn "stops_only\n" . join(";", @stops_only) . "\n";
    warn "nodes\n" . join(";", @nodes) . "\n";
    warn "stops\n" . join(";", @stops) . "\n";
#    confess Dumper $relation;
#    exit;
#
    if ( ( scalar(@nodes_only) + scalar(@stops_only) ) < 8) {
#      warn Dumper $arrets;
    }
# même nombre d'arrêts
    if ( scalar(@nodes_only) == scalar(@stops_only) ) {
#      warn Dumper $arrets;
      for $i ( 1 .. scalar(keys %{$arrets}) ) {
        if ( $arrets->{$i}->{stop}->{stop_name} eq $arrets->{$i}->{node}->{tags}->{name} ) {
          next;
        }
        warn "i:$i name:" . $arrets->{$i}->{stop}->{stop_name} . " # " . $arrets->{$i}->{node}->{tags}->{name};
        warn Dumper $arrets->{$i}->{node};
      }
    }
    return;
  }
#
# on vérifie la ref du node
  my ( $tags, $osm );
  $osm = '';
  for $i ( 1 .. scalar(keys %{$arrets}) ) {
    if ( name_norm($arrets->{$i}->{stop}->{stop_name}) ne name_norm($arrets->{$i}->{node}->{tags}->{name}) ) {
      warn "i:$i name:" . $arrets->{$i}->{stop}->{stop_name} . " # " . $arrets->{$i}->{node}->{tags}->{name};
      confess;
    }
    if ( not defined $arrets->{$i}->{node}->{tags}->{ref} ) {
      my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node',$arrets->{$i}->{node}->{id}));
      $tags->{ref} = $arrets->{$i}->{stop}->{stop_id};
      $osm .= $self->{oAPI}->modify_tags($node_osm, $tags, qw(ref)) . "\n";
#      warn $osm;
#      confess Dumper  $arrets->{$i};
      next;
    }
    if ( $arrets->{$i}->{stop}->{stop_id} ne $arrets->{$i}->{node}->{tags}->{ref} ) {
      warn "i:$i name:" . $arrets->{$i}->{stop}->{stop_name} . " # " . $arrets->{$i}->{node}->{tags}->{name};
      warn "i:$i ref:" . $arrets->{$i}->{stop}->{stop_id} . " # " . $arrets->{$i}->{node}->{tags}->{ref};
      warn "i:$i node_id: " .  $arrets->{$i}->{node}->{id};
#    confess Dumper  $arrets->{$i};
    }
  }
}
#
# la partie wfs
#
# comparaison des relations type=route avec wfs
sub relations_route_wfs {
  my $self = shift;

  my $wfs_routes = $self->wfs_routes_get();
#  warn Dumper $wfs_routes;
  my $hash_network = $self->oapi_get("(relation[network=fr_". $self->{network} . "][type=route]['route'='bus']);out meta;", "$self->{cfgDir}/route_bus.osm");
  my $level0 = '';
  my $tags_wfs = {
    source => $self->{source}
  };
  my %ref;
  foreach my $relation (sort tri_tags_ref @{$hash_network->{relation}}) {
    warn sprintf("relations_route_wfs() r%s;ref:%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp});
    if ( not defined $wfs_routes->{$relation->{tags}->{ref}} ) {
      warn "\t hors wfs";
      $level0 .= ",r". $relation->{id};
      next;
    }
    $ref{$relation->{tags}->{ref}}++;
    next;
    my $wfs_route = $wfs_routes->{$relation->{tags}->{ref}};
#    warn Dumper $wfs_route;
    my $nom = $wfs_route->{'NOM_LIGNE'};
    $nom =~ s{[\r\n\a].*}{}gsm;
    print "nom:$nom\n";
    $tags_wfs->{'name'} = $nom;
    my $osm_relation = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
#    warn $osm_relation;
    my $hash = $self->{oOSM}->osm2hash($osm_relation);
#    confess Dumper $hash;
    my $osm = $self->{oOSM}->modify_tags($osm_relation, $tags_wfs, qw(name source));
#    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');
#    delete $wfs_routes->{$relation->{tags}->{ref}};
#    last;
  }
  for my $id ( sort keys %{$wfs_routes} ) {
    if ( defined $ref{$id} ) {
      next;
    }
    warn "id:$id";
    my $osm = $self->{oOSM}->relation_route_wfs($wfs_routes->{$id});
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'create');;
  }
}
#
# pour mettre à jour des tags
sub relation_routes_tags {
  my $self = shift;
  my $hash_network = $self->oapi_get("(relation[network=". $self->{network} . "][type=route]['route'='bus']);out meta;", "$self->{cfgDir}/routes_tags.osm");
  my $level0 = '';
  $self->masters_lire();
  my $tags = {
    source => $self->{source}
  };
  my %ref;
  foreach my $relation (sort tri_tags_ref @{$hash_network->{relation}}) {
    warn sprintf("relation_routes_tags() r%s;ref:%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp});
    my $osm_relation = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
#    warn $osm_relation;
    my $hash = $self->{oOSM}->osm2hash($osm_relation);
#    confess Dumper $hash->{relation}[0]->{tags};
    my $t = $hash->{relation}[0]->{tags};
    my $ref = $t->{ref};
    if ( not defined $self->{masters}->{$ref} ) {
      confess "relation_routes_tags() *** ref:$ref";
    }
    my $nom = $self->{name} . $t->{ref} . " " .  $t->{name};
#    warn $nom;
    $tags->{'name'} = $nom;
    $tags->{colour} =  $self->{masters}->{$ref}->{fg};
    $tags->{bgcolor} =  $self->{masters}->{$ref}->{bg};
#    my $osm = $self->{oOSM}->modify_tags($osm_relation, $tags, qw(name source));
    my $osm = $self->{oOSM}->modify_tags($osm_relation, $tags, qw(colour bgcolor));
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');
  }
}
#
# analyse des members d'une relation route
sub relation_routes_members {
  my $self = shift;
  my $hash = $self->oapi_get("relation[network='". $self->{network} . "'][type=route]['route'='bus'];out meta;", "$self->{cfgDir}/routes_platform.osm");
  foreach my $relation (sort tri_tags_ref @{$hash->{relation}}) {
    my $k_ref = $relation->{tags}->{$self->{k_ref}};
    if ($k_ref !~ m{^0[1]} ) {
      next;
    }
    warn sprintf("relations_route_members() r%s ref:%s %s %s", $relation->{id}, $k_ref, $relation->{user}, $relation->{timestamp});
#    next;
    $self->{id} = $relation->{id};
    $self->relation_route_members();
  }
}
sub relation_route_members {
  my $self = shift;
  my $id = $self->{'id'};
  warn "relation_route_members() id:$id";
  my $hash = $self->api_get('relation', $id);
#  confess Dumper $hash;
  my $relation = $hash->{relation}[0];
  my (@stop, @platform, @way, $nodes);
#  confess Dumper $relation;
  for my $member ( @{$relation->{member}} ) {
    if ( $member->{role} =~ m{^stop} ) {
      push @stop, $member;
      next;
    }
    if ( $member->{role} =~ m{^platform} ) {
      push @platform, $member;
      next;
    }
    if ( $member->{role} =~ m{^$} ) {
      push @way, $member;
      my $id = $member->{ref};
      my $way = $hash->{osm}->{way}->{$id};
#      confess Dumper $way;
      for my $node ( @{$way->{nodes}} ) {
        $nodes->{$node}++;
      }
      next;
    }
    confess Dumper $member;
  }
  warn sprintf("relation_route_members() stop:%s platform:%s way:%s nodes:%s", scalar(@stop), scalar(@platform), scalar(@way), scalar(keys %{$nodes}));
  for my $member ( @stop ) {
    if ( defined $nodes->{$member->{ref}} ) {
      next;
    }
    warn "***stop # parcours";
    warn Dumper $member;
    my $id = $member->{ref};
    my $node = $hash->{osm}->{node}->{$id};
    warn Dumper $node;
  }
# https://gis.stackexchange.com/questions/11409/calculating-the-distance-between-a-point-and-a-virtual-line-of-two-lat-lngs
# une plateforme n'appartient pas au parcours
  for my $member ( @platform ) {
    my $id = $member->{ref};
    my $node = $hash->{osm}->{node}->{$id};
    if ( defined $nodes->{$member->{ref}} ) {
      warn "***platform";
      warn Dumper $member;
      warn Dumper $node;
      next;
    }
    my $distance = 10000;
    for my $id (keys %{$nodes} ) {
      my $node1 = $hash->{osm}->{node}->{$id};
      my $d = haversine_distance_meters($node->{lat}, $node->{lon}, $node1->{lat}, $node1->{lon});
      if ( $d < $distance ) {
        $distance = $d;
      }
    }
    if ($distance > 150 ) {
      warn "***platform $distance";
      warn Dumper $member;
      warn Dumper $node;
      next;
    }
  }
#  confess "***fin***";
}
sub api_get {
  my $self = shift;
  my ($type, $id) = @_;
  my $f_osm = sprintf("%s/%s_%s.osm", $self->{cfgDir}, $type, $id);
#  warn "api_get() f_osm: ". $f_osm;
  my ($osm);
#  $f_osm = "$self->{cfgDir}/relations_routes.osm";
  if ( ! -f "$f_osm" or  $self->{DEBUG_GET} > 0 ) {
    my $get = sprintf("https://www.openstreetmap.org/api/0.6/%s/%s/full", $type, $id);
#    warn $get;
    $osm = get($get);
    open(OSM, ">:utf8",  $f_osm) or die "osm_get() erreur:$!";
    print(OSM $osm);
    close(OSM);
  } else {
    $osm = do { open my $fh, '<:utf8', $f_osm or die $!; local $/; <$fh> };
  }
#  confess $osm;
  my $hash = $self->{oOSM}->osm2hash($osm);
  warn "api_get() $f_osm nb_r:" . scalar(@{$hash->{relation}}) . " nb_w:" . scalar(@{$hash->{way}}) . " nb_n:" . scalar(@{$hash->{node}});
  return $hash;
}
sub hexdump {
  my $data = shift;
  my ($hex, $char);
  $hex=$char='';
  foreach (split (//,$data)){
    $hex  .= sprintf('%02X ', ord($_));
    $char .= ord($_) > 13 ? $_ : ".";
  }
  return $hex;
}
#
# générer le code wiki d'un réseau, version ksma
sub wiki_routes {
  my $self = shift;
  warn "wiki_routes() debut";
#  $self->ksma_masters();
#  my $hash = $self->oapi_get("area[name='Saint-Malo'];(relation[network!~'fr_'][type=route][route=bus](area));out meta;", "$self->{cfgDir}/route_vide.osm");
  my $hash = $self->oapi_get("relation[network='$self->{network}'][type=route][route=bus];out meta;", "$self->{cfgDir}/network_wiki.osm");
#  my $hash = $self->oapi_get("relation[network='$self->{network}'][type=route_master][route_master=bus];out meta;", "$self->{cfgDir}/network_wiki.osm");
  my $wiki = <<'EOF';
==Les routes==
{|class="wikitable sortable"
|-
!scope="col"| Ligne
!scope="col" class="unsortable"| Nom
!scope="col" class="unsortable"| Direction
!scope="col" class="unsortable"| Statut
!scope="col" class="unsortable"| Notes
EOF
  foreach my $relation (sort tri_tags_ref @{$hash->{relation}}) {
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
    if ( $self->{DEBUG} > 0 ) {
      warn sprintf("wiki_routes() r%s ;ref:%s;%s;%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp}, scalar(@{$relation->{nodes}}), scalar(@{$relation->{ways}}));
    }
    my $id = $relation->{id};
    my $ref = $relation->{tags}->{ref};
#    my $ref_network = $relation->{tags}->{'ref:ksma'};
#    if ( $ref_network !~ m{\-[ABCD]$} ) {
#      next;
#    }
    my $network = $relation->{tags}->{network};
    my $to = $relation->{tags}->{to};
    my $name = $relation->{tags}->{name};
    my $fg = $relation->{tags}->{text_colour};
    my $bg = $relation->{tags}->{colour};
    $wiki .= <<EOF;
|-
!scope="row"| {{Sketch Line|$ref|$network|bg=$bg|fg=$fg}}
| $name
| {{Relation|$id| $name : Direction $to}}
| ||
EOF
  }
  $wiki .= <<EOF;
|}
EOF
  my $dsn = "$self->{cfgDir}/routes_wiki.txt";
  open(TXT, '>:utf8', $dsn);
  print TXT $wiki;
  warn "wiki_routes() fin $dsn";
}
sub route_stops_get {
  my $self = shift;
  my $relation = shift;
  my $shape = shift;
#  warn "diff_trip() debut";
  $self->get_relation_route_member_stops($relation);
#  confess Dumper $relation;
}
sub get_relation_route_member_node {
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
#      warn Dumper $member;
    my $node = find_node($member->{ref});
    if ( not defined $node->{tags}->{'highway'} ) {
      warn Dumper $node;
    }
    if ( $node->{tags}->{'highway'} ne 'bus_stop' ) {
      warn Dumper $node;
    }
#      warn Dumper $node;
    push @nodes,  $node->{tags}->{'name'};
  }
  return @nodes;
}
sub get_relation_route_member_stops {
  my $self = shift;
  my $relation = shift;
#  confess Dumper $relation;
  my @nodes = ();
  my $nodes_ref = '';
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
#      warn Dumper $member;
    my $node = find_node($member->{ref}, $self->{hash_route});
    if ( not defined $node->{tags}->{'highway'} and not defined  $node->{tags}->{'public_transport'}) {
      warn "get_relation_route_member_nodes() highway " . $member->{ref};
#      warn Dumper $node;
#      next;
    }
    if (defined $node->{tags}->{'highway'} and $node->{tags}->{'highway'} ne 'bus_stop' ) {
      warn "get_relation_route_member_nodes() highway bus_stop " . $member->{ref};
#      warn Dumper $node;
    }
#    warn Dumper $node;
    push @nodes,  $node;
    $ref = '';
    if ( defined $node->{'tags'}->{'ref:FR:STAR'} ) {
      $ref = $node->{'tags'}->{'ref:FR:STAR'};
    }
#    warn "ref:$ref";
    $nodes_ref .= "$ref,";
  }
  chop $nodes_ref;
#  warn $nodes_ref;
#  confess Dumper \@nodes;
  return $nodes_ref;
}
# pour mettre à jour les tags
sub routes_tags_maj {
  my $self = shift;
  warn "routes_tags_maj() début";
#  my $hash = $self->oapi_get("relation[network='$self->{network}'][type=route][route=bus];out meta;", "$self->{cfgDir}/routes_tags_maj.osm");
  my $hash = $self->oapi_get("relation[network='$self->{network}'][type=route_master][route_master=bus];out meta;", "$self->{cfgDir}/routes_tags_maj.osm");
  my $osm = '';
  my $nb_osm = 0;
  my $tags = {
    'public_transport:version' => '2',
    'website' => 'https://www.reseau-mat.fr/',
    'operator' => 'Keolis Saint-Malo',
    'source' => $self->{source}
  };
  my %tags;
  for my $relation ( @{$hash->{relation}} ) {
    my $nb_deleted = 0;
    my $nb_absent = 0;
    my $nb_diff = 0;
    for my $tag ( keys %{$relation->{tags}} ) {
      $tags{$tag}++;
    }
    for my $tag ( keys %{$tags} ) {
      if ( not defined $relation->{tags}->{$tag} ) {
        warn "routes_tags_maj() absent $relation->{id} tag:$tag";
#        warn Dumper $relation;
        $nb_absent++;
        next;
      }
      if ( $relation->{tags}->{$tag} != $tags->{$tag} ) {
        warn "routes_tags_maj() diff $relation->{id} tag:$tag";
#        warn Dumper $relation;
        $nb_diff++;
        next;
      }
    }
    if ($nb_absent == 0 && $nb_diff == 0) {
      next;
    }
    warn "routes_tags_maj() $relation->{id}  absent $nb_absent == 0 diff $nb_diff == 0";
    $nb_osm++;
    my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
    $relation_osm = $self->{oOSM}->modify_tags($relation_osm, $tags, keys %{$tags});
#    confess $relation_osm;
    $osm .= $relation_osm . "\n";
#    last;
    if ( $nb_osm > 10 ) {
#      last;
    }
#    confess Dumper $osm;
  }
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . " mise a jour des tags", 'modify');
  warn "routes_tags_maj() fin $nb_osm";
}
1;