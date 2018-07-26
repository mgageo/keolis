# <!-- coding: utf-8 -->
#
# les traitements sur le node bus_stop
#

# - différence avec le gtfs
#
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
use LWP::Simple;
our ($gtfs_stops, $hash, @nodes_modif, @stops_ajout);
sub tags_bus_stop {
  my $self = shift;
  warn "tags_bus_stop() début";
  $self->{oDB}->table_select('star_pointsarret');
  my $star_stops = $self->{oDB}->{table}->{'star_pointsarret'};
  $self->{oDB}->table_select('stops');
  my $gtfs_stops = $self->{oDB}->{table}->{'stops'};
  my $hash = $self->{oOAPI}->osm_get("node['ref:FR:STAR'][public_transport=platform];out meta;", "$self->{cfgDir}/tags_bus_stop.osm");
  my $stops;
  foreach my $node ( @{$hash->{node}}) {
    if ( (! $node->{tags}->{'ref:FR:STAR'}) || $node->{tags}->{'ref:FR:STAR'} !~ m{^\d\d\d\d$}) {
      confess $node;
      next;
    }
#    confess Dumper $node;
#    warn $node->{tags}->{'ref:FR:STAR'};
    $stops->{$node->{tags}->{'ref:FR:STAR'}}->{osm} = $node;
  }
#  foreach my $stop ( @{$star_stops} ) {
#    confess Dumper $stop;
#    $stops->{$stop->{'AP_TIMEO'}}->{star} = $stop;
#  }
  foreach my $stop ( @{$star_stops} ) {
#    confess Dumper $stop;
    $stops->{$stop->{'code'}}->{star} = $stop;
  }
  foreach my $stop ( @{$gtfs_stops} ) {
#    confess Dumper $stop;
    $stops->{$stop->{'stop_code'}}->{gtfs} = $stop;
  }
#  confess;
  my $osm_modify = '';
  for my $stop ( sort keys %{$stops} ) {
    if ( not defined $stops->{$stop}->{osm} ) {
#      warn Dumper $stops->{$stop};
      next;
    }
    $hash = $stops->{$stop}->{osm};
    my $tags_star = {
#      'source' => $self->{source},
      'highway' => 'bus_stop',
      'public_transport' => 'platform',
      'public_transport:version' => '2',
      'network' => 'FR:STAR'
    };
    my $star = $stops->{$stop}->{star};
    if ( $star->{'estaccessib'} eq 'true' ) {
      $tags_star->{'wheelchair'} = 'yes';
    }
    my $ko = 0;
    foreach my $tag ( sort keys %{$tags_star} ) {
       if (not defined $hash->{tags}->{$tag}) {
        warn "$hash->{tags}->{name} *** $tag";
        $ko++;
        next;
      }
      if ($hash->{tags}->{$tag} ne $tags_star->{$tag}) {
        warn "$hash->{tags}->{name} $tag";
        $ko++;
        next;
      }
    }
    if ( $ko == 0 ) {
      next;
    }
    $tags_star->{'source'} = $self->{source};
#    warn Dumper $stops->{$stop};
#    warn Dumper $tags_star;
    my $osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $stops->{$stop}->{osm}->{id}));
    $osm = $self->{oOSM}->node_replace_tags($osm, $tags_star);
    $osm_modify .= "$osm\n";;
  }
  $self->{oAPI}->changeset($osm_modify, $self->{osm_commentaire} . ' ajout de tags', 'modify');
  warn "tags_bus_stop() fin";
}
sub tags_bus_stop_v1 {
  my $self = shift;
  warn "tags_bus_stop() début";
  my $star_stops_table = 'star_arret_physique';
  $star_stops_table = 'star_pointsarret';
  $self->{oDB}->table_select($star_stops_table);
  my $star_stops = $self->{oDB}->{table}->{$star_stops_table};
  $self->{oDB}->table_select('stops');
  my $gtfs_stops = $self->{oDB}->{table}->{'stops'};
  my $hash = $self->osm_nodes_bus_stop_get();
  my $stops;
  foreach my $node ( @{$hash->{node}}) {
    if ( (! $node->{tags}->{ref}) || $node->{tags}->{ref} !~ m{^\d\d\d\d$}) {
      next;
    }
#    confess Dumper $node;
    $stops->{$node->{tags}->{ref}}->{osm} = $node;
  }
#  foreach my $stop ( @{$star_stops} ) {
#    confess Dumper $stop;
#    $stops->{$stop->{'AP_TIMEO'}}->{star} = $stop;
#  }
  foreach my $stop ( @{$star_stops} ) {
#    confess Dumper $stop;
    $stops->{$stop->{'code'}}->{star} = $stop;
  }
  foreach my $stop ( @{$gtfs_stops} ) {
#    confess Dumper $stop;
    $stops->{$stop->{'stop_code'}}->{gtfs} = $stop;
  }
  my $osm = '';
  for my $stop ( sort keys %{$stops} ) {
    if ( not defined $stops->{$stop}->{osm} ) {
#      warn Dumper $stops->{$stop};
      next;
    }
    $hash = $stops->{$stop}->{osm};
    if ( defined $hash->{tags}->{'ref:fr_star'} ) {
#      next;
    }
    if ( 1 == 2 ) {
      if (defined $stops->{$stop}->{star}->{'AP_TYPE'} and $stops->{$stop}->{star}->{'AP_TYPE'} =~ m{^m} ) {
        next;
      }
      if ( not defined $stops->{$stop}->{star} or not defined $stops->{$stop}->{gtfs}) {
        warn "***" . $stops->{$stop}->{star}->{'AP_TYPE'};
        warn Dumper $stops->{$stop};
        next;
      }
      my $star = $stops->{$stop}->{star};
      if ( $star->{'ACCES_PMR'} eq 'OUI' ) {
        $hash->{tags}->{'wheelchair'} = 'yes';
      }
      if ( $star->{'AP_TYPE'} eq 'mobilier' ) {
        $hash->{tags}->{'shelter'} = 'yes';
      }
      if ( $star->{'BANC'} eq 'OUI' ) {
        $hash->{tags}->{'bench'} = 'yes';
      }
    }
    my $tags_star;
    if ( 2 == 2 ) {
      my $star = $stops->{$stop}->{star};
      if ( $star->{'estaccessib'} eq 'true' ) {
        $tags_star->{'wheelchair'} = 'yes';
      }
    }
    foreach my $tag ( sort keys %{$tags_star} ) {
      if (not exists  $hash->{tags}->{$tag} ) {
        warn Dumper $stops->{$stop};
      }
    }
    $hash->{tags}->{'source'} = $self->{source};
    $hash->{tags}->{'ref:fr_star'} = $stop;
    my $tags;
    foreach my $tag ( sort keys %{$hash->{tags}} ) {
#      confess Dumper  $hash->{tags};
      my $v = $hash->{tags}->{$tag};
      $tags .=  "\n    <tag k=\"$tag\" v=\"$v\"/>";
    }
    $osm .= <<"EOF";
  <node id="$hash->{id}" lat="$hash->{lat}" lon="$hash->{lon}" version="$hash->{version}" timestamp="$hash->{timestamp}" changeset="$hash->{changeset}" uid="$hash->{uid}" user="$hash->{user}">$tags
  </node>
EOF

  }
#  $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' ajout de tags', 'modify');
  warn "tags_bus_stop() fin";
}
#
# les nodes qui ne sont plus utilisés
#
sub bus_stop_disused {
  my $self = shift;
  warn "bus_stop_disused() début";
  my $critere;
  $critere = "['disused:highway'=bus_stop]";
  $critere = "['highway'=bus_stop]['ref'~'^#']";
  my $hash_disused = $self->{oOAPI}->osm_get("node(area:3602005861)$critere;out meta;", "$self->{cfgDir}/bus_stop_disused.osm");
  my $hash_ways = $self->{oOAPI}->osm_get("node(area:3602005861)$critere->.a;.a < ->.ways;.ways >;out meta;", "$self->{cfgDir}/bus_stop_ways.osm");
  my @nodes = @{$hash_disused->{node}};
#  confess Dumper $hash_ways->{node};
  my %id;
  for my $node ( @{$hash_ways->{node} }) {
    $id{$node->{id}}++;
  }
  my $osm = '';
  my $osm_tags = '';
  for my $node ( @nodes) {
    if ( ! defined $node->{tags}->{"disused:highway"} ) {
#      next;
    }
    if ( defined $id{$node->{id}} ) {
      warn Dumper $node;
      $osm_tags .= $self->{oOSM}->node_delete($node);
      next;
    }
    $osm .= $self->{oOSM}->node_delete($node);
  }
  warn "bus_stop_disused() suppression des nodes";
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'delete');
  $self->{oAPI}->changeset($osm_tags, $self->{osm_commentaire}, 'modify');
}
#
# vérification des bus_stop hors relation
#
sub bus_stop_hors {
  my $self = shift;
  warn "bus_stop_hors() début";
  my $hash = $self->osm_nodes_bus_stop_hors_get();
  my @nodes = @{$hash->{node}};
  my $osm = '';
  my $osm_disused = '';
  for my $node ( @nodes) {
    if ( $node->{changeset} ne "26620898" ) {
#     next;
    }
#    confess Dumper $node;
    my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{id}));
    if ( $node->{id} eq '3170866413') {
      warn $node_osm;
    }
    if ( defined $node->{tags}->{"disused:highway"} ) {
      next;
    }
    if ( defined $node->{tags}->{"ref"} && $node->{tags}->{"ref"} =~ m{^#\d+$}) {
      $osm_disused .= $self->{oOSM}->node_disused($node_osm);
      next;
    }
#    next;
#    $osm_disused .= $self->{oOSM}->node_disused($node_osm);
#    next;
    if ( defined $node->{tags}->{source} and  $node->{tags}->{source} =~ m{Keolis} and $node->{user} eq 'mga_geo' ) {
      $osm .= $self->{oOSM}->node_delete($node);
      next;
    }
    if ( defined $node->{tags}->{ref} and  $node->{tags}->{ref} =~ m{^#} and $node->{user} eq 'mga_geo' ) {
      $osm .= $self->{oOSM}->node_delete($node);
      next;
    }
    if ( $node->{id} eq "3066261835" ) {
      warn Dumper $node;
    }
    if ( ! defined $node->{tags}->{name} ) {
      $osm .= $self->{oOSM}->node_delete($node);
      next;
    }
  }
#  confess $osm_disused;
  warn "bus_stop_hors() suppression des nodes";
#  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'delete');
  $self->{oAPI}->changeset($osm_disused, $self->{osm_commentaire} . ' passage en disused des nodes hors relation', 'modify');
  warn "bus_stop_hors() fin";
}
sub bus_stop_hors_relation {
  my $self = shift;
  warn "bus_stop_hors_relation() début";
  my $hash = $self->{oOAPI}->osm_get("node[highway=bus_stop]['ref:FR:STAR']->.all;relation[network='FR:STAR'][route=bus](bn.all);node(r);( .all; - ._; );out meta;", "$self->{cfgDir}/bus_stop_hors_relation.osm");;
  my @nodes = @{$hash->{node}};
  my $osm = '';
  my $osm_disused = '';
  for my $node ( @nodes) {
    if ( $node->{changeset} ne "26620898" ) {
#     next;
    }
    warn Dumper $node;
    if ( defined $node->{tags}->{source} and  $node->{tags}->{source} =~ m{Keolis} and $node->{user} eq 'mga_geo' ) {
      $osm .= $self->{oOSM}->node_delete($node);
      next;
    }
  }
#  confess $osm_disused;
  warn "bus_stop_hors_relation() suppression des nodes";
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'delete');
  warn "bus_stop_hors_relation() fin";
}
sub bus_stop_way {
  my $self = shift;
  warn "bus_stop_way() début";
  my $hash = $self->{oOAPI}->osm_get("node[highway=bus_stop]['ref:FR:STAR'];way(bn);node(w)[highway=bus_stop]['ref:FR:STAR'];out meta;", "$self->{cfgDir}/bus_stop_way.osm");;
  my @nodes = @{$hash->{node}};
  my @deleted_keys = qw("public_transport name:fr_illenoo ref:fr_illenoo ref:FR:STAR public_transport public_transport:version note operator name bench shelter source highway  wheelchair network next operator lines line url route_ref stop_id level local_ref material description created_by bus old_name alt_name alt_name:note amenity animated old_name:start_date old_name_1 capacity:disabled fr_star covered);
  my $deleted_keys = join('|', @deleted_keys);
  for my $node ( @nodes) {
    my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{id}));
    $node_osm = $self->{oOSM}->delete_tags($node_osm, $deleted_keys);
    $self->{oAPI}->changeset($node_osm, $self->{osm_commentaire} . " retrait des tags", 'modify');
  }
  warn "bus_stop_way() fin";
}

