# <!-- coding: utf-8 -->
#
# les traitements sur la relation network
#
#
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
use LWP::Simple;
#
# mise à jour de l'attribut network sur les node
sub network_node_maj {
  my $self = shift;
  my $network = $self->{network};
  my @deleted_keys = qw(source network operator);
  my $ql = <<EOF;
area[name='Bretagne']->.a;(
  relation(area.a)[type=route][route=bus][network='$network'];
)->.r;
.r >> ->.n;
(node.n[highway=bus_stop];node.n[public_transport];)->.s;
(.r;.s;);out meta;
EOF
  my $hash = $self->oapi_get($ql, "$self->{cfgDir}/relation_network.osm");
  my $osm_modify = '';
  my $nb = scalar(@{$hash->{node}});
  my $i = 0;
  for my $node ( @{$hash->{node}} ) {
    $i++;
    warn "$i $nb";
    my $tags = $node->{tags};
    my $t = {};
    my $ko = 0;
    my $dk = 'source|network|operator';
    while ( my ($k, $v) = each %{$tags} ) {
      if ( $k =~ m{(source|network|operator)} ) {
        next;
      }
      if ( $k !~ m{illenoo} ) {
#        $t->{$k} = $v;
        next;
      }
#      confess Dumper $node;
      $dk .= "|$k";
      $k =~ s{_}{:};
      $k =~ s{^FR}{fr};
      $t->{$k} = $v;
      $ko++;
    }
    if ( $ko == 0 ) {
      next;
    }
 #   confess Dumper $t;
#    $dk = substr($dk, 1);
#    warn $dk;

    my $osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{id}));
    $osm = $self->{oOSM}->delete_tags($osm, $dk);
    my $osm1 = $self->{oOSM}->modify_tags($osm, $t, keys %{$t});
#    confess $osm1;
    if ( $osm1 =~ /fr_illenoo/ ) {
      warn Dumper $osm;
      warn Dumper $osm1;
      confess Dumper $t;
    }
    $osm_modify .= "$osm1\n";
  }
