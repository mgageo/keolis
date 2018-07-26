# <!-- coding: utf-8 -->
#
# les traitements sur la relation route
#
# - différence avec les  parcours
#
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
use LWP::Simple;
#
#
# pour mettre en place "ref:star"
sub diff_parcours_v2 {
  my $self = shift;
  warn "diff_parcours() debut";
  my $table = 'star_parcours';
  my $network = $self->{network};
  my $hash_route = $self->{oOAPI}->osm_get("relation[network=${network}][type=route][route=bus];out meta;", "$self->{cfgDir}/relation_routes_bus.osm");
  $self->parcours_get($table);
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
sub parcours_ref_v2 {
  my $self = shift;
  warn "parcours_ref_v2() debut";
  my $table = 'star_parcours';
  $table = 'shapes2routes';
  my $network = $self->{network};
#  my $hash = $self->{oOAPI}->osm_get("relation[network='${network}'][type=route][route=bus];>>;out meta;", "$self->{cfgDir}/relation_routes_bus.osm");
  my $hash = $self->{oOAPI}->osm_get("relation[network='${network}'][type=route][route=bus]['ref:FR:STAR'!~'0'];>>;out meta;", "$self->{cfgDir}/relation_routes_bus.osm");
  $self->parcours_get_v2($table);
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
sub parcours_get_v2 {
  my $self = shift;
  my $table = shift;
  $self->{oDB}->table_select($table, '', 'ORDER BY shape_id');
  warn "parcours_get_v2() nb:".scalar(@{$self->{oDB}->{table}->{$table}});
}
1;