# pour les arrêts
sub diff_bus_stop {
  my $self = shift;
  warn "diff_bus_stop() début";
  $hash = $self->osm_nodes_bus_stop_get();
  $gtfs_stops = $self->gtfs_table_get('stops');
  $gtfs_stops = $self->gtfs_table_get('keolis_stops_lignes');
  $self->bus_stop();
  warn "diff_bus_stop() fin";
}
#
# vérification des bus_stop
#
# on indexe par ref/stop_id
sub bus_stop {
  my $self = shift;
  warn "bus_stop() début";
  my ($stops, $names, $names_norm, $osm, $tags);
  $osm = '';
  warn "bus_stop() indexation gtfs";
  foreach my $stop ( @{$gtfs_stops} ) {
#    warn Dumper $stop;
    if ( $stop->{stop_id} !~ m{^\d+$} ) {
      confess "stop_id " . Dumper $stop;
      next;
    }
    if ( defined $stops->{$stop->{stop_id}} ) {
      warn "stop_id ***" . $stop->{stop_name} . " " . $stop->{stop_id};
      next;
    }
    push @{$stops->{$stop->{stop_id}}->{gtfs}}, $stop;
    push @{$names->{$stop->{stop_name}}->{gtfs}}, $stop;
    push @{$names_norm->{name_norm($stop->{stop_name})}->{gtfs}}, $stop;
  }
  warn "bus_stop() indexation osm";
  foreach my $node (sort @{$hash->{node}} ) {
    my $name = '';
    my $name_norm = '';
    my $ref = '';
    if ( not defined $node->{tags}->{name} ) {
      if ( $self->{DEBUG} > 1 ) {
        warn "bus_stop() indexation osm ref pas de name";
      }
 #     warn Dumper $node;
      next;
    }
    $name = $node->{tags}->{name};
    $name_norm = name_norm($name);
    if ( $name =~ m{__Rennes/Metz} ) {
      warn "bus_stop() n$node->{id} $node->{tags}->{name}  $node->{tags}->{ref}";
      warn Dumper $node;
    }
    if (!defined $node->{tags}->{$self->{k_ref}}  &&  defined $node->{tags}->{'ref:fr_illenoo'} ) {
      next;
    }
    if ( !defined $node->{tags}->{$self->{k_ref}}  && defined $node->{tags}->{'network'} && defined $node->{tags}->{'ref'} ) {
      warn "bus_stop() n$node->{id} *** k_ref $node->{tags}->{name}";
      next;
      warn Dumper $node;
      $self->bus_stop_proche($node, $gtfs_stops);
      exit;
    }
    if ( !defined $node->{tags}->{$self->{k_ref}}  && defined $node->{tags}->{'network'} ) {
      warn "bus_stop() n$node->{id} *** k_ref $node->{tags}->{name}";
      next;
      warn Dumper $node;
      $self->bus_stop_proche($node, $gtfs_stops);
      exit;
    }
    if ( ! defined $node->{tags}->{ref} && defined $node->{tags}->{$self->{k_ref}}) {
#      warn "bus_stop() n$node->{id} *** k_ref $node->{tags}->{name} " . $node->{tags}->{$self->{k_ref}};
#      $node->{tags}->{ref} = $node->{tags}->{$self->{k_ref}};
    }
    if ( defined $node->{tags}->{$self->{k_ref}} ) {
      $ref =  $node->{tags}->{$self->{k_ref}};
      if ( $ref =~ m{^#\d+$} ) {
        if ( $self->{DEBUG} > 1 ) {
          warn "bus_stop() ref:$ref name:$name";
        }
        next;
      }
      if ( $ref !~ m{^\d+$} ) {
        if ( $self->{DEBUG} > 1 ) {
          warn "bus_stop() indexation osm ref non numérique";
        }
#        warn Dumper $node;
        next;
      }
      push @{$stops->{$ref}->{osm}}, $node;
    } else {
      warn "bus_stop() n$node->{id} *** ref $node->{tags}->{name}";
      warn Dumper $node->{tags};
    }
    push @{$names->{$name}->{osm}}, $node;
    push @{$names_norm->{$name_norm}->{osm}}, $node;
  }
  warn "bus_stop() indexation nb names: " . scalar(keys %{$names});
  warn "bus_stop() indexation nb names_norm: " . scalar(keys %{$names_norm});
  warn "bus_stop() indexation nb ref: " . scalar(keys %{$stops});
#  exit;
#
# les ref en double du coté gtfs
  my $nb_double_gtfs = 0;
  my $osm_name = '';
  for my $ref (sort keys  %{$stops} ) {
    if ( not defined $stops->{$ref}->{gtfs} ) {
      next;
    }
    if ( scalar(@{$stops->{$ref}->{gtfs}}) > 1 ) {
      $nb_double_gtfs++;
      next;
    }
    if ( not defined $stops->{$ref}->{osm} ) {
      next;
    }
    if ( scalar(@{$stops->{$ref}->{osm}}) > 1 ) {
      next;
    }
    if ( $stops->{$ref}->{osm}[0]->{tags}->{name} eq $stops->{$ref}->{gtfs}[0]->{stop_name} ) {
 #     confess Dumper $stops->{$ref};
#      delete $stops->{$ref};
      next;
    }
    if ( name_norm($stops->{$ref}->{osm}[0]->{tags}->{name}) eq name_norm($stops->{$ref}->{gtfs}[0]->{stop_name}) ) {
 #     confess Dumper $stops->{$ref};
#      delete $stops->{$ref};
      next;
    }
    warn 'id:' . $stops->{$ref}->{osm}[0]->{id} . ' osm ' . $stops->{$ref}->{osm}[0]->{tags}->{name} . ' # gtfs ' . $stops->{$ref}->{gtfs}[0]->{stop_name};
    my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $stops->{$ref}->{osm}[0]->{id}));
    undef $tags;
    $tags->{name} = $stops->{$ref}->{gtfs}[0]->{stop_name};
    $tags->{source} = $self->{source};
    $osm_name .= $self->{oOSM}->modify_tags($node_osm, $tags, qw(name source)) . "\n";
  }
  if ( $osm_name ne '' ) {
    warn "bus_stop() modification des noms";
#    $self->{oAPI}->changeset($osm_name, $self->{osm_commentaire} . ' modification du nom des nodes' , 'modify');
  } else {
    warn "bus_stop() pas de modification des noms";
  }
  warn "bus_stop() nb_double_gtfs: $nb_double_gtfs";
  warn "bus_stop() indexation nb ref: " . scalar(keys %{$stops});
