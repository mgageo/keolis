# <!-- coding: utf-8 -->
#
# les traitements sur les données gtfs
#
#
package Transport;
use utf8;
use strict;
use DBI;
use Storable qw(store retrieve);
#
# les données gtfs
# ================
#
#
# récupération d'un fichier csv
# https://metacpan.org/pod/DBD::CSV
sub gtfs_table_get {
  my $self = shift;
  $self->gtfs_dbi_sqlite();
  my $table = shift;
  my $where = '';
  if ( @_ ) {
    $where = shift;
  }
  my $order = '';
  if ( @_ ) {
    $order = shift;
  }
  my $stmt = "SELECT * FROM ${table} ${where} ${order}";
  $stmt = "select * from $table";
  warn "gtfs_table_get() $stmt";
  my $sth = $self->{dbh}->prepare($stmt);
  my $rv = $sth->execute or die $DBI::errstr;;
  if($rv < 0){
    confess "gtfs_table_get ". $DBI::errstr;
  }
  @{$self->{table}->{$table}} = ();
  while(my $hash = $sth->fetchrow_hashref()) {
#    confess Dumper $hash;    return;
#    delete $hash->{Geometry};
#    delete $hash->{geom2154};
    push @{$self->{table}->{$table}}, $hash;
  }
  warn "gtfs_table_get() table: ${table} nb: " . scalar( @{$self->{table}->{$table}});
  return $self->{table}->{$table};
}
sub gtfs_table_select {
  my $self = shift;
  my $table = shift;
  my $where = '';
  if ( @_ ) {
    $where = shift;
  }
  my $order = '';
  if ( @_ ) {
    $order = shift;
  }
  my $stmt = "SELECT * FROM ${table} ${where} ${order};";
  warn "table_select() $stmt";
  my $sth = $self->{dbh}->prepare( $stmt );
  my $rv = $sth->execute() or die $DBI::errstr;
  if($rv < 0){
    confess "gtfs_table_select() ". $DBI::errstr;
  }
  @{$self->{table}->{$table}} = ();
  while(my $hash = $sth->fetchrow_hashref()) {
#    confess Dumper $hash;    return;
    delete $hash->{Geometry};
    delete $hash->{geom2154};
    push @{$self->{table}->{$table}}, $hash;
  }
  warn "gtfs_table_select() table: ${table} nb: " . scalar( @{$self->{table}->{$table}});
}
# récupération d'un fichier csv
# https://metacpan.org/pod/DBD::CSV
sub gtfs_dbi_csv {
  my $self = shift;
  $self->{dbh} = DBI->connect ("dbi:CSV:", undef, undef, {
    f_dir   => $self->{gtfs}->{dir},
    f_ext   => ".txt/r",
    f_encoding   => "utf-8",
    csv_eol          => "\r\n",
    csv_sep_char     => ",",
    csv_quote_char   => '"',
    csv_escape_char  => '"',
  });
}
sub gtfs_dbi_sqlite {
  my $self = shift;
  my $dbname="KEOLIS/35000_network.sqlite";
  if ( @_ ) {
    $dbname = shift;
  }
  warn "gtfs_dbi_sqlite dbname:$dbname";
  if ( ! -f $dbname ) {
    confess "*** $dbname";
  }
  $self->{dbh} = DBI->connect("dbi:SQLite:dbname=$dbname"
	  , ""
	  , ""
	  , {
        PrintError => 1
      , AutoCommit => 0
      , RaiseError => 1
      , sqlite_unicode => 1
    }
  ) or die $DBI::errstr;
#  my @tables = $self->{dbh}->tables();
#  warn Dumper \@tables;
}
# récupération des routes avec indexation par route_short_name # osm ref
sub gtfs_routes_get {
  my $self = shift;
  $self->gtfs_table_get('routes', 'where `agency_id` eq "' .  $self->{gtfs}->{agency_id} . '"' );
#  confess Dumper $self->{oDB}->{table}->{routes};
  my $routes;
  for my $route ( @{$self->{table}->{routes}} ) {
    if ( $route->{agency_id} ne $self->{gtfs}->{agency_id} ) {
      next;
    }
#  	warn Dumper $route;
    $routes->{$route->{route_short_name}} = $route;
  }
#  confess Dumper $routes;
  warn "gtfs_routes_get() nb:".scalar(keys %{$routes});
  return $routes;
}
# récupération des routes avec indexation par route_id
sub gtfs_routeid_get {
  my $self = shift;
  $self->gtfs_table_get('routes', 'where `agency_id` eq "' .  $self->{gtfs}->{agency_id} . '"' );
#  confess Dumper $self->{oDB}->{table}->{routes};
  my $routes;
  for my $route ( @{$self->{table}->{routes}} ) {
    if ( $route->{agency_id} ne $self->{gtfs}->{agency_id} ) {
      next;
    }
#  	warn Dumper $route;
    $routes->{$route->{route_id}} = $route;
  }
#  confess Dumper $routes;
  warn "gtfs_routeid_get() nb:".scalar(keys %{$routes});
  return $routes;
}
# récupération des voyages d'une route
sub gtfs_trips_get {
  my $self = shift;
  $self->gtfs_table_get('trips', 'where `route_id` eq "' .  $self->{gtfs}->{route_id} . '"' );
#  confess Dumper $self->{oDB}->{table}->{trips};
  my $trips;
  for my $trip ( @{$self->{table}->{trips}} ) {
    if ( $trip->{route_id} ne $self->{gtfs}->{route_id} ) {
      next;
    }
#  	warn Dumper $trip;
    $trips->{$trip->{trip_id}} = $trip;
  }
#  confess Dumper $trips;
  my $nb = scalar(keys %{$trips});
  warn "gtfs_trips_get() nb:" . $nb;
  if ( $nb == 0 ) {
    confess;
  }
  return $trips;
}
# récupération des voyages de plusieurs routes
sub gtfs_tripid_get {
  my $self = shift;
  my $routes = $self->gtfs_routeid_get();
  $self->gtfs_table_get('trips', 'where `route_id` eq "' .  $self->{gtfs}->{route_id} . '"' );
#  confess Dumper $self->{oDB}->{table}->{trips};
  my $trips;
  for my $trip ( @{$self->{table}->{trips}} ) {
    my $k = $trip->{route_id};
    if ( ! exists $routes->{$k} ) {
      next;
    }
#  	warn Dumper $trip;
    $trips->{$trip->{trip_id}} = $trip;
  }
#  confess Dumper $trips;
  warn "gtfs_tripid_get() nb:".scalar(keys %{$trips});
  return $trips;
}
# récupération des stop_times pour une route
sub gtfs_stop_times_get {
  my $self = shift;
  my $trips = $self->gtfs_trips_get();
  $self->gtfs_table_get('stop_times', 'where `route_id` eq "' .  $self->{gtfs}->{route_id} . '"' );
#  confess Dumper $self->{oDB}->{table}->{trips};
  my $stop_times;
  for my $stop_time ( @{$self->{table}->{stop_times}} ) {
    my $k = $stop_time->{trip_id};
    if ( ! exists $trips->{$k} ) {
      next;
    }
#  	confess Dumper $stop_time;
    $trips->{$k}->{$stop_time->{stop_sequence}} = $stop_time;
    $trips->{$k}->{nb_stops}++;
    $stop_times->{$stop_time->{stop_id}} = $stop_time;
  }
#  confess Dumper $stop_times;
  warn "gtfs_stop_times_get() nb: ".scalar(keys %{$stop_times});
  my $dsn = "$self->{cfgDir}/stop_times.dmp";
  store($stop_times, $dsn);
  warn "gtfs_stop_times_get() dsn: " . $dsn;
  $self->{trips} = $trips;
  warn "gtfs_stop_times_get() nb: ".scalar(keys %{$trips});
  my $dsn = "$self->{cfgDir}/trips_stops.dmp";
  store($trips, $dsn);
  warn "gtfs_stop_times_get() dsn: " . $dsn;
  return $stop_times;
}
# récupération des stop_times pour des routes
sub gtfs_stop_time_id_get {
  my $self = shift;
  my $trips = $self->gtfs_tripid_get();
  $self->gtfs_table_get('stop_times', 'where `route_id` eq "' .  $self->{gtfs}->{route_id} . '"' );
#  confess Dumper $self->{oDB}->{table}->{trips};
  my $stops;
  for my $stop_time ( @{$self->{table}->{stop_times}} ) {
    my $k = $stop_time->{trip_id};
    if ( ! exists $trips->{$k} ) {
      next;
    }
    $stops->{$stop_time->{stop_id}} = $stop_time;
  }
#  confess Dumper $stop_times;
  warn "gtfs_stop_time_id_get() nb: ".scalar(keys %{$stops});
  my $dsn = "$self->{cfgDir}/gtfs_stop_time_id.dmp";
  store($stops, $dsn);
  warn "gtfs_stop_time_id_get() dsn: " . $dsn;
  return $stops;
}
# récupération des stop_time_id
sub gtfs_stop_time_id_lire {
  my $self = shift;
  my $dsn = "$self->{cfgDir}/gtfs_stop_time_id.dmp";
  my $stops = retrieve($dsn);
  carp "dsn: " . $dsn;
#  confess Dumper $stops;
  return $stops;
}
# récupération des trips_stops
sub gtfs_trips_stops_lire {
  my $self = shift;
  my $dsn = "$self->{cfgDir}/trips_stops.dmp";
  my $trips_stops = retrieve($dsn);
  carp "dsn: " . $dsn;
#  confess Dumper $stops;
  return $trips_stops;
}
# récupération des stops d'une route
sub gtfs_stops_get {
  my $self = shift;
  my $stop_times = $self->gtfs_stop_times_get();
  $self->gtfs_table_get('stops', 'where `stop_id` eq "' .  $self->{gtfs}->{route_id} . '"' );
#  confess Dumper $self->{oDB}->{table}->{trips};
  my $stops;
  for my $stop ( @{$self->{table}->{stops}} ) {
    my $k = $stop->{stop_id};
    if ( ! exists $stop_times->{$k} ) {
      next;
    }
#  	warn Dumper $stop;
    $stops->{$stop->{stop_id}} = $stop;
  }
#  confess Dumper $stops;
  warn "gtfs_stops_get() nb: ".scalar(keys %{$stops});
  my $dsn = "$self->{cfgDir}/stops.dmp";
  store($stops, $dsn);
  warn "gtfs_stops_get() dsn: " . $dsn;
  return $stops;
}
# récupération des stops d'un réseau
sub gtfs_stop_id_get {
  my $self = shift;
  my $stop_times = $self->gtfs_stop_time_id_lire();
  $self->gtfs_table_get('stops', 'where `stop_id` eq "' .  $self->{gtfs}->{route_id} . '"' );
#  confess Dumper $self->{oDB}->{table}->{trips};
  my $stops;
  for my $stop ( @{$self->{table}->{stops}} ) {
    my $k = $stop->{stop_id};
    if ( ! exists $stop_times->{$k} ) {
      next;
    }
#  	warn Dumper $stop;
    $stops->{$stop->{stop_id}} = $stop;
  }
#  confess Dumper $stops;
  warn "gtfs_stop_id_get() nb: ".scalar(keys %{$stops});
  my $dsn = "$self->{cfgDir}/gtfs_stop_id.dmp";
  store($stops, $dsn);
  warn "gtfs_stop_id_get() dsn: " . $dsn;
  return $stops;
}
# récupération des stops
sub gtfs_stop_id_lire {
  my $self = shift;
  my $dsn = "$self->{cfgDir}/gtfs_stop_id.dmp";
  my $stops = retrieve($dsn);
#  confess Dumper $stops;
  return $stops;
}
# récupération des stops
sub gtfs_stops_lire {
  my $self = shift;
  my $dsn = "$self->{cfgDir}/stops.dmp";
  my $stops = retrieve($dsn);
#  confess Dumper $stops;
  return $stops;
}
# récupération des stops
sub gtfs_stops_create {
  my $self = shift;
  my $dsn = "$self->{cfgDir}/stops.dmp";
  my $stops = $self->gtfs_stops_lire();
  my $osm = '';
  for my $s ( keys(%$stops) ) {
    my $stop = $stops->{$s};
    my $ql = sprintf("node(around:5, %s,%s)->.a;(node.a[highway=bus_stop];node.a[public_transport];);out meta;", $stop->{stop_lat}, $stop->{stop_lon});
    warn $ql;
    my $hash = $self->oapi_get($ql, "$self->{cfgDir}/gtfs_stops_create.osm", 1);
    if ( scalar(@{$hash->{node}}) > 0 ) {
      next;
    }
#    warn Dumper $stop;
    $osm .= $self->gtfs_node_stop_create($stop);
#    last;
  }
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'create');
  return;
}
sub gtfs_node_stop_create {
  my $self = shift;
  my $hash = shift;
  my $format = <<'EOF';
  <node lat="%s" lon="%s" id="%s" timestamp="0" changeset="1" version="1">
    <tag k="highway" v="bus_stop"/>
    <tag k="public_transport" v="platform"/>
    <tag k="name" v="%s"/>
    <tag k="ref:%s" v="%s"/>
  </node>
EOF
  $self->{node_id}--;
  return sprintf($format, $hash->{stop_lat}, $hash->{stop_lon}, $self->{node_id}, $hash->{stop_name}, $self->{network}, $hash->{stop_id});
}
1;