# <!-- coding: utf-8 -->
#
# les traitements sur la relation stop_area
#
# - différence avec le gtfs
# - validation avec remplacement des nodes
#
package Transport;
use utf8;
use strict;
use LWP::Simple;
#
# relations stop_area
sub stop_area {
  my $self = shift;
  $self->diff_stop_area(@_);
  $self->valid_stop_area(@_)
}
#
# différence des relations stop_area
sub diff_stop_area {
  my $self = shift;
  warn "diff_stop_area()";
  my $hash = $self->osm_relations_stop_area_get();
  my $gtfs_stops = $self->gtfs_stops_get();
# on indexe les stops par name
  my ($names, $names_norm);
  warn "diff_stop_area() indexation gtfs";
  foreach my $stop ( @{$gtfs_stops} ) {
    $stop->{stop_name} =~ s{Mendes France}{Mendès France};
    my $name = $stop->{stop_name};
    push @{$names->{$name}->{gtfs}}, $stop;
    push @{$names_norm->{name_norm($name)}->{gtfs}}, $stop;
    if (scalar(keys %{$names}) != scalar(keys %{$names_norm}) ) {
      warn $stop->{stop_name};
      last;
    }
  }
  warn "diff_stop_area() indexation nb names: " . scalar(keys %{$names});
  warn "diff_stop_area() indexation nb names_norm: " . scalar(keys %{$names_norm});
  warn "diff_stop_area() indexation osm nb_relations:" . scalar(@{$hash->{relation}});
  foreach my $node (sort @{$hash->{relation}} ) {
    my $name = '';
    my $name_norm = '';
    if ( not defined $node->{tags}->{name} ) {
        warn "diff_stop_area() indexation osm ref pas de name";
 #     warn Dumper $node;
      next;
    }
    $name = $node->{tags}->{name};
    $name_norm = name_norm($name);
    push @{$names->{$name}->{osm}}, $node;
    push @{$names_norm->{$name_norm}->{osm}}, $node;

  }
#
# on boucle par name
  my ($osm_create, $osm_delete, $nb_create, $nb_delete);
  $osm_create = '';
  $osm_delete = '';
  $nb_create = 0;
  $nb_delete = 0;
  for my $name (sort keys %{$names_norm}) {
    if ( not defined $names_norm->{$name}->{gtfs} ) {
      warn "relation delete $name";
      $nb_delete++;
      $osm_delete .= $self->{oOSM}->relation_delete($names_norm->{$name}->{osm}[0]);
      next;
    }
    if ( not defined $names_norm->{$name}->{osm} ) {
#      confess Dumper  $names->{$name};
      $nb_create++;
      warn "relation create $name";
#      confess Dumper $names_norm->{$name}->{gtfs};
      $osm_create .= $self->{oOSM}->relation_stop_area($names_norm->{$name}->{gtfs}[0]->{stop_name});
      next;
    }
  }
  warn "diff_stop_area() comparaison nb_create:$nb_create nb_delete:$nb_delete";
  $self->{oAPI}->changeset($osm_create, $self->{source}, 'create');
  $self->{oAPI}->changeset($osm_delete, $self->{source}, 'delete');
}
#
# validation des relations stop_area
sub valid_stop_area {
  my $self = shift;
  warn "valid_stop_area()";
  my $hash_bus_stop = $self->osm_get("relation[network=fr_star][route=bus];node(r);out meta;", "$self->{cfgDir}/network_node_bus.osm");
  my $hash_stop_area = $self->osm_relations_stop_area_get();
  my ($names, $names_norm);
#
# on indexe les nodes par name
  foreach my $node (sort @{$hash_bus_stop->{node}} ) {
    my $name = '';
    my $name_norm = '';
    my $ref = '';
    if ( not defined $node->{tags}->{name} ) {
      warn "valid_stop_area() indexation node pas de name n" . $node->{id};
      if ( $self->{DEBUG} > 1 ) {
      }
 #     warn Dumper $node;
      next;
    }
    if ( not defined $node->{tags}->{ref} ) {
      warn "valid_stop_area() indexation node pas de ref n" . $node->{id};
      if ( $self->{DEBUG} > 1 ) {
      }
 #     warn Dumper $node;
      next;
    }
    if ( $node->{tags}->{ref} !~ m{^\d+$} ) {
      warn "valid_stop_area() indexation node ref n" . $node->{id} . " " . $node->{tags}->{ref};
      if ( $self->{DEBUG} > 1 ) {
      }
 #     warn Dumper $node;
      next;
    }
    $name = $node->{tags}->{name};
    $name_norm = name_norm($name);
    push @{$names->{$name}->{node}}, $node;
    push @{$names_norm->{$name_norm}->{node}}, $node;
  }
#
# on indexe les relation par name
  foreach my $relation (sort @{$hash_stop_area->{relation}} ) {
    my $name = '';
    my $name_norm = '';
    my $ref = '';
    if ( not defined $relation->{tags}->{name} ) {
      if ( $self->{DEBUG} > 1 ) {
        warn "valid_stop_area() indexation relation pas de name";
      }
 #     warn Dumper $node;
      next;
    }
    $name = $relation->{tags}->{name};
    $name_norm = name_norm($name);
    push @{$names->{$name}->{relation}}, $relation;
    push @{$names_norm->{$name_norm}->{relation}}, $relation;
  }
  warn "valid_stop_area() indexation nb names: " . scalar(keys %{$names});
  warn "valid_stop_area() indexation nb names_norm: " . scalar(keys %{$names_norm});
#
# on recherche l'origine des name_norm
  for my $name (sort keys %{$names_norm} ) {
    if ( not defined $names_norm->{$name}->{relation} ) {
      next;
    }
    if ( scalar(@{$names_norm->{$name}->{relation}}) == 1 ) {
      next;
    }
    warn $name . " nb:" . scalar(@{$names_norm->{$name}->{relation}});
    for my $r ( @{$names_norm->{$name}->{relation}} ) {
      warn  "\tr" . $r->{id} . "->" . $r->{tags}->{name}
    }
#    confess Dumper  $names_norm->{$name}->{relation};
  }
#
# on boucle par name
  my $osm_member = '';
  warn "valid_stop_area() mise a jour des relations";
  for my $name (sort keys %{$names}) {
    if ( not defined $names->{$name}->{relation} ) {
      next;
    }
    if ( not defined $names->{$name}->{node} ) {
      warn "relation $name";
      next;
    }
    warn "$name";
#    confess Dumper $names->{$name}->{node};
    my $members = '';
    for my $n ( @{$names->{$name}->{node}} ) {
      $members .= sprintf('  <member type="node" ref="%s" role="platform"/>' ."\n", $n->{id});
    }
    my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation',  $names->{$name}->{relation}[0]->{id}));
    $osm_member .= $self->{oOSM}->relation_replace_member($relation_osm, '<member type="node" ref="\d+" role="platform"/>', $members) . "\n";
#    last;
  }
  $self->{oAPI}->changeset($osm_member, $self->{source}, 'modify');
}
1;