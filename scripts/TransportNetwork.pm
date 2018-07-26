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
sub create_network {
  my $self = shift;
  warn "create_network() debut";
  my $osm = $self->{oOSM}->relation_public_transport_network();
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'create');
}
sub valid_network {
  my $self = shift;
  my $network = $self->{network};
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
    my $osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation',$hash_network->{relation}[0]->{id} ));
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