#  exit;
#
# les ref en double du coté osm
  my $nb_double_osm = 0;
  my $osm_delete = "";
  for my $ref (sort keys  %{$stops} ) {
    if ( not defined $stops->{$ref}->{osm} ) {
      next;
    }
    if ( scalar(@{$stops->{$ref}->{osm}}) == 1 ) {
      next;
    }
    $nb_double_osm++;
    if ( not defined $stops->{$ref}->{gtfs} ) {
      next;
    }
    warn "bus_stop() *** double osm " . sprintf("http://www.openstreetmap.org/#map=17/%s/%s", $stops->{$ref}->{gtfs}[0]->{stop_lat}, $stops->{$ref}->{gtfs}[0]->{stop_lon});
#    warn "bus_stop() *** double osm " . Dumper $stops->{$ref};
#    next;
    my $nodes = "";
    foreach my $node (@{$stops->{$ref}->{osm}}) {
      $nodes .= ",n" . $node->{id};
      if ( defined $node->{tags}->{source} && $node->{tags}->{source} =~ m{10 octobre 2016} ) {
#        confess "bus_stop() *** double osm " . Dumper $node;
#        $osm_delete = $self->{oOSM}->node_delete($node);
#        $self->{oAPI}->changeset($osm_delete, $self->{osm_commentaire}, 'delete');
      }
    }
    warn "josm " . substr($nodes, 1);
#    my $name =  $stops->{$ref}->{gtfs}[0]->{stop_name};
#    warn Dumper $names->{$name};
#    exit;
  }
  warn "bus_stop() nb_double_osm: $nb_double_osm";
