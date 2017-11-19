# <!-- coding: utf-8 -->
#
#
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
use Devel::Peek;
use English;
use LWP::Simple;
use XML::Simple;
use Storable 'dclone';
use GeoMisc;
#
sub valid_routes_ways {
  my $self = shift;
  my $network = $self->{network};
  my $tag = $self->{'tag_ref'};
  my $requete = "rel[network='$network'][route=bus]$tag;out meta;";
  warn "valid_routes_ways() tag:$tag $requete";
#  my $osm = $self->{oOAPI}->osm_get("rel['ref:star'];out meta;", "$self->{cfgDir}/relation_routes.osm");
  my $osm = $self->{oOAPI}->osm_get($requete, "$self->{cfgDir}/relation_routes.osm");
  my ( @id );
  for my $relation ( @{$osm->{'relation'}} ) {
    my $ref_network = $relation->{tags}->{'ref:ksma'};
    if ( $ref_network !~ m{7} ) {
#      next;
    }
#    warn Dumper $r->{tags};
#    push @id, $r->{tags}{$tag};
    push @id, {
      id => $relation->{id},
      ref => $relation->{tags}->{ref},
      tags => $relation->{tags}
    };
#    confess Dumper \@id;
  }
  my $nb_ko = 0;
  my $refs = '';
  my $level0 = '';
  for my $id ( sort {$a->{ref} cmp $b->{ref} } @id ) {
#    confess Dumper $id;
    $self->{tags} = $id;
    $self->{id} = $id->{id};
    my $rc = $self->valid_relation_ways();
    $nb_ko += $rc->{nb_ko};
    if ( $rc->{nb_ko} > 0 ) {
      $refs .= "$self->{ref} ";
      $level0 .= "r" . $id->{id} . ",";
    }
#    $self->relation_bus_stop();
    if ( $rc->{nb_ko} == 0 ) {
      $self->gpx_relation_ways();
    }
  }
  chop $level0;
  warn <<EOF;
***************************
valid_routes_ways fin $network
nb_ko: $nb_ko refs: $refs
level0: $level0
***************************
EOF
}
#
sub valid_route_ways {
  my $self = shift;
  warn "valid_route_ways() id:" . $self->{id};
  $self->valid_relation_ways();
}
sub valid_relation_ways {
  my $self = shift;
  my $network = $self->{network};
  my $tag = $self->{'tag'};
  my $tag_ref = $self->{'tag_ref'};
  my $id = $self->{'id'};
  my $ref = $self->{'tags'}->{'ref'};
  $tag =  $self->{'tags'}->{'tags'}->{$tag};
#  confess Dumper  $self->{'id'};
  warn "\n=========\nvalid_relation_ways debut network:$network id:$id ref:$ref tag_ref:$tag_ref tag:$tag\n";
#  confess Dumper $self->{'tags'}->{'tags'};
  my $nb_ko = 0;
  $self->get_relation_ways_nodes();
  my $nodes = $self->{nodes};
  my $ways = $self->{ways};
  my $osm = $self->{osm};
#  confess Dumper $ways;
#  confess Dumper $osm->{'relation'}[0]->{'member'};
  my $members = $osm->{'relation'}[0]->{'member'};
  my $avant = undef;
  my $n1 = undef;
  my $w1 = undef;
  my @ways;

  my $tags_nodes;

  for my $member ( @{$members} ) {
    if ( $member->{type} eq 'node' ) {
      my $n = $member->{ref};
      if ( $member->{role} =~ m{^(stop|platform|stop_entry_only|platform_entry_only|stop_exit_only|platform_exit_only)$} ) {
#      warn Dumper $nodes->{$n};
#      warn $nodes->{$n}->{tags}->{name};
        if ( $n1 ) {
#        warn GeoMisc::_distance($nodes->{$n}->{lat}, $nodes->{$n}->{lon}, $nodes->{$n1}->{lat}, $nodes->{$n1}->{lon});
        }
        if ( not defined $nodes->{$n}->{tags}->{'highway'} or not defined $nodes->{$n}->{tags}->{'public_transport'} ) {
#          warn Dumper $nodes->{$n};
          $tags_nodes->{$n}++;
          next;
        }
        if ( $nodes->{$n}->{tags}->{highway} ne 'bus_stop' ) {
          warn Dumper $nodes->{$n};
          next;
        }
        $n1 = $n;
        next;
      }
      if ( $nodes->{$n}->{tags}->{highway} eq 'mini_roundabout' ) {
        next;
      }
#      confess Dumper $nodes->{$n};
      warn "\tnode role#stop|platform " . $member->{role} . " tags " . $nodes->{$n}->{tags}->{highway} . " " . $nodes->{$n}->{tags}->{name};
      $nb_ko++;
    };
#    exit;
    if ( $member->{type} eq 'way' ) {
#      warn $member->{ref};
      my $w = $member->{ref};
#      warn Dumper $ways->{$w}->{'nodes'};
      my $actuel = $ways->{$w}->{'nodes'};
      if ( $avant ) {
        my %avant = map{$_=>1} @{$avant};
        my %actuel = map{$_=>1} @{$actuel};
        my @intersection = grep($avant{$_}, @{$actuel});
        if ( @intersection ) {
#          warn "\tnodes:" . join(",", @intersection);
          if ( defined $ways->{$w}->{tags}->{'oneway'} ) {
# le premier noeud doit appartenir au précédent segment
            my $n1 = $ways->{$w1}->{nodes}[0];
            if ( not defined $avant{$n1} ) {
              warn Dumper $ways->{$w1}->{nodes};
              warn Dumper $ways->{$w};
            }
          }
        } else {
          warn "w${w} " . join(",", @{$avant});
          warn "w${w1} ". join(",", @{$actuel});
          warn "\t " . $self->distance_node_stops(@{$avant}[0], $members, $nodes);
          warn "\t " . $self->distance_node_stops(@{$actuel}[0], $members, $nodes);
          $nb_ko++;
#          exit;
        }
      }
      $avant = $ways->{$w}->{'nodes'};
      push @ways, $w;
      $w1 = $w;
      next;
    };
  }
  warn "\nvalid_relation_ways fin network:$network tag:$tag id:$id ref:$ref\nnb_ko:$nb_ko\n=========\n";
  return { nb_ko => $nb_ko };
}