#  confess $osm_modify;
  $self->{oAPI}->changeset($osm_modify, $self->{osm_commentaire} . ' changement network', 'modify');
}
#
# mise à jour de l'attribut network sur les relations
# perl scripts/keolis.pl --DEBUG 0 --DEBUG_GET 1 illenoo network_relation_maj
# perl scripts/keolis.pl --DEBUG 0 --DEBUG_GET 1 vitre network_relation_maj
# perl scripts/keolis.pl --DEBUG 0 --DEBUG_GET 1 chateaubourg network_relation_maj
# perl scripts/keolis.pl --DEBUG 0 --DEBUG_GET 1 rmat network_relation_maj
# perl scripts/keolis.pl --DEBUG 0 --DEBUG_GET 1 star network_relation_maj
# perl scripts/keolis.pl --DEBUG 0 --DEBUG_GET 1 breizhgo network_relation_maj
# perl scripts/keolis.pl --DEBUG 0 --DEBUG_GET 1 dinardbus network_relation_maj
sub network_maj {
  my $self = shift;
  my $network = $self->{network};
  my $ql = <<EOF;
area[name='Bretagne']->.a;
(
  relation(area.a)[type=route][route=bus][network='$network'] -> .itineraries;
  .itineraries > -> .stops_and_ways;
  .itineraries << -> .lines;
);out meta;
EOF
  my $hash = $self->oapi_get($ql, "$self->{cfgDir}/network_maj.osm");
  my $osm_modify = '';
  my $nb = scalar(@{$hash->{relation}});
  my $i = 0;
  warn "$i $nb";
  for my $relation ( @{$hash->{relation}} ) {
    $i++;
    warn "$i $nb";
    my $tags = $relation->{tags};
    my $t = {};
    my $ko = 0;
    my $dk = 'source';
    while ( my ($k, $v) = each %{$tags} ) {
      if ( $k =~ m{(source)} ) {
        next;
      }
      if ( $k =~ m{^ref\:(fr\:|fr_)} ) {
        $dk .= "|$k";
        $k =~ s{_}{:};
        $k =~ s{fr\:}{FR:};
        $t->{$k} = $v;
        $ko++;
        next;
      }
      if ( $k eq 'network' && $v =~ m{^(fr|fr_)} ) {
        $v =~ s{_}{:};
        $v =~ s{^fr}{FR};
        $t->{$k} = $v;
        $ko++;
        next;
      }
    }
    if ( $ko == 0 ) {
      next;
    }
 #   confess Dumper $t;
#    $dk = substr($dk, 1);
#    warn $dk;

    my $osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
    $osm = $self->{oOSM}->delete_tags($osm, $dk);
    my $osm1 = $self->{oOSM}->modify_tags($osm, $t, keys %{$t});
    if ( $osm1 =~ /fr\:/ ) {
      warn Dumper $osm;
      warn Dumper $osm1;
      warn "dk: $dk";
#      confess Dumper $t;
    }
    $osm_modify .= "$osm1\n";
  }
#  confess $osm_modify;
  $self->{oAPI}->changeset($osm_modify, $self->{osm_commentaire} . ' changement network', 'modify');
}
#
# création de la relation network
sub create_network {
  my $self = shift;
  warn "create_network() debut";
  my $osm = $self->{oOSM}->relation_public_transport_network();
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'create');
}
#
# ajout des route_master en membre de la relation network
sub valid_network {
  my $self = shift;
  my $network = $self->{network};
  my @deleted_keys = qw(text_color source operator);
  my $deleted_keys = join('|', @deleted_keys);
  warn "valid_network() debut";
  my $hash_network = $self->oapi_get("relation[network='${network}'][type=network];out meta;", "$self->{cfgDir}/relation_network.osm");
#  confess Dumper $hash_network;
# une seule relation
  if ( scalar(@{$hash_network->{relation}}) != 1 ) {
    confess "valid_network()*** nb relations # 1";
  }
  if ( not defined $hash_network->{relation}[0]->{member} ) {
    warn "valid_network() *** pas de member";
  }
  my $hash_route_master = $self->oapi_get("relation[network='${network}'][type=route_master];out meta;", "$self->{cfgDir}/relation_routes_master.osm");
  my $hash_route = $self->oapi_get("relation[network='${network}'][type=route][route=bus];out meta;", "$self->{cfgDir}/relation_routes_bus.osm");
#  confess Dumper $hash_route_master;
  my $members;
#  confess Dumper  @{$hash_network->{relation}[0]->{member}};
  for my $member ( @{$hash_network->{relation}[0]->{member}} ) {
    if ( $member->{type} ne 'relation' ) {
      next;
    }
    $members->{$member->{ref}}++;
    my $relation = find_relation($member->{ref}, $hash_route_master);
    if ( defined $relation->{tags}->{ref} ) {
      next;
    }
    my $relation = find_relation($member->{ref}, $hash_route);
    if ( defined $relation->{tags}->{ref} ) {
      next;
    }
    warn "valid_network() inconnu r" . $member->{ref};
  }
  warn "valid_network() nb_members : " . scalar(keys(%{$members}));
  my $osm_member = '';
#  foreach my $relation (sort tri_tags_ref  @{$hash_route->{relation}}) {
  my $ko = 0;
  foreach my $relation (sort tri_tags_ref  @{$hash_route_master->{relation}}) {
#    warn "valid_network() ref:" . $relation->{tags}->{ref} . " id: " . $relation->{id};
# que si on a des routes avec cette référence
    my @routes = get_relation_tag_ref($hash_route, $relation->{tags}->{ref});
    if ( scalar(@routes) < 1 ) {
     warn "valid_network() master sans route " . $relation->{tags}->{ref};
      next;
    }
    if ( not defined $members->{$relation->{id}} ) {
      $ko++;
    }
    $osm_member .= sprintf('   <member type="relation" ref="%s" role=""/>'."\n", $relation->{id});
  }
  warn "valid_network() ko:$ko nb_members : " . scalar(keys(%{$members}));
#  confess $osm_member;
  if ( $ko > 0 ) {
    my $osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $hash_network->{relation}[0]->{id} ));
    $osm = $self->{oOSM}->relation_replace_member($osm, '<member type="relation" ref="\d+" role=""/>', $osm_member);
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');
  }
}
#
# force le tag network
sub tags_network {
  my $self = shift;
  my $network = $self->{network};
  warn "valid_network() debut";
  my $tags_network = {
    'network' => $network,
    'source' => $self->{source}
  };
  my $hash_network = $self->oapi_get("relation[network=${network}][type=network];out meta;", "$self->{cfgDir}/relation_network.osm");
#  confess Dumper $hash_network;
# une seule relation
  if ( scalar(@{$hash_network->{relation}}) != 1 ) {
    confess "tags_network() nb relations";
  }
  if ( not defined $hash_network->{relation}[0]->{member} ) {
    warn "tags_network() *** pas de member";
  }
  my @members = @{$hash_network->{relation}[0]->{member}};
  foreach my $member ( @members ) {
#    confess Dumper $member;
    if ( $member->{type} ne "relation" ) {
      next;
    }
    my $relation_osm = $self->{oAPI}->get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $member->{ref} ));
    if ( $relation_osm =~ m{$network} ) {
      next;
    }
    my $osm = $self->{oOSM}->modify_tags($relation_osm, $tags_network, qw(network source));
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');
#    last;
  }
}

1;