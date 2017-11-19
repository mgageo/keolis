# <!-- coding: utf-8 -->
#
# les traitements avec le routage osrm
#
#
package Transport;
use utf8;
use strict;
use LWP::Simple;
use JSON qw(decode_json);
#
#
# ===================
#
#
# récupération d'un routage entre deux points
sub osrm_get {
  my $self = shift;
  my $query = shift;
  my $force = 3;
  my ($lat1, $lon1, $lat2, $lon2, $url, $content);
  $lat1 = "48.15518";
  $lon1 = "-1.573236";
  $lat2 = "48.15399";
  $lon2 = "-1.543296";
  my $routerUrl = "http://192.168.148.129:5000";
  $url = sprintf('%s/route/v1/driving/%s,%s;%s,%s?overview=false&annotations=nodes', $routerUrl, $lon1, $lat1, $lon2, $lat2);
  $url = sprintf('%s/route/v1/driving/%s?overview=false&annotations=nodes', $routerUrl, $query);
#  $url = sprintf('%s/match/v1/driving/%s?overview=false&annotations=nodes&tidy=true&gaps=ignore', $routerUrl, $query);
  warn($url);
#  exit;
  my $f_osrm = "$self->{cfgDir}/osrm.json";
  if ( ! -f "$f_osrm" or  $self->{DEBUG_GET} > 0 or $force > 0) {
    $content = get($url);
    open(OSRM, ">",  $f_osrm) or die "osm_get() erreur:$! $f_osrm";
    print(OSRM $content);
    close(OSRM);
  } else {
    $content = do { open my $fh, '<', $f_osrm or die $!; local $/; <$fh> };
  }
  warn "osrm_get() f_osrm: $f_osrm";
#  exit;
  my $decoded_json = decode_json($content);
  my $legs = $decoded_json->{routes}[0]->{legs};
  my @nodes;
#  confess Dumper $legs;
  foreach my $leg (@$legs) {
    push @nodes, @{$leg->{annotation}->{nodes}};
  }
#  confess Dumper @nodes;
  return @nodes;
}
#
# liste des ways
sub osrm_get_ways {
  my $self = shift;
  my $query = shift;
  my @nodes = $self->osrm_get($query);

  my (@ways, $way, $way_prec, @ids, @ids_prec);
  warn "osrm_get_ways() nb nodes : " . scalar(@nodes);
  for (my $i=0; $i < scalar(@nodes); $i++) {
    warn $nodes[$i];
    my $url = sprintf("http://www.openstreetmap.org/api/0.6/node/%s/ways", $nodes[$i]);
    my $content = get($url);
#    (@ids) = ($content =~ m{<way id="(\d+)"}gsm );
#    warn $content;
    my $hash = $self->{oAPI}->osm2hash($content);
    undef @ids;
    for my $way ( @{$hash->{way}} ) {
      if ( not defined $way->{'tags'}->{'highway'} ) {
        next;
      }
      push @ids, $way->{id};
#      warn Dumper $way;
    }
#    warn Dumper \@ids; exit;
    my %count = ();
    my @intersect;
    foreach my $id (@ids, @ids_prec) {
      $count{$id}++;
      if ( $count{$id} > 1 ) {
        push @intersect, $id;
      }
    }
#    warn Dumper \@intersect;
    if ( scalar(@intersect) == 1 ) {
      $way = $intersect[0];
      if ( $way ne $way_prec ) {
        push @ways, $way;
      }
      $way_prec = $way;
    } else {
      if ( $i > 0 ) {
        warn "****" .  scalar(@intersect);
#        exit;
      }
    }
    @ids_prec = @ids;
  }
  foreach my $way (@ways) {
    print "  wy $way\n";
  }
}
#
# liste des parcours
#  perl scripts/keolis.pl star osrm_get_parcours
sub osrm_get_parcours {
  my $self = shift;
  my $dsn = 'd:/web.var/geo/STAR/tco-bus-topologie-parcours-td.geojson';
  my $json = do { open my $fh, '<', $dsn or die $!; local $/; <$fh> };
  my $decoded_json = decode_json($json);
#  confess Dumper $decoded_json;
  my $features = $decoded_json->{'features'};
  my $coordinates;
  foreach my $feature (@$features) {
#    confess Dumper $feature;
    my $id = $feature->{'properties'}->{'id'};
    if ( $id ne $self->{shape} ) {
      next;
    }
    warn $feature->{'properties'}->{'id'};
#    confess Dumper $feature;
    $coordinates = $feature->{'geometry'}->{'coordinates'};
    last;
  }
  warn "osrm_get_parcours() nb coordinates: " . scalar(@$coordinates);
#  confess Dumper $coordinates;
  my $lon1 = @$coordinates[0]->[0];
  my $lat1 = @$coordinates[0]->[1];
  my $query = "$lon1,$lat1";
  for (my $i=1; $i < scalar(@$coordinates); $i++) {
    my $lon2 = @$coordinates[$i]->[0];
    my $lat2 = @$coordinates[$i]->[1];
    my $distance = haversine_distance_meters($lat2, $lon2, $lat1, $lon1);
    if ( $distance < 30 ) {
      next;
    }
#    warn "$lon2, $lat2 : $distance";
    $lon1 = $lon2;
    $lat1 = $lat2;
    $query .= sprintf(";%0.5f,%0.5f",$lon1, $lat1);
  }
#  warn $query;
  $self->osrm_get_ways($query);
}
1;