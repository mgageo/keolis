# <!-- coding: utf-8 -->
#
# les traitements sur la relation route_master
#
# - différence avec le gtfs
#
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
use LWP::Simple;
#
our ($hash, $gtfs_routes);
#
# vérification des relations type=route_master
# - par rapport à OSM
# -- les relations membres
# -- une seule relation par ref
# - par rapport à GTFS
#
#
# pour les lignes
sub liste_routes_master {
  my $self = shift;
  warn "valid_routes_master()";
  my $network = $self->{network};
  my $hash_route_master = $self->oapi_get("relation[network='${network}'][type=route_master];out meta;", "$self->{cfgDir}/relation_routes_master.osm");
  my $hash_route = $self->oapi_get("relation[network='${network}'][type=route][route=bus];out meta;", "$self->{cfgDir}/relation_routes_bus.osm");
  my $hash_disused = $self->oapi_get("relation[network='${network}'][type=route]['disused:route'=bus];out meta;", "$self->{cfgDir}/relation_disused_route_bus.osm");
  foreach my $relation (sort tri_tags_ref  @{$hash_route_master->{relation}}) {
    my @routes = get_relation_tag_ref($hash_route, $relation->{tags}->{ref});
    my @lines = get_relation_tag_ref($hash_disused, $relation->{tags}->{ref});
    warn "liste_routes_master() ref:" . $relation->{tags}->{ref} . " id: " . $relation->{id} . " nb_routes:" . scalar(@routes) . " nb_disuseds:" . scalar(@lines);
  }
}
sub ref_routes_master {
  my $self = shift;
  warn "ref_routes_master()";
  my $network = $self->{network};
  my $hash_route_master = $self->oapi_get("relation[network='${network}'][type=route_master];out meta;", "$self->{cfgDir}/relation_routes_master.osm");
  my $osm = '';
  foreach my $relation (sort tri_tags_ref  @{$hash_route_master->{relation}}) {
    if ( defined $relation->{tags}->{'ref:FR:STAR'} ) {
      next;
    }
    warn "ref_routes_master() ref:" . $relation->{tags}->{ref} . " id: " . $relation->{id};
    my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
    my $tags;
    $tags->{'ref:FR:STAR'} =  sprintf("%04d", $relation->{tags}->{ref});
    $osm .= $self->{oOSM}->modify_tags($relation_osm, $tags, qw(ref:FR:STAR)) . "\n";
  }
  $self->{oAPI}->changeset($osm, "ajout ref:FR:STAR", 'modify');
}
#
# la comparaison avec le gtfs
sub diff_routes_master {
  my $self = shift;
  warn "diff_routes_master()";
  my $network = $self->{network};

  my $hash_route_master = $self->oapi_get("relation[network='${network}'][type=route_master][route_master=bus];out meta;", "$self->{cfgDir}/relation_routes_master.osm");
# on indexe par ref
  my $refs;
  my $k_ref = $self->{k_ref};
  foreach my $relation (sort @{$hash_route_master->{relation}}) {
    if ( defined $refs->{$relation->{tags}->{$k_ref}} ) {
      warn "diff_routes_master() *** r" . $refs->{$relation->{tags}->{ref}}->{id} . ",r" . $relation->{id};
      next;
    }
    $refs->{$relation->{tags}->{$k_ref}} = $relation;
  }
  $self->{oDB}->table_select('star_lignes');
  my $star_lignes = $self->{oDB}->{table}->{'star_lignes'};
  my $star_routes;
  for my $ligne ( @{$star_lignes} ) {
    my $k = sprintf("%04d", $ligne->{'id'});
    $star_routes->{$k} = $ligne;
  }
  my $osm = '';
  my $osm_create = '';
  my $star_refs;
  my @deleted_keys = qw(text_color);
  my $deleted_keys = join('|', @deleted_keys);
  for my $ref (sort tri_ref keys %{$star_routes}) {
    if ( $ref =~ m{^Ts\d+} ) {
      next;
    }
 # le métro
    if ( $ref =~ m{^(a)$}i ) {
      next;
    }
    $star_refs->{$ref}++;
    if ( not defined $refs->{$ref} ) {
      print "\ndiff_routes_master() ref:$ref ";
#      $osm_create .= $self->{oOSM}->relation_route_master($star_routes->{$ref});
      next;
    }
    my $tags;
#    confess Dumper  $star_routes->{$ref};
    $tags->{"public_transport:version"} =  "2";
    $tags->{description} =  $star_routes->{$ref}->{nomlong};
    $tags->{name} =  "Bus Rennes Ligne " . $star_routes->{$ref}->{nomcourt};
    $tags->{text_colour} =  uc($star_routes->{$ref}->{couleurtexteligne});
    $tags->{colour} = uc($star_routes->{$ref}->{couleurligne});
    $tags->{text_colour} =~ s{[\x00-\x1F]}{}g;
    $tags->{'ref:FR:STAR'} =  sprintf("%04d", $star_routes->{$ref}->{id});
    my $ko = 0;
    my $relation = $refs->{$ref};
    for my $tag (sort keys %{$tags} ) {
      if ( $relation->{tags}->{$tag} ne $tags->{$tag} ) {
        $ko++;
        warn "diff_routes_master() *** $tag r" . $relation->{id} . "\n osm:" . $relation->{tags}->{$tag}. "--\ngtfs:" . $tags->{$tag} . '--';
        last;
      }
    }
    if ( $ko > 0 ) {
      my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
      $tags->{description} = xml_escape($tags->{description});
      $tags->{'source'} = $self->{source};
      $relation_osm = $self->{oOSM}->delete_tags($relation_osm, $deleted_keys);
      $osm .= $self->{oOSM}->modify_tags($relation_osm, $tags, keys %{$tags}) . "\n";
#      warn Dumper $star_routes->{$ref};exit;
    }
  }
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');
#  $self->{oAPI}->changeset($osm_create, $self->{osm_commentaire}, 'create');
}
#
# pour créer une relation "route_master"
sub route_master_creer {
  my $self = shift;
  $self->{oDB}->table_select('star_lignes');
  my $star_lignes = $self->{oDB}->{table}->{'star_lignes'};
  my $lignes;
  for my $ligne ( @{$star_lignes} ) {
    $lignes->{$ligne->{'id'}} = $ligne;
  }
  if ( not defined $lignes->{$self->{ref}} ) {
    confess "route_master_creer() ligne:$self->{ref}";
  }
  my $ligne = $lignes->{$self->{ref}};
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
  $tags->{description} =  $ligne->{nomlong};
  $tags->{name} =  "Bus Rennes Ligne " . $ligne->{nomcourt};
  $tags->{text_colour} =  uc($ligne->{couleurtexteligne});
  $tags->{colour} = uc($ligne->{couleurligne});
  $tags->{text_colour} =~ s{[\x00-\x1F]}{}g;
  $tags->{'ref:FR:STAR'} =  sprintf("%04d", $ligne->{id});
  $tags->{description} = xml_escape($tags->{description});
  $tags->{'source'} = $self->{source};
  $osm = $self->{oOSM}->modify_tags($osm, $tags, keys %{$tags}) . "\n";
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'create');
}
#
# la comparaison avec le gtfs
sub diff_routes_master_gtfs {
  my $self = shift;
  warn "diff_routes_master()";
  my $network = $self->{network};

  my $hash_route_master = $self->oapi_get("relation[network='${network}'][type=route_master][route_master=bus];out meta;", "$self->{cfgDir}/relation_routes_master.osm");
# pour annuler un changeset malheureux
  if ( 1 == 2 ) {
    my $osm_double = '';
    foreach my $relation (sort @{$hash_route_master->{relation}}) {
      if ( $relation->{changeset} ne '26775367' ) {
        next;
      }
#    my $osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id} ));
      $osm_double .= $self->{oOSM}->relation_delete($relation);
    }
    $self->{oAPI}->changeset($osm_double, 'maj Keolis novembre 2014', 'delete');
    exit;
  }
# on indexe par ref
  my $refs;
  foreach my $relation (sort @{$hash_route_master->{relation}}) {
    if ( defined $refs->{$relation->{tags}->{ref}} ) {
      warn "diff_routes_master() *** r" . $refs->{$relation->{tags}->{ref}}->{id} . ",r" . $relation->{id};
      next;
    }
    $refs->{$relation->{tags}->{ref}} = $relation;
  }
  my $gtfs_routes = $self->gtfs_routes_get();
  my $osm = '';
  my $osm_create = '';
  my $gtfs_refs;
  for my $ref (sort tri_ref keys %{$gtfs_routes}) {
    if ( $ref =~ m{^Ts\d+} ) {
      next;
    }
 # le métro
    if ( $ref =~ m{^(a)$}i ) {
      next;
    }
    $gtfs_refs->{$ref}++;
    if ( not defined $refs->{$ref} ) {
      print "\ndiff_routes_master() ref:$ref ";
      $osm_create .= $self->{oOSM}->relation_route_master($gtfs_routes->{$ref});
      next;
    }
    my $tags;
#    confess Dumper  $gtfs_routes->{$ref};
    $tags->{description} =  $gtfs_routes->{$ref}->{route_long_name};
    $tags->{name} =  "Bus Rennes Ligne " . $gtfs_routes->{$ref}->{route_short_name};
    $tags->{text_coulor} =  $gtfs_routes->{$ref}->{route_text_color};
    $tags->{colour} = '#' . $gtfs_routes->{$ref}->{route_color};
    $tags->{'ref:FR:STAR'} =  $gtfs_routes->{$ref}->{route_id};
    my $ko = 0;
    my $relation = $refs->{$ref};
    for my $tag (sort keys %{$tags} ) {
      if ( $relation->{tags}->{$tag} ne $tags->{$tag} ) {
        $ko++;
        warn "diff_routes_master() *** $tag r" . $relation->{id} . "\n osm:" . $relation->{tags}->{$tag}. "--\ngtfs:" . $tags->{$tag} . '--';
        last;
      }
    }
    if ( $ko > 0 ) {
      my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
      $tags->{description} =   xml_escape($gtfs_routes->{$ref}->{route_long_name});
      $osm .= $self->{oOSM}->modify_tags($relation_osm, $tags, qw(name description text_color colour)) . "\n";
#      warn Dumper $gtfs_routes->{$ref};exit;
    }
  }
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');
#  $self->{oAPI}->changeset($osm_create, $self->{osm_commentaire}, 'create');
  return;
#
# les route_master qui ne sont plus actives
  $osm = '';
  foreach my $relation (sort @{$hash_route_master->{relation}}) {
    if ( defined $gtfs_refs->{$relation->{tags}->{ref}} ) {
      next;
    }
    if ( $relation->{tags}->{ref} =~ m{^Ts\d+} ) {
      next;
    }
    if ( $relation->{tags}->{ref} =~ m{^a$}i ) {
      next;
    }
    warn "diff_routes_master() *** ref:" . $relation->{tags}->{ref} . ", r" . $relation->{id};
    my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
    $osm .= $self->{oOSM}->relation_disused($relation_osm);
  }
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');
  $self->{oAPI}->changeset($osm_create, $self->{osm_commentaire}, 'create');
  return;
#
# on passe aux relations
  my $hash_route = $self->oapi_get("relation[network=${network}][type=route][route=bus];out meta;", "$self->{cfgDir}/relation_routes.osm");
#
# les route_master qui ne sont plus actives
  $osm = '';
  foreach my $relation (sort @{$hash_route->{relation}}) {
    if ( defined $gtfs_refs->{$relation->{tags}->{ref}} ) {
      next;
    }
    if ( $relation->{tags}->{ref} =~ m{^Ts\d+} ) {
      next;
    }
    if ( $relation->{tags}->{ref} =~ m{^a$}i ) {
      next;
    }
    warn "diff_routes_master() *** ref:" . $relation->{tags}->{ref} . ", r" . $relation->{id};
    my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
    $osm .= $self->{oOSM}->relation_disused($relation_osm);
  }
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');

}
#
# pour les différentes lignes
sub valid_routes_master {
  my $self = shift;
  my $gtfs_routes = $self->gtfs_routes_get();
  for my $ref (sort tri_ref keys %{$gtfs_routes}) {
    if ( $ref =~ m{^(11|70|223|33)$} ) {
 #     next;
    }
    if ( $ref =~ m{^(Ts\d+)$} ) {
      next;
    }
    if ( $ref =~ m{^2\d\d$} ) {
      next;
    }
    if ( $ref =~ m{^R$} ) {
      next;
    }
    if ( $ref !~ m{^11$} ) {
#      next;
    }
    print "valid_routes_master() ref:$ref ";
    $self->{ref} = $ref;
    my $rc = $self->valid_route_master();
    if ( $rc != 0 ) {
      print "***rc:$rc\n";
    } else {
      print "ok \n";
    }
  }
}
# pour une ligne
sub valid_route_master {
  my $self = shift;
  my $ref = $self->{ref};
  my $network = $self->{network};

  warn "valid_route_master() ref:$ref";
  my $hash_route_master = $self->oapi_get("relation[network='${network}'][type=route_master][route_master=bus][ref='$ref'];out meta;", "$self->{cfgDir}/relation_route_master_${ref}.osm");;
  if ( scalar( @{$hash_route_master->{relation}} ) != 1 ) {
    warn "valid_route_master() *** ref:$ref 0 relation route_master";
    return -1;
  }
  my $hash_route = $self->oapi_get("relation[network='${network}'][type=route][route=bus][ref='$ref'];out meta;", "$self->{cfgDir}/relation_route_bus_${ref}.osm");
  my $ko = 0;
  if ( not defined $hash_route_master->{relation}[0]->{member} ) {
    warn "valid_route_network() *** ref:$ref member";
    $ko = -2;
  }
  my $hash_disused = $self->oapi_get("relation[network='${network}'][type=route]['disused:route'=bus][ref='$ref'];out meta;", "$self->{cfgDir}/relation_disused_route_bus_${ref}.osm");
  if ( $ko == 0 ) {
    for my $member ( @{$hash_route_master->{relation}[0]->{member}} ) {
      if ( $member->{type} ne 'relation' ) {
        next;
      }
      my $relation = find_relation($member->{ref}, $hash_route);
      if ( defined $relation->{tags}->{ref} ) {
        warn "valid_route_master() r" . $relation->{id} . " ref:star " .$relation->{tags}->{'ref:star'};
        next;
      }
      warn "valid_route_master() ref: " . $member->{ref};
      $ko++;
    }
  }
  if ( $ko == 0) {
    warn "valid_route_master() ok $ref";
    return 0;
  }
  if ( scalar(@{$hash_route->{relation}}) == 0 ) {
    warn "valid_route_master() pas de route";
    return -4;
  }
  warn "valid_route_master() ko $ref\n";
  my $osm_member = '';
  for my $relation ( @{$hash_route->{relation}} ) {
#    confess Dumper $relation;
    $osm_member .= '  <member type="relation" ref="' . $relation->{id} . '" role=""/>' . "\n";
  }
  warn  "valid_route_master() osm_member " . $osm_member;
  my $osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation',$hash_route_master->{relation}[0]->{id} ));
  $osm =  $self->{oOSM}->relation_replace_member($osm, '<member type="relation" ref="\d+" role=""/>', $osm_member);
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');
  return $ko;
  foreach my $relation (sort tri_tags_ref  @{$hash_route_master->{relation}}) {
    my @routes = get_relation_tag_ref($hash_route, $relation->{tags}->{ref});
    my @lines = get_relation_tag_ref($hash_disused, $relation->{tags}->{ref});
    warn "valid_route_master() ref:" . $relation->{tags}->{ref} . " nb_routes:" . scalar(@routes) . " nb_lines:" . scalar(@lines);
    $hash =  $hash_route;
    for my $relation ( @routes ) {
      my @nodes = display_relation_route_member_node($relation);
      warn "valid_route_master() routes nodes ".join(";", @nodes);
    }
    $hash =  $hash_disused;
    for my $relation ( @lines ) {
      my @nodes = display_relation_route_member_node($relation);
    }
  }
}
sub relations_route_master {
  my $self = shift;
  warn "relations_route_master() debut";
#
# une seule relation par ref
# on mémorise les membres de chaque relation
  my ($relation_ref, $ref, @double, $relation_member, $osm, $osm_member);
  foreach my $relation (sort @{$hash->{relation}}) {
    warn sprintf("relations_route_master() ref:%s;%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp});
    if ( not defined $relation->{tags}->{ref} ) {
      confess;
    }
    $ref = $relation->{tags}->{ref};
    if ( defined $relation_ref->{$ref} ) {
      push @double, $relation->{id};
      if ( defined $relation->{member} ) {
        push @{$relation_member->{$ref}}, @{$relation->{member}};
      }
      next;
    }
    $relation_ref->{$ref} = $relation->{id};
#    confess Dumper $relation;
  }
  for $ref (sort keys %{$relation_ref} ) {
#    warn "relations_route_master() double ref:$ref";
    if ( not defined $relation_member->{$ref} ) {
      next;
    }
    my $osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation_ref->{$ref} ));
#    warn $osm;
    $osm_member .= osm_modify_members($osm, $relation_member->{$ref});
  }
  warn "relations_route_master() ref en double :" . Dumper @double;
  if ( scalar(@double) > 100 ) {
#
# suppression des relations en double
# - d'abord dans la relation network
    my $osm_network = get('http://api.openstreetmap.org/api/0.6/relation/1744131');
    $osm_network = osm_delete_members($osm_network, @double);
    $self->{oAPI}->changeset($osm_network, 'maj Kéolis juillet 2014');
# - puis les relations
    my $osm_double = '';
    for my $id ( @double ) {
      warn "relations_route_master() double id:$id";
      my $osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $id ));
      $osm_double .= osm_delete($osm);
    }
    warn $osm_double;
    $self->{oAPI}->changeset($osm_double, 'maj Kéolis juillet 2014', 'delete');
  }