#  exit;
#
# les nodes d'osm en plus (absent du gtfs)
  for my $name (sort keys  %{$names_norm} ) {
    if ( defined $names_norm->{$name}->{gtfs} ) {
      next;
    }

#    warn "bus_stop() osm en plus: name: $name";
  }
#
# les nodes d'osm en moins (présent dans le gtfs)
  my $osm_ref = '';
  for my $ref (sort keys  %{$stops} ) {
    if ( defined  $stops->{$ref}->{osm} ) {
      next;
    }
    my $g = $stops->{$ref}->{gtfs}[0];
    if (  $g->{routes} =~ m{^a$} ) {
      next;
    }
    warn "bus_stop() osm en moins: name: $ref stop_name:" . $g->{stop_name} . " refs:" . $g->{routes};
#    warn Dumper $stops->{$ref}->{gtfs}[0]; exit;
    $osm_ref .= $self->{oOSM}->node_stop($stops->{$ref}->{gtfs}[0]);
  }
#  exit;
#  confess Dumper $osm_ref;
  if ( $osm_ref ne '' ) {
    warn "bus_stop() ajout des nodes manquants";
    $self->{oAPI}->changeset($osm_ref, $self->{osm_commentaire} . ' ajout des nodes manquants' , 'create');
  } else {
    warn "bus_stop() pas de nodes manquants";
  }
  return;
#
# on ne conserve qu'un node par référence
# =======================================
  warn "bus_stop() un node par référence nb_stops:" . scalar(keys %{$stops});
  undef @nodes_modif;
  my  $osm_latlon = '';
  my $tags_star = {
    'source' => $self->{source},
    'public_transport' => 'platform',
    'public_transport:version' => '2',
    'network' => 'FR:STAR'
  };
  for my $ref (sort keys %{$stops} ) {
    if ( $ref !~ m{^\d+$} ) {
      confess "ref:$ref " . Dumper $stops->{$ref};
      next;
    }
    if ( not defined $stops->{$ref}->{osm} ) {
      next;
    }
    if ( not defined $stops->{$ref}->{gtfs} ) {
      next;
    }
    my $stop = $stops->{$ref}->{gtfs}[0];
    if ( scalar(@{$stops->{$ref}->{osm}}) == 1 ) {
      my $node = ${$stops->{$ref}->{osm}}[0];
#      confess Dumper $node;
      if ( $node->{'user'} !~ m{(mga_geo|Verdy_p)} ) {
#        next;
      }
      my $d = haversine_distance_meters($node->{lat}, $node->{lon}, $stop->{stop_lat}, $stop->{stop_lon});
      if ( $d > 25 ) {
        warn "bus_stop() n$node->{id} d: $d name: $stop->{stop_name}";
#        confess Dumper $node;
        my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{id}));
        $node_osm = $self->{oOSM}->node_replace_tags($node_osm, $tags_star);
        $osm_latlon .= $self->{oOSM}->modify_latlon($node_osm, $stop->{stop_lat}, $stop->{stop_lon}) . "\n";

      }
      next;
    }
    warn "bus_stop() node ref name:" . $stops->{$ref}->{gtfs}[0]->{stop_name};
    my %distance;
    my @nodes = @{$stops->{$ref}->{osm}};
    for my $n ( 0 .. scalar(@nodes)-1 ) {
      my $node = $nodes[$n];
      my $d = haversine_distance_meters($node->{lat}, $node->{lon}, $stop->{stop_lat}, $stop->{stop_lon});
      if ( $self->{DEBUG} > 1 ) {
        warn "bus_stop() id:$node->{id} d: $d";
      }
      $distance{$n} = $d;
    }
    my $nb = 0;
    for my $n ( sort {$distance{$a} <=> $distance{$b}} keys %distance ) {
      $nb++;
      if ( $self->{DEBUG} > 1 ) {
        warn "nb:$nb n=>$n distance:" . $distance{$n};
      }
      if ( $nb == 1 ) {
        next;
      }
      $nodes[$n]->{tags}->{ref} = "#" . $nodes[$n]->{tags}->{ref};
      push @nodes_modif,  $nodes[$n];
    }
  }
#  confess  $osm_latlon;
  $self->{oAPI}->changeset($osm_latlon, $self->{osm_commentaire} . ' latlon', 'modify');
  warn "bus_stop() fin";
  exit;
#  warn Dumper \@nodes_modif;
  warn "bus_stop() nb nodes_modif:" . scalar(@nodes_modif);
#
# mise en place du tag ref
  $osm_ref = '';
  my %id;
  for my $node ( @nodes_modif) {
    if ( not defined $node->{id} ) {
      next;
    }
    if ( defined $id{ $node->{id}} ) {
      next;
    }
    if ( scalar(keys %id) > 5 ) {
#      last;
    }
    $id{ $node->{id} }++;
    my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{id}));
    undef $tags;
    $tags->{ref} = $node->{tags}->{ref};
    $osm_ref .= $self->{oOSM}->modify_tags($node_osm, $tags, qw(ref)) . "\n";
  }
#  confess $osm_ref;
#  confess Dumper $stops;
  if ( $osm_ref ne '' ) {
    $self->{oAPI}->changeset($osm_ref, 'maj Keolis octobre 2014');
  }
  exit;