#
# conversion des ways d'une relation en format gpx
sub gpx_relation_ways {
  my $self = shift;
  my $network = $self->{network};
  my $tag = $self->{'k_ref'};
  my $id = $self->{'id'};
  my $ref = $self->{'tags'}->{$tag};
  my $DEBUG = $self->{DEBUG};
  if ( $ref ne "_0057-02-A" ) {
#    return;
  } else {
    $DEBUG = 1.
  }
#  confess Dumper  $self->{'id'};
  warn "\n=========\ngpx_relation_ways debut network:$network tag:$tag id:$id ref:$ref\n";
  my $nb_ko = 0;
  $self->get_relation_ways_nodes();
  my $osm = $self->{osm};
  my $nodes = $self->{nodes};
  my $ways = $self->{ways};
  my @ways;
  my $members = $osm->{'relation'}[0]->{'member'};
  my $ref = $osm->{'relation'}[0]->{tags}->{'ref:FR:STAR'};
  for my $member ( @{$members} ) {
    if ( $member->{type} eq 'way' ) {
#      confess Dumper $ways->{$member->{ref}};
#      my $w = dclone $ways->{$member->{ref}};;
#      confess Dumper $w;
      push @ways, dclone $ways->{$member->{ref}};
    }
  };
#  confess Dumper \@ways;
  warn "gpx_relation_ways() ways nb " . scalar(scalar(@ways));
  my @i;
  my $nb_ways = 0;
  my $i1 = undef;
  for my $i ( 0 .. scalar(@ways)-1 ) {
    my $w = $ways[$i]->{id};
    my $roundabout = 0;
    if ( $DEBUG ) {
      warn sprintf("%3d %12s %s\n", $i, $w,  $ways[$i]->{tags}->{name});
    }
# un seul point ?
    if ( $ways[$i]->{tags}->{highway} eq 'mini_roundabout' ) {
      if ( $DEBUG ) {
        warn sprintf("\tmini_roundabout\n");
      }
      next;
    }
    if ( $ways[$i]->{nodes}[0] == $ways[$i]->{nodes}[-1] ) {
      $ways[$i]->{roundabout} = 1;
      if ( $DEBUG ) {
        warn sprintf("\troundabout\n");
      }
    }
# le premier segment est un rond-point, on ignore !
    if ( $i == 0 && $roundabout == 1) {
      next;
    }
    push @i, $i;
    if ($nb_ways == 0 ) {
      $i1 = $i;
      $nb_ways++;
      next;
    }
#    next;
#
# on doit avoir un point en commun
# - deux ways
    if ( $ways[$i]->{roundabout} == 0 && $ways[$i1]->{roundabout} == 0 ) {
      if ( $ways[$i]->{nodes}[0] != $ways[$i1]->{nodes}[-1] ) {
#        printf("$nb_ways *** inverse w:%s w1:%s\n", $ways[$i]->{nodes}[0], $ways[$i1]->{nodes}[-1]);
#        printf("w1:$w1 nodes:%s\n", join(" ", @{$ways[$i1]->{nodes}}));
#        printf("w:$w nodes:%s\n", join(" ", @{$ways[$i]->{nodes}}));
        if ( $ways[$i]->{nodes}[0] == $ways[$i1]->{nodes}[0] ) {
          @{$ways[$i1]->{nodes}} = reverse @{$ways[$i1]->{nodes}};
        }
        if ( $ways[$i]->{nodes}[-1] == $ways[$i1]->{nodes}[-1] ) {
          @{$ways[$i]->{nodes}} = reverse @{$ways[$i]->{nodes}};
        }
        if ( $ways[$i]->{nodes}[-1] == $ways[$i1]->{nodes}[0] ) {
          @{$ways[$i]->{nodes}} = reverse @{$ways[$i]->{nodes}};
          @{$ways[$i1]->{nodes}} = reverse @{$ways[$i1]->{nodes}};
        }
        if ( $ways[$i]->{nodes}[0] != $ways[$i1]->{nodes}[-1] ) {
          printf("   inverse i:$i w:%s w1:%s\n", $ways[$i]->{nodes}[0], $ways[$i1]->{nodes}[-1]);
          printf("i1:$i1 nodes:%s\n", join(" ", @{$ways[$i1]->{nodes}}));
          printf("i :$i nodes:%s\n", join(" ", @{$ways[$i]->{nodes}}));
          my $j = 0;
          for my $w ( @ways ) {
            $j++;
#            warn "\t$j $w " .  $ways[$i]->{tags}->{name} . "\n";

          }
          return;
        }
      }
    }
# - on arrive sur un rond-point
# il faut trouver le point d'entrée sur le rond-point
    if ( $ways[$i]->{roundabout} == 1 && $ways[$i1]->{roundabout} == 0 ) {
      my @nodes = @{$ways[$i]->{nodes}};
      pop @nodes;
      for my $n ( 0 .. scalar(@nodes) ) {
# c'est le dernier noeud du segment précédent
        if ( $nodes[0] == $ways[$i1]->{nodes}[-1] ) {
          last;
        }
# c'est le premier noeud du segment précédent
# => il n'était pas dans le bon sens
        if ( $nodes[0] == $ways[$i1]->{nodes}[0] ) {
          @{$ways[$i1]->{nodes}} = reverse @{$ways[$i1]->{nodes}};
          last;
        }
        push @nodes,(shift @nodes);
      }
      @{$ways[$i]->{nodes}} = @nodes;
#      warn Dumper \@nodes;exit;
    }
# - on sort d'un rond-point
# il faut trouver le point de sortie du rond-point
    if ( $ways[$i]->{roundabout} == 0 && $ways[$i1]->{roundabout} == 1 ) {
      my @nodes = @{$ways[$i1]->{nodes}};
      for my $n ( 1 .. scalar(@nodes) ) {
# c'est le premier noeud
        if ( $nodes[-1] == $ways[$i]->{nodes}[0] ) {
          last;
        }
# c'est le dernier noeud
# => il n'était pas dans le bon sens
        if ( $nodes[-1] == $ways[$i]->{nodes}[-1] ) {
          @{$ways[$i]->{nodes}} = reverse @{$ways[$i]->{nodes}};
          last;
        }
        pop @nodes;
      }
      @{$ways[$i1]->{nodes}} = @nodes;
#      warn Dumper \@nodes;exit;
    }
#    printf("%03d %s % 12d % 12d %-20s\n", $i, $roundabout, $ways->{$w}->{nodes}[0], $ways->{$w}->{nodes}[-1], $ways->{$w}->{tags}->{'highway'});
#    confess "i:$i " . Dumper $ways->{$w};
    $i1 = $i;
#
  }
  if ( scalar(@i) < 2 ) {
    return;
  }
  my $gpx = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.0" creator="mga" xmlns="http://www.topografix.com/GPX/1/0">
  <trk>
    <name>$ref</name>
    <trkseg>
EOF
#  confess Dumper \@i;
#  confess Dumper \@ways;
  for my $i ( @i ) {
    my $w = $ways[$i];
#    printf("%03d %s % 12d % 12d %-20s\n", $i, $w->{roundabout}, $w->{nodes}[0], $w->{nodes}[-1], $w->{tags}->{'highway'});
    for my $n ( @{ $w->{nodes}} ) {
#      confess Dumper $nodes->{$n};
      $gpx .= sprintf("\n      <trkpt lat=\"%s\" lon=\"%s\"/>", $nodes->{$n}->{lat}, $nodes->{$n}->{lon});
    }
  }
  $gpx .= <<EOF;

    </trkseg>
  </trk>
</gpx>
EOF
#  warn $gpx;
  open(GPX, "> :utf8", "$self->{cfgDir}/${ref}_$id.gpx") or die;
  print GPX $gpx;
  close(GPX);
  warn "gpx_relation_ways() $self->{cfgDir}/${ref}_$id.gpx";
  return $nb_ko;
}
#
# recherche des ways formant un segment
sub segment_relation_ways {
  my $self = shift;
  my $id = $self->{'id'};
#  confess Dumper  $self->{'id'};
  warn "\n=========\nsegment_relation_ways debut id:$id\n";
  my $nb_ko = 0;
  $self->get_relation_ways_nodes();
  my $osm = $self->{osm};
  my $nodes = $self->{nodes};
  my $ways = $self->{ways};
  my @ways;
  my $members = $osm->{'relation'}[0]->{'member'};
  for my $member ( @{$members} ) {
    if ( $member->{type}ne 'way' ) {
      next;
    }
    push @ways, $member->{ref};
  };
  for my $i ( 0 .. scalar(@ways)-1 ) {
    my $wi = $ways[$i];
    my $ni = $ways->{$wi}->{'nodes'};
    my %ni = map{$_=>1} @{$ni};
    for my $j ( 0 .. scalar(@ways)-1 ) {
      if ( $j == $i ) {
        next;
      }
      my $wj = $ways[$j];
      my $nj = $ways->{$wj}->{'nodes'};
      my %nj = map{$_=>1} @{$nj};
      my @intersection = grep($ni{$_}, @{$nj});
      if ( @intersection ) {
        push @{$ways->{$wi}->{intersection}}, $wj;
      }
    }
  }
  for my $i ( 0 .. scalar(@ways)-1 ) {
    my $w = $ways[$i];
    my $name = '';
    if ( defined $ways->{$w}->{tags}->{name} ) {
       $name = $ways->{$w}->{tags}->{name};
    }
    my $roundabout = 0;
    if ( $ways->{$w}->{nodes}[0] == $ways->{$w}->{nodes}[-1] ) {
      $roundabout = 1;
    }
    $ways->{$w}->{roundabout} = $roundabout;
    my $intersection = '';
    if ( defined $ways->{$w}->{intersection} ) {
      $intersection = join(" ", @{$ways->{$w}->{intersection}});
    }
    printf("w:$w $roundabout $name\n\tnodes:%s\n\t%s\n", join(" ", @{$ways->{$w}->{nodes}}), $intersection );
  }
  printf("\n\nles intersections\n");
  my $segments;
  for my $i ( 0 .. scalar(@ways)-1 ) {
    my $w = $ways[$i];
    if ( not defined $ways->{$w}->{intersection} ) {
      next;
    }
    if ( scalar(@{$ways->{$w}->{intersection}}) > 2 ) {
      next;
    }
    my $name = '';
    if ( defined $ways->{$w}->{tags}->{name} ) {
      $name = $ways->{$w}->{tags}->{name};
    }
    if ( defined $ways->{$w}->{segment} ) {
      next;
    }
    $ways->{$w}->{segment} = $w;
    $segments->{$w} = $w;
    printf("w:$w $name\n");
    my @wi = @{$ways->{$w}->{intersection}};
    while  ( @wi ) {
      my $wi = shift @wi;
      if ( defined $ways->{$wi}->{segment} ) {
        next;
      }
      my $nbi = scalar( @{$ways->{$wi}->{intersection}});
      if ( $nbi > 2 ) {
        next;
      }
      $ways->{$wi}->{segment} = $w;
      push @wi, @{$ways->{$wi}->{intersection}};
      my $namei = '';
      if ( defined $ways->{$wi}->{tags}->{name} ) {
        $namei = $ways->{$wi}->{tags}->{name};
      }
      printf("\twi:$wi $nbi $namei\n");
      $segments->{$wi} = $w;
    }
  }
}
#
# conversion des ways d'une relation en format gpx
sub gpx_relation_ways_v1 {
  my $self = shift;
  my $network = $self->{network};
  my $id = $self->{'id'};
  my $ref = $self->{'tags'}->{'ref'};
#  confess Dumper  $self->{'id'};
  warn "gpx_relation_ways debut network:$network id:$id ref:$ref\n";
  $self->get_relation_ways_nodes();
  my $osm = $self->{osm};
  my $nodes = $self->{nodes};
  my $ways = $self->{ways};
  my @ways;
  my $members = $osm->{'relation'}[0]->{'member'};
  for my $member ( @{$members} ) {
    if ( $member->{type} eq 'way' ) {
      push @ways, $member->{ref};
    }
  };
  my $gpx = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.0" creator="mga" xmlns="http://www.topografix.com/GPX/1/0">
  <trk>
    <name>$self->{'id'}</name>
EOF
  for my $w ( @ways ) {
    $gpx .= sprintf("    <trkseg>\n");
#    printf("%03d %s % 12d % 12d %-20s\n", $i, $ways->{$w}->{roundabout}, $ways->{$w}->{nodes}[0], $ways->{$w}->{nodes}[-1], $ways->{$w}->{tags}->{'highway'});
    for my $n ( @{ $ways->{$w}->{nodes}} ) {
#      confess Dumper $nodes->{$n};
      $gpx .= sprintf("      <trkpt lon=\"%s\" lat=\"%s\"/>\n",$nodes->{$n}->{lon}, $nodes->{$n}->{lat});
    }
    $gpx .= sprintf("    </trkseg>\n");
  }
  $gpx .= <<EOF;
  </trk>
</gpx>
EOF
#  warn $gpx;
  $ref =~ s{\W}{_}gi;
  my $f_gpx = "$self->{cfgDir}/relation_ref_$ref.gpx";
  open(GPX, "> :utf8", $f_gpx) or die;
  print GPX $gpx;
  close(GPX);
  warn "gpx_relation_ways() $f_gpx";
}
sub get_relation_ways_nodes {
  my $self = shift;
  my $id = $self->{'id'};
  my $nb_ko = 0;
  warn "get_relation_ways_nodes() id: $id";
#  my $osm = $self->{oAPI}->osm_get("relation/$id", "$self->{cfgDir}/relation_$id.osm");
#  my $osm = $self->{oOAPI}->osm_get("relation($id);>>;out meta;", "$self->{cfgDir}/relation_route_$id.osm");
  my $osm = $self->{oAPI}->osm_get("relation/$id/full", "$self->{cfgDir}/relation_route_$id.osm");
  if ( scalar(@{$osm->{'relation'}}) != 1 ) {
    my $msg = '';
    for my $r ( @{$osm->{'relation'}} ) {
      $msg .= " , r" . $r->{'id'};;
    }
    warn "\t*** relation $msg";

    return $nb_ko++;
  }
  my ($nodes, $ways);
  for my $n ( @{$osm->{'node'}} ) {
    $nodes->{$n->{'id'}} = $n;
  }
  for my $w ( @{$osm->{'way'}} ) {
    $ways->{$w->{'id'}} = $w;
  }
  $self->{ways} = $ways;
  $self->{nodes} = $nodes;
  $self->{osm} = $osm;
}
#
sub distance_node_stops {
  my $self = shift;
  my $n1 = shift;
  my $members = shift;
  my $nodes = shift;
  my %distances;
#  warn Dumper $nodes->{$n1};
  for my $member ( @{$members} ) {
    if ( $member->{type} ne 'node' ) {
      next;
    }
    my $n = $member->{ref};
#    warn Dumper $nodes->{$n};
    my $distance = GeoMisc::_distance($nodes->{$n}->{lat}, $nodes->{$n}->{lon}, $nodes->{$n1}->{lat}, $nodes->{$n1}->{lon});
    $distances{$n} = $distance;
  };
  my $name;
  foreach my $n ( sort { $distances{$a} <=> $distances{$b} } keys %distances) {
   $name = $nodes->{$n}->{'tags'}->{'name'};
    last;
  }
  return $name;
}
#
#
# pour mettre en place "ref:star"
# avec le fichier de l'open data rennes
sub diff_parcours {
  my $self = shift;
  warn "diff_parcours() debut";
  my $table = 'star_parcours';
  my $network = $self->{network};
  my $hash_route = $self->{oOAPI}->osm_get("relation[network=${network}][type=route][route=bus];out meta;", "$self->{cfgDir}/relation_routes_bus.osm");
  $self->parcours_get($table);
#
# on indexe par le code
  my $codes;
  foreach my $relation (sort tri_tags_ref @{$hash_route->{relation}}) {
    my $tags = $relation->{tags};
    if ( $tags->{ref} =~ /^(Ts|TT|N)/ ) {
      next;
    }
    if ( $tags->{ref} =~ /^2\d\d/ ) {
      next;
    }
    if ( not defined $tags->{'ref:fr_star'} ) {
      warn sprintf("%s %s from:%s to:%s id:%s", $tags->{'ref'}, $tags->{'description'}, $tags->{'from'}, $tags->{'to'}, $relation->{'id'});
      next;
    }
    $codes->{$tags->{'ref:fr_star'}}->{'osm'} = $relation;
  }
  for my $row ( @{$self->{oDB}->{table}->{$table}} ) {
    $codes->{$row->{'code'}}->{'star'} = $row;
  }
  for my $code ( sort keys %{$codes} ) {
    if ( not exists $codes->{$code}->{'osm'} ) {
      warn "absent osm $code";
      my $row = $codes->{$code}->{'star'};
      warn sprintf("\t%s %s from:%s to:%s", $row->{'code'}, $row->{'libellelong'}, $row->{'nomarretdep'}, $row->{'nomarretarr'});#
    }
    if ( not exists $codes->{$code}->{'star'} ) {
      warn "absent star $code";
    }
  }
  confess;
  my $osm = '';
  foreach my $relation (sort tri_tags_ref @{$hash_route->{relation}}) {
#    confess Dumper $relation;
    my $tags = $relation->{tags};
    if ( $tags->{ref} =~ /^Ts/ ) {
      next;
    }
    if ( $tags->{ref} =~ /^2\d\d/ ) {
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
# même référence on controle from to
      if ( $tags->{'ref:fr_star'} && $tags->{'ref:fr_star'} eq $row->{'code'} ) {
        if ( $tags->{'from'} ne $row->{'nomarretdep'} ) {
          warn sprintf("\tfrom:%s nomarretdep:%s", $tags->{'from'}, $row->{'nomarretdep'});;
        }
        if ( $tags->{'to'} ne $row->{'nomarretarr'} ) {
          warn sprintf("\tto:%s nomarretarr:%s", $tags->{'to'}, $row->{'nomarretarr'});;
        }
        next;
      }
      if ( $tags->{'from'} ne $row->{'nomarretdep'} ) {
        next;
      }
      if ( $tags->{'to'} ne $row->{'nomarretarr'} ) {
        next;
      }
      if (  $row->{'code'} !~ m{\-0\d\-[AB]$} ) {
        next;
      }
      warn sprintf("\t%s %s from:%s to:%s", $tags->{'ref'}, $tags->{'ref:fr_star'}, $tags->{'from'}, $tags->{'to'});
      warn sprintf("\t%s %s from:%s to:%s", $row->{'code'}, $row->{'libellelong'}, $row->{'nomarretdep'}, $row->{'nomarretarr'});#
 # confess Dumper $tags;
      next;
      my $relation_id = $relation->{'id'};
      my $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation_id));
      $tags->{'ref:fr_star'} =  $row->{'code'};
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
sub valid_parcours {
  my $self = shift;
  warn "valid_parcours() debut";
  my $table = 'star_parcours';
  my $network = $self->{network};
  my $hash_route = $self->{oOAPI}->osm_get("relation[network=${network}][type=route][route=bus];out meta;", "$self->{cfgDir}/relation_routes_bus.osm", 0);
# on index les routes par leur ref
  my $hash_route_ref = {};
  my %relations;
  foreach my $relation (@{$hash_route->{relation}}) {
#    confess Dumper $relation;
    $relations{$relation->{id}} = $relation;
    $relations{$relation->{id}}->{nb} = 0;
#    confess Dumper \%relations;
    my $tags = $relation->{tags};
    if ( $tags->{ref} =~ /^(N|T|2\d\d)/ ) {
      next;
    }
    if ( ! defined $tags->{"ref:fr_star"} ) {
      warn Dumper $relation->{tags};
      next;
    }
    push @{$hash_route_ref->{$tags->{ref}}}, $relation;
  }
#  exit;
  $self->parcours_get($table);
  warn "valid_parcours() analyse des parcours star";
  for my $row ( @{$self->{oDB}->{table}->{$table}} ) {
    warn sprintf("star %s %s from:%s to:%s", $row->{'code'}, $row->{'libellelong'}, $row->{'nomarretdep'}, $row->{'nomarretarr'});
    my $ref = $row->{'nomcourtlig'};
    my $osm_ok = '';
    my $osm_ko = '';
    my $ok = 0;
    foreach my $relation (@{$hash_route_ref->{$ref}} ) {
      my $tags = $relation->{tags};
      if ( defined $tags->{'ref:fr_star'} &&  $tags->{'ref:fr_star'} eq $row->{'code'} ) {
        $ok++;
        $relations{$relation->{id}}->{nb}++;
        $osm_ok .= sprintf("\t=== %s ref:fr_star: %s %s from:%s to:%s r%s\n", $tags->{'ref'}, $tags->{'ref:fr_star'}, $tags->{'description'}, $tags->{'from'}, $tags->{'to'}, $relation->{'id'});
        next;
      }
      $osm_ko .= sprintf("\t*** %s ref:fr_star: %s %s from:%s to:%s r%s\n", $tags->{'ref'}, $tags->{'ref:fr_star'}, $tags->{'description'}, $tags->{'from'}, $tags->{'to'}, $relation->{'id'});
    }
    print $osm_ok;
    if ( $ok != 1 ) {
      print $osm_ko;
    }
  }
  warn "valid_parcours() analyse des parcours osm sans correspondance star";
  for my $r ( sort keys %relations ) {
    my $relation =  $relations{$r};
    if ( $relation->{nb} == 1 ) {
      next;
    }
    my $ref = $relation->{tags}->{ref};
    if ( $ref =~ m/^(N|T|2\d\d)/ ) {
      next;
    }
    my $tags = $relation->{tags};
#    confess Dumper $relation;
    warn sprintf("r%s %d %s from:%s to:%s ref:fr_star:%s",$r, $relation->{nb}, $tags->{name}, $tags->{'from'}, $tags->{'to'}, $tags->{'ref:fr_star'});
  }
#  confess $osm;
}

# récupération d'une table
sub parcours_get {
  my $self = shift;
  my $table = shift;
  $self->{oDB}->table_select($table, '', 'ORDER BY id');
  warn "parcours_get() nb:".scalar(@{$self->{oDB}->{table}->{$table}});
}
#
sub valid_network {
  my $self = shift;
  warn "valid_network()";
  $self->{oOSM}->valid_network_route();
}
#
#
sub osm2route {
  my $self = shift;
  my $f_csv = $self->{cfgDir} . '/ligne_' . $self->{network} . '_way_ok.csv';
  warn "osm2route() f_csv: $f_csv";
  open(CSV, $f_csv) or die "osm2route() erreur:$! open(CSV, $f_csv)";
  my @lignes = <CSV>;
  close(CSV);
# mise en tableau
  my (@item, $way, @ways, $ways, $ref);
  for my $ligne ( @lignes ) {
    chomp $ligne;
    my ($NUM_LIGNE,$item_no,$ratio_segment, $ratio_way, $lg_segment,$lg_way,$way_id,$highway,$name,$nodes_id) = split(";", $ligne);
    if ( $way_id !~ m{^\d+$} ) {
      next;
    }
    if ( $ratio_segment !~ m{^\d+$} ) {
      warn $ligne;
      next;
    }
    if ( $ratio_segment < 50 && $ratio_way < 50 ) {
      next;
    }
    $ref = $NUM_LIGNE;
    if ( $highway =~ m{(pedestrian|footway|steps|cycleway)} ) {
      next;
    }
    my $kv = {
      ratio_segment => $ratio_segment,
      ratio_way => $ratio_way,
      lg_segment => $lg_segment,
      lg_way => $lg_way,
      highway => $highway,
      name => $name,
      highway => $highway,
      way_id => $way_id,
      nodes_id => $nodes_id,
    };
    push @{$item[$item_no]}, $kv;
    $way->{$way_id}->{$item_no} = 1;
    $ways->{$way_id} = $kv;
    if ( scalar(@item) > 35000 ) {
      last;
    }
  }
  $self->{ref} = $ref;
  warn "osm2route() ref:$ref nb_items:" . scalar(@item);
#  warn Dumper $way;
#  warn Dumper \@item;
  my $item = 0;
  my $max = -1;
  while ( $item < scalar(@item) ) {
    if ( not defined $item[$item] ) {
      warn "osm2route() *** $item";
      $item++;
      next;
    }

# recherche de la relation avec la plus longue séquence d'items
#    confess Dumper $item;
    my $max_way = -1;
    my @inclues = ();
    for my $i (@{$item[$item]} ) {
      my $way_id = $i->{way_id};
#      warn "way_id:$way_id ratio_way:" . $i->{ratio_way};
# la way est inclue ?
      if ( $i->{ratio_way} > 95 ) {
        push @inclues, $way_id;
#        next;
      }
      if ( $i->{ratio_segment} < 50 ) {
        next;
      }
#      warn Dumper  $way->{$way_id};
      my $nb = $item;
      for my $j ( sort { $a <=> $b } keys %{$way->{$way_id}} ) {
#        warn "way_id:$way_id item:$item nb:$nb j:$j";
        if ( $j < $nb ) {
          next;
        }
        if ( $j > $nb + 2 ) {
          last;
        }
        $nb = $j;
      }
      if ( $nb >= $max ) {
        $max = $nb;
        $max_way = $way_id;
      }
    }
    if ( $max_way == -1 && scalar(@inclues) < 1) {
      warn "max_way ****";
      warn "nb_inclues:" . scalar(@inclues);
      warn Dumper $item[$item];
#      warn Dumper $way;
      exit;
    }
    if ( $max_way > -1 ) {
      push @inclues, $max_way;
    } else {
      $max = $item;
    }
    my %seen =() ;
    @inclues = grep { ! $seen{$_}++ } @inclues;
#    warn "item:$item: way:$max_way max:$max";
#    confess Dumper $ways->{$max_way};
    for $max_way ( @inclues ) {
      warn "osm2route() $item=>$max nb_inclues:" . scalar(@inclues) . " " . $ways->{$max_way}->{way_id} . " " . $ways->{$max_way}->{highway} . " " . $ways->{$max_way}->{name};
      push @ways, $max_way;
    }
    $item =  $max + 1;
  }
  my $data = sprintf($self->{overpassQL}, $ref);
  my $hash = $self->{oOSM}->osm_get($data, "$self->{cfgDir}/$self->{network}_${ref}_r.osm");
#  confess Dumper  $hash;
  my $relation_id = 4267909;
  my $action = 'modifiy';
  my $version = '0';
  my $relation_osm = '';
  if ( scalar(@{$hash->{relation}}) > 0 ) {
    $relation_id = ${$hash->{relation}}[0]->{id};
    $relation_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation_id));
    ( $version ) = ( $relation_osm =~ m{ version="(\d+)" });

    $action = 'modify';
  } else {
    $relation_id = -1;
    $version = 1;
    $action = 'create';
  }
  warn "osm2route() relation_id:$relation_id action:$action";
  my $osm = <<EOF;
  <relation id="$relation_id" timestamp="0" changeset="1" version="${version}">
EOF
  for my $way_id ( @ways ) {
    $osm .= '    <member type="way" ref="' . $way_id . '" role=""/>' . "\n";
  }
#  confess Dumper \@way_id;
  $osm .= <<"EOF";
   <tag k="network" v="fr_$self->{network}"/>
    <tag k="operator" v="$self->{operator}"/>
    <tag k="ref" v="$ref"/>
    <tag k="$self->{k_route}" v="bus"/>
    <tag k="source" v="$self->{source}"/>
    <tag k="type" v="route"/>
  </relation>
EOF
#  warn $osm;
  my $f_osm = "$self->{cfgDir}/$self->{network}_${ref}.osm";
  open(OSM, ">",  $f_osm) or die "osm2route() erreur:$!";
  print(OSM $osm);
  close(OSM);
  warn "osm2route() f_osm: $f_osm action:$action";

  my $delta = $self->{oOSM}->diff_relation_member($osm, $relation_osm);
#  if ( $delta !~ m{^\s*$} ) {
    $self->{oAPI}->changeset($osm, 'maj decembre 2014', $action);
#  }
}
1;