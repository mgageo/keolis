# <!-- coding: utf-8 -->
#
# les traitements sur les données gtfs
#
#
package Transport;
use utf8;
use strict;
#
# les données gtfs
# ================
#
#
# récupération d'une table
sub gtfs_table_get {
  my $self = shift;
  my $table = shift;
  $self->{oDB}->table_select($table);
  warn "gtfs_table_get() nb:".scalar(@{$self->{oDB}->{table}->{$table}});
  return $self->{oDB}->{table}->{$table};
}
# récupération des routes avec indexation par route_short_name # osm ref
sub gtfs_routes_get {
  my $self = shift;
  $self->{oDB}->table_select('routes');
#  confess Dumper $self->{oDB}->{table}->{routes};
  my $routes;
  for my $route ( @{$self->{oDB}->{table}->{routes}} ) {
#	warn $route->{route_long_name};
    $routes->{$route->{route_short_name}} = $route;
  }
#  confess Dumper $routes;
  warn "gtfs_routes_get() nb:".scalar(keys %{$routes});
  return $routes;
}
# récupération des stops avec indexation par route_short_name # osm ref
sub gtfs_stops_getid {
  my $self = shift;
  $self->{oDB}->table_select('stops');
#  confess Dumper $self->{oDB}->{table}->{stops};
  my $stops;
  for my $stop ( @{$self->{oDB}->{table}->{stops}} ) {
#	warn $route->{route_long_name};
    $stops->{$stop->{'stop_id'}} = $stop;
#    confess Dumper $stop;
  }
#  confess Dumper $stops;
  warn "gtfs_stops_get() nb:".scalar(keys %{$stops});
  return $stops;
}
# récupération des itinéraires
sub gtfs_keolis_iti_get {
  my $self = shift;
  my $ref = shift;
  my ( $route_id ) = ( $ref =~ m{(\d+)} );
  if ( $ref =~ m{^N} ) {
    $route_id += 120;
  }
  $route_id = sprintf("%04d", $route_id);
#  $self->{oDB}->table_select('keolis_trip', 'WHERE route_short_name = "' . $ref . '"');
  $self->{oDB}->table_select('keolis_trip', 'WHERE route_id = "' . $route_id . '"');
#  confess Dumper $self->{oDB}->{table}->{keolis_trip};
  warn "gtfs_keolis_iti_get() ref:$ref nb:" . scalar(@{$self->{oDB}->{table}->{keolis_trip}});
  if ( scalar(@{$self->{oDB}->{table}->{keolis_trip}}) == 0 ) {
    warn "gtfs_keolis_iti_get() *** 0";
    return undef;
  }
  my $gtfs_iti;
  for my $iti ( @{$self->{oDB}->{table}->{keolis_trip}} ) {
    delete $iti->{geometry};
    push @{$gtfs_iti->{$iti->{trip_id}}}, $iti;
  }
#  confess Dumper $gtfs_iti;
  my ($itis, $from, $to);
  for my $trip_id ( sort keys %{$gtfs_iti} ) {
    my $iti = sprintf("%s;%s;%s", scalar(@{$gtfs_iti->{$trip_id}}), ${$gtfs_iti->{$trip_id}}[0]->{stop_name}, ${$gtfs_iti->{$trip_id}}[-1]->{stop_name});
#    warn "gtfs_keolis_iti_get() $iti";
#    confess Dumper $gtfs_iti->{$trip_id};
    $itis->{$iti}->{nb}++;
    $itis->{$iti}->{trip} = $gtfs_iti->{$trip_id};
    $itis->{$iti}->{shape_id} = ${$gtfs_iti->{$trip_id}}[-1]->{shape_id};
    $itis->{$iti}->{from} = ${$gtfs_iti->{$trip_id}}[0]->{stop_name};
    $itis->{$iti}->{to} = ${$gtfs_iti->{$trip_id}}[-1]->{stop_name};
    $itis->{$iti}->{description} = ${$gtfs_iti->{$trip_id}}[-1]->{route_long_name};
    $itis->{$iti}->{ref} = ${$gtfs_iti->{$trip_id}}[-1]->{route_short_name};
#    push @{$from->{${$gtfs_iti->{$trip_id}}[0]->{stop_name}}} , $iti;
#    push @{$to->{${$gtfs_iti->{$trip_id}}[-1]->{stop_name}}} , $iti;
  }
#  confess Dumper $itis;
  warn "gtfs_keolis_iti_get() ref:$ref depart/arrive nb itis:" . scalar(keys %{$itis});
# on conserve les 2 itinéraires les plus utilisés
  my @nb = ();
  for my $iti ( sort keys %{$itis} ) {
    push @nb, $itis->{$iti}->{nb};
  }
  @nb = sort {$a <=> $b} @nb;
  warn "gtfs_keolis_iti_get() ref:$ref nb itis par arrivee/depart " . join(";", @nb) . " seuil:". $nb[-2];
  for my $iti ( sort keys %{$itis} ) {
    warn "gtfs_keolis_iti_get() $iti";
  }
  return $itis;

exit;
  $self->{seuil} = $nb[-2];
  my $nb_iti = 0;
  my ( %fromto, $fromto, $f, $t, %from, %to );
  for my $iti ( sort keys %{$itis} ) {
    warn "gtfs_keolis_iti_get() iti:$iti nb:" . $itis->{$iti}->{nb};
    if ( $itis->{$iti}->{nb} < $nb[-2] ) {
      delete $itis->{$iti};
      next;
    }
    ( $fromto ) = ( $iti =~ m{^[^;]+;(.*)} );
    if ( defined $fromto{$fromto} ) {
      warn "gtfs_keolis_iti_get() fromto: $fromto";
      delete $itis->{$iti};
      next;
    }
    $fromto{$fromto}++;
    ($f, $t) = ( $fromto =~ m{(.*);(.*)} );
    if ( defined $from{$f} ) {
      warn "gtfs_keolis_iti_get() from: $f";
      delete $itis->{$iti};
      next;
    }
    $from{$f}++;
    if ( defined $to{$t} ) {
      warn "gtfs_keolis_iti_get() to: $t";
      delete $itis->{$iti};
      next;
    }
    $to{$t}++;
    $nb_iti++;
    if ( $nb_iti > 2 ) {
#      delete $itis->{$iti};
#      next;
    }
    warn "gtfs_keolis_iti_get() iti:$iti ***ok***";
#    warn Dumper $gtfs_iti->{$itis->{$iti}->{trip_id}};
# le code de création osm
    $itis->{$iti}->{osm} = $self->{oOSM}->relation_route($itis->{$iti});
  }
  warn "gtfs_keolis_iti_get() nb itis:" . scalar(keys %{$itis});
  return $itis;
}
#
# récupération des arrêts
sub gtfs_stops_get {
  my $self = shift;
  $self->{oDB}->table_select('stops');
  warn "gtfs_stops_get() nb:".scalar(@{$self->{oDB}->{table}->{stops}});
  return $self->{oDB}->{table}->{stops};
}

#
# pour lister un itinéraire
sub gtfs_iti_liste {
  my $self = shift;
  my $ref ='12567';
  my $stmt = "SELECT trip_id, stop_id, stop_sequence
FROM stop_times
WHERE stop_times.trip_id = '1'
ORDER BY trip_id, CAST(stop_times.stop_sequence AS integer);";
  my $sth = $self->{oDB}->{dbh}->prepare( $stmt );
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0){
    confess "table_select() ". $DBI::errstr;
  }
  my @table = ();
  while(my $hash = $sth->fetchrow_hashref()) {
#    confess Dumper $hash;    return;
    delete $hash->{Geometry};
    push @{table}, $hash;
  }
  confess Dumper \{@table};
}

1;