#
# on essaye de mettre en place une ref
  my $ref_node = 0;
  $osm_ref = '';
  for my $name (sort keys  %{$names} ) {
    $ref_node++;
    if( $ref_node > 10 ) {
#      last;
    }
    warn "name: $name";
    $osm_ref .= bus_stop_name($name, $names->{$name});
  }
  warn "nb stops_ajout:" . scalar(@stops_ajout);
  $osm_ref = '';
  for my $stop (@stops_ajout) {
    $osm_ref .= $self->{oOSM}->node_stop($stop);
  }
  if ( $osm_ref ne '' ) {
    $self->{oAPI}->changeset($osm_ref, 'maj Keolis octobre 2014', 'create');
  }
  confess Dumper $osm_ref;
  exit;

  exit;
  warn "bus_stop() node=bus_stop voisins";
  my $osm_node = '';
  my $new_node = 0;
  my $modify_node = 0;
  for my $ref (sort keys %{$stops} ) {
    if ( $new_node > 50 ) {
#      last;
    }
    if ( $modify_node > 5 ) {
      last;
    }
    if ( $ref !~ m{^\d+$} ) {
      confess "ref:$ref " . Dumper $stops->{$ref};
      next;
    }
    if ( $ref < 2458 ) {
#      next;
    }
    if ( defined $stops->{$ref}->{osm} ) {
      next;
    }
    if ( not defined $stops->{$ref}->{gtfs} ) {
      next;
    }
    warn "new_node:$new_node modify_node:$modify_node ref:$ref stop_name:" . $stops->{$ref}->{gtfs}->{stop_name};
#    confess Dumper $stops->{$ref};
    my $ok = 0;
    my $h = osm_bus_stop_around($stops->{$ref}->{gtfs}->{stop_lat}, $stops->{$ref}->{gtfs}->{stop_lon} );
# pas de réponse
    if ( scalar( @{$h->{node}} ) == 0 ) {
#      confess Dumper $arrets->{$i}->{stop};
#      $osm_node .= $self->{oOSM}->node_stop($arrets->{$i}->{stop});
    }
    foreach my $node (sort @{$h->{node}}) {
      if ( not defined  $node->{tags}->{name} ) {
        next;
      }
      if ( defined $node->{tags}->{ref} ) {
        next;
      }
      if ( $node->{tags}->{name} eq $stops->{$ref}->{gtfs}->{stop_name} ) {
        warn "node around ===" . $node->{tags}->{name};
#        confess Dumper $node;
        my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{id}));
        undef $tags;
        $tags->{ref} = $stops->{$ref}->{gtfs}->{stop_id};
        $osm .= $self->{oOSM}->modify_tags($node_osm, $tags, qw(ref)) . "\n";
        $modify_node++;
        $ok++;
        last;
      }
#      confess Dumper $node;
    }
    if ( $ok == 0 ) {
      $new_node++;
#      confess Dumper $arrets->{$i}->{stop};
      $osm_node .= $self->{oOSM}->node_stop($stops->{$ref}->{gtfs});
      if ( $new_node > 5 ) {
#        last;
      }
    }
  }
  $self->{oAPI}->changeset($osm_node, 'maj Keolis octobre 2014', 'modify');
#  $self->{oAPI}->changeset($osm_node, 'maj Keolis septembre 2014', 'create');
}
#
# tentative de rapprochement pour un name
sub bus_stop_name {
  my $self = shift;
  my $name = shift;
  my $hash = shift;
  my $osm_ref = '';
  warn "bus_stop_name() name: $name";
  if ( not defined $hash->{osm} or not defined $hash->{gtfs} ) {
    return $osm_ref;
  }
# étape 1 :
# - on ne garde que ceux avec référence commune
# - et on ne garde que le plus proche
  my (@stops, @nodes);
  for my $stop ( @{$hash->{gtfs}} ) {
    my $ok = 0;
    my (@nodes);
    for my $node ( @{$hash->{osm}} ) {
      if ( not defined $node->{tags}->{ref} ) {
        next;
      }
      if ( $stop->{stop_code} ne $node->{tags}->{ref} ) {
        next;
      }
      if ( $self->{DEBUG} > 1 ) {
        warn "bus_stop_name() name: $name ref:" . $node->{tags}->{ref};
      }
      $ok++;
      push @nodes, $node;
    }
# trop de correspondance, on conserve le plus proche
    if ( $ok > 1 ) {
      my %distance;
#      confess Dumper \@nodes;
      for my $n ( 0 .. scalar(@nodes)-1 ) {
        my $node = $nodes[$n];
        my $d = haversine_distance_meters($node->{lat}, $node->{lon}, $stop->{stop_lat}, $stop->{stop_lon});
#        warn "bus_stop_name() id:$node->{id} d: $d";
        $distance{$n} = $d;
      }
      my $nb = 0;
      for my $n ( sort {$distance{$a} <=> $distance{$b}} keys %distance ) {
        $nb++;
        if ( $self->{DEBUG} > 1 ) {
          warn "nb:$nb n=>$n distance:" . $distance{$n};
        }
        if ( $nb == 1 ) {
          next;
        }
        $nodes[$n]->{tags}->{ref} = "#" . $nodes[$n]->{tags}->{ref};
#        push @nodes_modif,  $nodes[$n];
      }
    }
  }
# étape 2 :
# - on ne garde que ceux sans référence
# - et on ne garde que le plus proche
  undef @stops;
  undef @nodes;
  for my $stop ( @{$hash->{gtfs}} ) {
    my $ok = 0;
    for my $node ( @{$hash->{osm}} ) {
      if ( not defined $node->{tags}->{ref} ) {
        next;
      }
      if ( $stop->{stop_code} eq $node->{tags}->{ref} ) {
        $ok++;
        last;
      }
    }
# pas de correspondance, on mémorise
    if ( $ok == 0 ) {
      push @stops, $stop;
    }
  }
  for my $node ( @{$hash->{osm}} ) {
    if ( not defined $node->{tags}->{ref} ) {
      push @nodes, $node;
      next;
    }
    if ( $node->{tags}->{ref} !~ m{^\d+$} ) {
      push @nodes, $node;
      next;
    }
    my $ok = 0;
    for my $stop ( @{$hash->{gtfs}} ) {
      if ( $stop->{stop_code} eq $node->{tags}->{ref} ) {
        $ok++;
        last;
      }
    }
# pas de correspondance, on mémorise
    if ( $ok == 0 ) {
      push @nodes, $node;
    }
  }
#
# on a des stops mais de nodes, on les crée !
  if ( scalar(@nodes) == 0 && scalar(@stops) > 0 ) {
    for my $stop ( @stops ) {
      push @stops_ajout, $stop;
    }
#    confess Dumper \@stops;
    return;
  }
  if ( scalar(@nodes) == 0) {
    return '';
  }
  if ( scalar(@stops) == 0 and scalar(@nodes) > 0) {
    for my $node ( @nodes ) {
      $node->{tags}->{ref} = "#####";
#      push @nodes_modif,  $node;
    }
    return '';
  }
# on calcule les distances
   my %distance;
  for my $stop ( @stops ) {
    for my $n ( 0 .. scalar(@nodes)-1 ) {
      my $node = $nodes[$n];
      my $d = haversine_distance_meters($node->{lat}, $node->{lon}, $stop->{stop_lat}, $stop->{stop_lon});
      if ( $self->{DEBUG} > 1 ) {
        warn "bus_stop_name() id:$node->{id} d: $d";
      }
      $distance{$n} = $d;
    }
    my $nb = 0;
    for my $n ( sort {$distance{$a} <=> $distance{$b}} keys %distance ) {
      $nb++;
      warn "nb:$nb n=>$n distance:" . $distance{$n};
      if ( $nb == 1 ) {
        $nodes[$n]->{tags}->{ref} = $stop->{stop_id};
        push @nodes_modif,  $nodes[$n];
        next;
      }
      $nodes[$n]->{tags}->{ref} = "#####";
    }
  }
  return;
  warn "stops: " .  Dumper \@stops;
  warn "nodes: " .  Dumper \@nodes;
  if ( $osm_ref ne '' ) {
    warn $osm_ref;
  }
#  confess Dumper \@{$hash->{osm}};
  return $osm_ref;
  confess Dumper $hash;
# uniquement si 2 stations
  if (scalar(@{$hash->{osm}}) != 2  or scalar(@{$hash->{gtfs}}) != 2 ) {
    return $osm_ref;
  }
# déjà la bonne ref ?
  my $ok = 0;
  for my $stop ( @{$hash->{gtfs}} ) {
    for my $node ( @{$hash->{osm}} ) {
      if ( not defined $node->{tags}->{ref} ) {
        next;
      }
      if ( $stop->{stop_code} ne $node->{tags}->{ref} ) {
        next;
      }
      warn "bus_stop_name() name: $name ref:" . $node->{tags}->{ref};
      $ok++;
      last;
    }
  }
  if ( $ok ) {
    return $osm_ref;
  }
  confess Dumper $hash;
# calcul des distances entre les points
# on ne retient que le plus proche
  my %proches;
  for my $node ( @{$hash->{osm}} ) {
# on ignore si à plus de 200 mètres
    $node->{gtfs}->{distance} = 200;
    for my $stop ( @{$hash->{gtfs}} ) {
      my $d = haversine_distance_meters($node->{lat}, $node->{lon}, $stop->{stop_lat}, $stop->{stop_lon});
      if ( $d >  $node->{gtfs}->{distance} ) {
        next;
      }
#      warn "bus_stop_name() node:" . $node->{id} . " stop:" . $stop->{stop_id} . " distance: $d";
      $node->{gtfs}->{distance} = $d;
      $node->{gtfs}->{stop_id} =  $stop->{stop_id};
    }
    $proches{$node->{gtfs}->{stop_id}} = $node->{id};
  }
#  warn "bus_stop_name() proches :" . Dumper \%proches;
  if ( scalar(keys %proches) != 2 ) {
    return $osm_ref;
    confess Dumper $hash;
  }
  for my $node ( @{$hash->{osm}} ) {
#    $osm_ref = "$node->{id}\n";  last;
    my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{id}));
    my $tags;
    $tags->{ref} =  $node->{gtfs}->{stop_id};
    $osm_ref .= $self->{oOSM}->modify_tags($node_osm, $tags, qw(ref)) . "\n";
  }
  return $osm_ref;
}
sub bus_stop_35 {
  my $self = shift;
  warn "bus_stop_35() début";
  $hash = $self->{oOAPI}->osm_get("area[name='Ille-et-Vilaine'];node(area)['highway'='bus_stop'];out meta;", "$self->{cfgDir}/bus_stop_35.osm");
#  $hash = $self->{oOAPI}->osm_get("node['highway'='bus_stop']['ref:illenoo'];out meta;", "$self->{cfgDir}/bus_stop_35.osm");
#  confess Dumper $hash;
  my $csv = "id;lon;lat;name;ref;source";
  for my $node ( @{$hash->{node}} ) {
    if ( $node->{'tags'}->{'ref'} && $node->{'tags'}->{'ref'} =~ m{\d\d\d\d} ) {
      next;
    }
    $csv .= sprintf("\n%s;%s;%s;%s;%s;%s", $node->{'id'}, $node->{'lon'}, $node->{'lat'}, $node->{'tags'}->{'name'}, $node->{'tags'}->{'ref'}, $node->{'tags'}->{'source'});
  }
  open(CSV, "> :utf8", "$self->{cfgDir}/bus_stop_35.csv") or die;
  print CSV $csv;
  close(CSV);
}
# ajout de la ref et de la source aux nodes existants
sub bus_stop_35_ref {
  my $self = shift;
  warn "bus_stop_35_ref() début";
  my $table = 'bus_stop';
  my $nodes = $self->table_get($table);
  my ($ids, $osm);
  for my $node ( @{$nodes} ) {
#    confess Dumper $node;
    if ( defined $ids->{$node->{id}} ) {
      next;
    }
    $ids->{$node->{id}}++;
    my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{id}));
    my $tags = {
      source => $self->{source},
      'ref:fr_illenoo' => $node->{ref},
      name => $node->{name},
    };
    if ( $tags->{name} =~ m{^\s*$} ) {
      $tags->{name} = $node->{illenoo};
#      confess Dumper $tags;
    }
    $osm .= $self->{oOSM}->modify_tags($node_osm, $tags, qw(ref:fr_illenoo source name)) . "\n";