#
# les ref de gtfs qui ne sont pas dans osm
  $osm = '';
  my $id = 0;
  for $ref (sort keys %{$gtfs_routes} ) {
    if ( defined $relation_ref->{$ref} ) {
      next;
    }
    $id--;
    $osm .= sprintf('
  <relation id="%s" version="1">
    <tag k="colour" v="#%s"/>
    <tag k="description" v="%s"/>
    <tag k="name" v="Bus Rennes Ligne %s"/>
    <tag k="network" v="${network}"/>
    <tag k="operator" v="STAR"/>
    <tag k="ref" v="%s"/>
    <tag k="route_master" v="bus"/>
    <tag k="service" v="busway"/>
    <tag k="text_color" v="#%s"/>
    <tag k="type" v="route_master"/>
  </relation>' , $id, $gtfs_routes->{$ref}->{route_color}, xml_escape($gtfs_routes->{$ref}->{route_long_name}), $ref, $ref, $gtfs_routes->{$ref}->{route_text_color});
#    confess Dumper $gtfs_routes->{$ref};
    warn "relations_route_master() gtfs_routes ref:$ref";
  }
  warn "relations_route_master() gtfs_routes \n" . $osm; return;
  $self->{oAPI}->changeset($osm, 'maj Kéolis juillet 2014', 'create');
  return;
#  warn $osm_member;
#  $self->{oAPI}->changeset($osm_member, 'maj Kéolis juillet 2014');
#
# la comparaison gtfs
  foreach my $relation (@{$hash->{relation}}) {
    my $ref = $relation->{tags}->{ref};
    if ( ! defined $gtfs_routes->{$ref} ) {
      warn sprintf("relations_route_master() *** inc %s ref:%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp});
      next;
    }
#	confess Dumper $gtfs_routes->{$ref};
    my $color = $gtfs_routes->{$ref}->{route_color};
    $color = "#" . uc($color);
    if ( ! defined  $relation->{tags}->{colour} ) {
      warn sprintf("relations_route_master() *** colour $color %s ref:%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp});
      next;
    }
    my $colour = $relation->{tags}->{colour};
    if ( $color ne $relation->{tags}->{colour} ) {
      warn sprintf("relations_route_master() *** colour $colour<>$color %s ref:%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp});
      next;
    }
#	last;
  }
}

#
# pour mettre à jour les relations "route_master"
sub routes_master_diff {
  my $self = shift;
  warn "routes_master_diff() debut";
  $self->masters_lire();
  my $hash = $self->oapi_get("relation[network='$self->{network}'][type=route_master][route_master=bus];out meta;", "$self->{cfgDir}/routes_master_diff.osm");
  my $level0 = '';
# on indexe par ref
  my $refs;
  foreach my $relation (@{$hash->{relation}}) {
    $refs->{$relation->{tags}->{ref}} = $relation;
    warn sprintf("ksma_routes_master_diff() r%s ;ref:%s;%s;%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp}, scalar(@{$relation->{nodes}}), scalar(@{$relation->{ways}}));
    $level0 .= 'r' . $relation->{id} . ',';
    $self->{id} = $relation->{id};
    $self->{'tags'}->{'ref'} = $relation->{tags}->{ref};
    $self->{'ref'} = $relation->{tags}->{ref};
#    $self->ksma_route_master_diff();
    $self->valid_route_master();
  }
  chop $level0;
  warn "routes_master_diff() level0: $level0";
  foreach my $ref (sort keys %{$self->{masters}} ) {
    warn $ref;
    if ( defined $refs->{$ref} ) {
      next;
    }
    $self->{relation_id}--;
    my $iti = $self->{masters}->{$ref};
#  warn Dumper $iti;
    my $format = <<'EOF';
  <relation id="%s" timestamp="0" changeset="1" version="1">
    <tag k="description" v="%s"/>
    <tag k="name" v="Bus %s Ligne %s"/>
    <tag k="network" v="%s"/>
    <tag k="operator" v="%s"/>
    <tag k="ref" v="%s"/>
    <tag k="route_master" v="bus"/>
    <tag k="service" v="busway"/>
    <tag k="type" v="route_master"/>
    <tag k="colour" v="%s"/>
    <tag k="text_color" v="%s"/>
    <tag k="source" v="%s"/>
  </relation>
EOF
    my $osm = sprintf($format, $self->{relation_id}, xml_escape($iti->{name}), $self->{name}, $ref, $self->{network}, $self->{operator}, $ref, $iti->{bg}, $iti->{fg}, $self->{source});
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'create');
  }
}
#
# vérification des itinéraires des relations route_master
sub relations_route_master_iti {
  my $self = shift;
# le rapprochement avec les relations membre
  foreach my $relation (@{$hash->{relation}}) {
#    confess Dumper $relation;
    relation_route_master($relation);
#	last;
  }
}
#
# vérification d'une relation type=route_master
# - par rapport à OSM
# -- relation membre dans plusieurs relations
# -- way membre
# -- tags avec relation membre
# fait hériter ref network operator
our ( $relation_members );
sub relation_route_master {
  my $self = shift;
  my $relation = shift;
#	confess Dumper $relation->{tags};
  warn sprintf("relation_route_master %s ref:%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp});
# vérification des membres
  my $osm = '';
  foreach my $member (@{$relation->{member}}) {
#    confess Dumper $member;
# type=way => une route
    if ( $member->{type} eq 'way' ) {
      warn sprintf("*** MEMBER %s", $member->{type});
      next;
    }
# type=relation => une route
    if ( $member->{type} eq 'relation' ) {
      if ( defined $relation_members->{$member->{ref}} ) {
        warn sprintf("MEMBERS *** %s %s %s", $relation->{id}, $member->{ref}, $relation_members->{$member->{ref}});
        next;
      }

      $relation_members->{$member->{ref}} = $relation->{id};
#      warn sprintf("MEMBERS %s %s", $relation->{id}, $member->{ref});
#      next;
#      warn sprintf("\%s", $member->{ref});
#	  my $member_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s/full", $member->{type}, $member->{ref}));
      my $member_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", $member->{type}, $member->{ref}));
#	  confess Dumper $member_osm;
      my $member_hash = osm2hash($member_osm);
#	  confess Dumper $member_hash;
# la réponse ne doit comporter qu'une relation
      my $member_relation = $member_hash->{relation}[0];
      if ( not defined $member_relation->{tags}->{ref}
           or not defined $member_relation->{tags}->{network}
           or not defined $member_relation->{tags}->{operator}
        ) {
        $osm .= osm_modify_tags($member_osm, $relation->{tags}, qw(ref network operator)) . "\n";
#        confess $osm;
        next;
      }
      warn sprintf("MEMBER %s ref:%s;%s;%s", $member_relation->{id}, $member_relation->{tags}->{ref}, $member_relation->{user}, $member_relation->{timestamp});
# les tags en commun doivent être identiques
      foreach my $tag (sort keys %{$member_relation->{tags}} ) {
        if ( $tag =~ m{(type)} ) {
          next;
        }
        if ( defined $relation->{tags}->{$tag} ) {
          if ($relation->{tags}->{$tag} eq $member_relation->{tags}->{$tag} ) {
            next;
          }
          warn  $tag . "=> " . $relation->{tags}->{$tag} ."#". $member_relation->{tags}->{$tag};
        }
      }
      next;
    }
# type non pris en compte
    confess Dumper $member;
  }
  if ( $osm ne '' ) {
#    confess $osm;
    if ( ! $self->{DEBUG} ) {
#      $self->{oAPI}->changeset($osm, 'maj Keolis septembre 2014', 'modify');
    } else {
      warn $osm;
    }
#    exit;
  }
}
#
# pour supprimer les disused:route_master
sub disused_route_master_delete {
  my $self = shift;
  my $network = "fr_" . $self->{network};
  warn "disused_route_master_delete() debut";
  my $hash = $self->oapi_get("relation[network=${network}]['disused:route_master'='bus'];out meta;", "$self->{cfgDir}/disused_route_master_delete.osm");
  my $osm = '';
  warn "disused_route_master_delete() nb:" . scalar(@{$hash->{relation}});
  foreach my $relation (@{$hash->{relation}}) {
#    confess Dumper $relation;
    warn "disused_route_master_delete() ref:" . $relation->{tags}->{ref};
    $osm = $self->{oOSM}->relation_delete($relation);
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' supression disused', 'delete');
#    last;
  }
}
#
# la partie wfs
#
# comparaison des relations type=route avec wfs
sub relations_route_master_wfs {
  my $self = shift;

  my $wfs_routes = $self->wfs_routes_get();
#  warn Dumper $wfs_routes;
  my $hash_routes = $self->oapi_get("(relation[network=". $self->{network} . "][type=route_master]['route_master'='bus']);out meta;", "$self->{cfgDir}/route_master_bus.osm");
  my $tags_wfs = {
    source => $self->{source}
  };
  my %ref;
  my $level0 = '';
  foreach my $relation (sort tri_tags_ref @{$hash_routes->{relation}}) {
    warn sprintf("relations_route_master_wfs() r%s;ref:%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp});
    if ( not defined $wfs_routes->{$relation->{tags}->{ref}} ) {
      warn "\t hors wfs";
      $level0 .= ",r". $relation->{id};
      next;
    }
    $ref{$relation->{tags}->{ref}}++;
    my $wfs_route = $wfs_routes->{$relation->{tags}->{ref}};
    $tags_wfs->{'network'} = 'fr_illenoo';
    my $nom = $wfs_route->{'NOM_LIGNE'};
    $nom =~ s{[\r\n\a].*}{}gsm;
    $tags_wfs->{'description'} = $nom;
    my $osm_relation = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
#    warn $osm_relation;
    my $hash = $self->{oOSM}->osm2hash($osm_relation);
#    confess Dumper $hash;
    my $osm = $self->{oOSM}->modify_tags($osm_relation, $tags_wfs, qw(network description));
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');
  }
  for my $id ( sort keys %{$wfs_routes} ) {
    if ( defined $ref{$id} ) {
      next;
    }
    warn "id:$id";
    my $osm = $self->{oOSM}->relation_route_master_wfs($wfs_routes->{$id});
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'create');;
  }
}
#
# pour les différentes lignes
sub valid_routes_master_wfs {
  my $self = shift;
  my $wfs_routes = $self->wfs_routes_get();
  for my $ref (sort tri_ref keys %{$wfs_routes}) {
    print "valid_routes_master_wfs() ref:$ref ";
    $self->{ref} = $ref;
    my $rc = $self->valid_route_master();
    if ( $rc != 0 ) {
      warn "valid_routes_master_wfs() ***rc:$rc";
    } else {
      print "ok \n";
    }
#    last;
  }
}
1;