#    last;
  }
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');
}
# ajout des nodes manquants
sub bus_stop_35_ajout {
  my $self = shift;
  warn "bus_stop_35_ajout() début";
  my $table = ' bus_stop_hors_osm';
  my $nodes = $self->table_get($table);
  my ($osm);
  my $format = <<'EOF';
  <node id="%s" lat="%s" lon="%s" version="1" timestamp="0" changeset="1">
    <tag k="highway" v="bus_stop"/>
    <tag k="name" v="%s"/>
    <tag k="ref:fr_illenoo" v="%s"/>
    <tag k="source" v="%s"/>
  </node>
EOF
  for my $node ( @{$nodes} ) {
#    confess Dumper $node;
    $osm .= sprintf($format, $self->{node_id}, $node->{Y_WGS84}, $node->{X_WGS84}, $node->{NOM}, $node->{ID}, $self->{source});
    $self->{node_id}--;
  }
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'create');
}
#
# la partie wfs
# pour les arrêts
sub diff_bus_stop_wfs {
  my $self = shift;
  warn "diff_bus_stop_wfs() début";
  my $wfs_stops = $self->wfs_stops_get();
  my $osm_stops = $self->bus_stop_35();
  warn "diff_bus_stop_wfs() fin";
}
#
# pour rechercher et ordonner les arrêts
# on calcule la distance de chaque arret à tous les points de la ligne
# on garde le plus proche
sub relation_bus_stop {
  my $self = shift;
  warn "relation_bus_stop() début";
  my $id = $self->{id};
  $self->get_relation_ways_nodes();
  my $hash = $self->oapi_get("rel($id);node(around:50)['highway'='bus_stop'];out meta;", "$self->{cfgDir}/relation_bus_stop_$id.osm");
  my $nodes;
  my $ways = $self->{ways};
  my $members = $self->{'osm'}->{'relation'}[0]->{'member'};
  my $tags =  $self->{'osm'}->{'relation'}[0]->{tags};

# on constitue la liste de tous les noeuds des ways membres de la relation
# on en profite pour mémoriser à quelle way appartient le node
#  confess Dumper $members;
  my $nb_nodes = 0;
  for my $member ( @{$members} ) {
    if ( $member->{type} ne 'way' ) {
      $nb_nodes++;
      next;
    }
    my $w = $member->{ref};
    if ( not defined $ways->{$w} ) {
      confess;
    }
#    confess Dumper $ways->{$w};
    for my $n ( @{$ways->{$w}->{nodes}} ) {
      push @{$nodes->{$n}->{ways}}, $w;
    }
  }
  warn "relation_bus_stop() $id "
    . "\n\t" . $tags->{name}
    . "\n\t" . $tags->{description}
    . "\n\t" . $tags->{from} . "=>" . $tags->{to}
    . "\n\tnb_nodes:$nb_nodes";
#  confess Dumper $nodes;
  my $bus_stop;
  for my $node ( @{$hash->{node}} ) {
    my $distance = 2000;
    for my $nk ( keys %{$nodes} ) {
      my $n = $self->{nodes}->{$nk};
#      warn "relation_bus_stop() $n->{'id'}, $n->{'lon'}, $n->{'lat'}";
      my $d = haversine_distance_meters($node->{lat}, $node->{lon}, $n->{lat}, $n->{lon});
      if ( $d > $distance ) {
        next;
      }
      $distance = $d;
      $node->{'distance'} = $d;
      $node->{'node'} = $nk;
    }
    $bus_stop->{$node->{'node'}} = $node;
#    warn "relation_bus_stop() $distance $node->{'id'}, $node->{'lon'}, $node->{'lat'}, $node->{'tags'}->{'name'}";
#    last;
  }
#  confess Dumper $bus_stop;
# on parcourt de nouveau les ways membres de la relation
  my $level0 = 'r' . $self->{id} . "\n";
  my $osm_members = '';
  my $prev = '';
  my $nb_stops = 0;
  @{$self->{stops}} = ();
  for my $member ( @{$members} ) {
    if ( $member->{type} ne 'way' ) {
      next;
    }
    my $w = $member->{ref};
    if ( not defined $ways->{$w} ) {
      confess;
    }
#    confess Dumper $ways->{$w};
    for my $n ( @{$ways->{$w}->{nodes}} ) {
      if ( not defined $bus_stop->{$n} ) {
        next;
      }
      my $node = $bus_stop->{$n};
      if ( $prev == $node ) {
        next;
      }
      warn "relation_bus_stop() $node->{'id'}, $node->{'tags'}->{'name'}";
      $level0 .= "  nd $node->{'id'} platform\n";
      $osm_members .= sprintf('  <member type="node" ref="%s" role="platform"/>' ."\n", $node->{id});

      $prev = $node;
      $nb_stops++;
      push @{$self->{stops}}, $node;
    }
  }
#  print $level0;
#  print $osm_members;
  my $osm = get(sprintf("https://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $self->{'id'}));
  $osm = $self->{oOSM}->relation_replace_member($osm, '<member type="node" ref="\d+" role="platform[^"]*"/>', $osm_members);
#  print $osm;
  $self->{oAPI}->changeset($osm, 'mise a jour des arrets', 'modify');
  warn "relation_bus_stop() fin nb_stops:$nb_stops";
}
sub bus_stop_35_tags {
  my $self = shift;
  warn "bus_stop_35_tags() début";#  $hash = $self->{oOAPI}->osm_get("area[name='Ille-et-Vilaine'];node(area)['highway'='bus_stop'];out meta;", "$self->{cfgDir}/bus_stop_35.osm");
#  $hash = $self->{oOAPI}->osm_get("area[name='Ille-et-Vilaine'];node(area)['highway'='bus_stop']['public_transport'!='platform']['$self->{tag_stop}'];out meta;", "$self->{cfgDir}/bus_stop_35_tags.osm");
  $hash = $self->{oOAPI}->osm_get("area[name='Ille-et-Vilaine'];node(area)['highway'!='bus_stop']['public_transport'='platform']['$self->{tag_stop}'];out meta;", "$self->{cfgDir}/bus_stop_35_tags.osm");
  my $tags_nodes;
  for my $node ( @{$hash->{node}} ) {
    $tags_nodes->{$node->{'id'}}++;
  }
  $self->nodes_bus_stops_tags($tags_nodes);
}
# préfixage avec fr_ de la ref
sub bus_stop_fr_tags {
  my $self = shift;
  warn "bus_stop_fr_tags() début";
  my $network = 'ksma';
  $hash = $self->{oOAPI}->osm_get("node['highway'='bus_stop']['ref:${network}'];out meta;", "$self->{cfgDir}/bus_stop_fr_tags.osm");
  my $osm = '';
  for my $node ( @{$hash->{node}} ) {
    my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{'id'} ));
    $node_osm =~ s{ref:illenoo}{ref:fr_${network}}sm;
    $node_osm =~ s{.*<(node|way|relation)}{<$1}sm;
    $node_osm =~ s{</(node|way|relation)>.*}{</$1>}sm;
    $osm .= $node_osm;
#    confess $node_osm;
  }
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . " modification du tag ref:${network}" , 'modify');
}
sub bus_stop_commun {
  my $self = shift;
  warn "bus_stop_commun() début";
  $hash = $self->{oOAPI}->osm_get("node['highway'='bus_stop']['ref:fr_star']['ref:fr_illenoo'];out meta;", "$self->{cfgDir}/bus_stop_commun.osm");
  my $opendata_stops = $self->illenoo_stops_get();
  my $osm = '';
  for my $node ( @{$hash->{node}} ) {
    my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{'id'} ));
    if ( defined $node->{tags}->{'ref:fr_illenoo'} ) {
      next;
    }
    my $ref = $node->{tags}->{'name:fr_illenoo'};
#    confess Dumper $opendata_stops->{$ref};
    my $nom = $opendata_stops->{$ref}->{'NOM'};
    my $tags = {
      'name:fr_illenoo' => $nom,
    };
    $node_osm = $self->{oOSM}->modify_tags($node_osm, $tags, qw(name:fr_illenoo)) . "\n";
#    confess $node_osm;
    $osm .= $node_osm;
  }
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' ajout du tag name:fr_illenoo' , 'modify');
}
#
# modification des tags des nodes
sub bus_stops_nodes_tags {
  my $self = shift;
  my $hash_nodes = $self->oapi_get("node['" . $self->{k_ref} . "'];out meta;", "$self->{cfgDir}/bus_stops_nodes_tags.osm");
  my $tags = {
    'highway' => 'bus_stop',
    'public_transport' => 'platform',
#    'public_transport:version' => '2',
    'source' => $self->{source}
  };
  my $osm = '';
  for my $node ( @{$hash_nodes->{node}} ) {
    if ( not defined $node->{tags}->{'public_transport'} ) {
      warn "bus_stops_nodes_tags() public_transport " ;
      warn Dumper $node;
      next;
    }
    if ( $node->{tags}->{'public_transport'} =~ m{^stop} ) {
#      warn "bus_stops_nodes_tags() public_transport " ;
#      warn Dumper $node;
      next;
    }
    my $nb_absent = 0;
     for my $tag ( keys %{$tags} ) {
      if ( not defined $node->{tags}->{$tag} ) {
        warn "bus_stopnodes_tags() absent $node->{id} tag:$tag";
        warn Dumper $node;
        $nb_absent++;
      }
    }
#    confess Dumper $node;
    if ( $nb_absent == 0 ) {
      next;
    }
    my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{id}));
    $osm .= $self->{oOSM}->modify_tags($node_osm, $tags, qw(highway public_transport source)) . "\n";
  }
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' modification des tags' , 'modify');
}
# pour supprimer les tags next
sub bus_stop_tag_next {
  my $self = shift;
  warn "bus_stop_tag_next() début";
  $hash = $self->osm_nodes_bus_stop_get();
  my $osm = '';
  my $nb_osm = 0;
  my $tags = {
    'highway' => 'bus_stop',
    'public_transport' => 'platform'
  };
  my %tags;
  my @deleted_keys = qw(network next operator lines line url route_ref stop_id level local_ref material description created_by bus old_name alt_name alt_name:note amenity animated old_name:start_date old_name_1 capacity:disabled fr_star covered);
  my $deleted_keys = join('|', @deleted_keys);
  warn "bus_stop_tag_next() deleted_keys:$deleted_keys";
  for my $node ( @{$hash->{node}} ) {
    my $nb_deleted = 0;
    my $nb_absent = 0;
    for my $tag ( keys %{$node->{tags}} ) {
      $tags{$tag}++;
      if ( $tag !~ m{^($deleted_keys)$} ) {
        next;
      }
      $nb_deleted++;
      warn "bus_stop_tag_next() $node->{id} tag:$tag";
#      warn Dumper $node;
      delete $node->{tags}->{$tag};
    }
    for my $tag ( keys %{$tags} ) {
      if ( not defined $node->{tags}->{$tag} ) {
        warn "bus_stop_tag_next() absent $node->{id} tag:$tag";
        warn Dumper $node;
        $nb_absent++;
      }
    }
    if ( $nb_deleted == 0 && $nb_absent == 0) {
      next;
    }
    warn "bus_stop_tag_next() $node->{id}  $nb_deleted == 0 && $nb_absent == 0";
    $nb_osm++;
    my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{id}));
    confess $node_osm;
    $node_osm = $self->{oOSM}->delete_tags($node_osm, $deleted_keys);
    $node_osm = $self->{oOSM}->modify_tags($node_osm, $tags, qw(highway public_transport));
    $osm .= $node_osm . "\n";
    if ( $nb_osm > 10 ) {
#      last;
    }
#    confess Dumper $osm;
  }
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . " retrait des tags $deleted_keys", 'modify');
  for my $tag (sort keys %tags) {
    printf("% 20s %5d\n", $tag, $tags{$tag});
  }
  warn "bus_stop_tag_next() fin $nb_osm";
}
# https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_API_by_Example
# trouve des points hors Rennes
sub bus_stop_not_relation {
  my $self = shift;
  warn "bus_stop_not_relation() début";
  $hash = $self->{oOAPI}->osm_get("area[name='Rennes'];node(area)['highway'='bus_stop']->.all;rel(bn.all);node(r);( .all; - ._; );out meta;", "$self->{cfgDir}/bus_stop_not_relation.osm");
  warn "bus_stop_not_relation() osm: " . "$self->{cfgDir}/bus_stop_not_relation.osm";
  my $tags_nodes;
  for my $node ( @{$hash->{node}} ) {
#    $tags_nodes->{$node->{'id'}}++;
  }
#  $self->nodes_bus_stops_tags($tags_nodes);
}
sub bus_stop_proche {
  my $self = shift;
  warn "bus_stop_proche()";
  my $node = shift;
  warn Dumper $node;
  my $stops = shift;
  my %distance;
  my $n = 0;
  for my $stop (@{$stops} ) {
#    confess Dumper $stop;
    my $d = haversine_distance_meters($node->{lat}, $node->{lon}, $stop->{stop_lat}, $stop->{stop_lon});
    if ( $d > 300 ) {
#      warn $d;
      next;
    }
    if ( $self->{DEBUG} > 1 ) {
#      warn "bus_stop() id:$node->{id} d: $d";
    }
    warn "bus_stop() $n d: $d";
    $distance{$n} = {
      'd' => $d,
      'stop' => $stop
    };
    $n++;
  }
  confess Dumper \%distance;
  my $nb = 0;
  for my $n ( sort {$distance{$a} <=> $distance{$b}} keys %distance ) {
    $nb++;
    if ( $self->{DEBUG} > 1 ) {
      warn "nb:$nb n=>$n distance:" . $distance{$n};
    }
  }
}
# pour mettre à jour les tags
sub bus_stop_tags_maj {
  my $self = shift;
  warn "routes_tags_maj() début";
  my $hash = $self->oapi_get("relation[network='$self->{network}'][type=route][route=bus];>>;node._[highway=bus_stop];out meta;", "$self->{cfgDir}/bus_stop_tags_maj.osm");
  my $osm = '';
  my $nb_osm = 0;
  my $tags = {
    'public_transport:version' => '2',
    'highway' => 'bus_stop',
    'public_transport' => 'platform',
    'website' => 'https://www.reseau-mat.fr/',
    'operator' => 'Keolis Saint-Malo',
    'source' => $self->{source}
  };
  my %tags;
  for my $node ( @{$hash->{node}} ) {
    my $nb_deleted = 0;
    my $nb_absent = 0;
    my $nb_diff = 0;
    for my $tag ( keys %{$node->{tags}} ) {
      $tags{$tag}++;
    }
    for my $tag ( keys %{$tags} ) {
      if ( not defined $node->{tags}->{$tag} ) {
        warn "routes_tags_maj() absent $node->{id} tag:$tag";
#        warn Dumper $node;
        $nb_absent++;
        next;
      }
      if ( $node->{tags}->{$tag} != $tags->{$tag} ) {
        warn "routes_tags_maj() diff $node->{id} tag:$tag";
#        warn Dumper $node;
        $nb_diff++;
        next;
      }
    }
    if ($nb_absent == 0 && $nb_diff == 0) {
      next;
    }
    warn "bus_stop_tags_maj() $node->{id}  absent $nb_absent == 0 diff $nb_diff == 0";
    $nb_osm++;
    my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{id}));
    $node_osm = $self->{oOSM}->modify_tags($node_osm, $tags, keys %{$tags});
#    confess $node_osm;
    $osm .= $node_osm . "\n";
#    last;
    if ( $nb_osm > 10 ) {
#      last;
    }
#    confess Dumper $osm;
  }
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . " mise a jour des tags", 'modify');
  warn "bus_stop_tags_maj() fin $nb_osm";
}
1;