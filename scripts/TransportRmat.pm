# <!-- coding: utf-8 -->
#
# les informations du Réseau Malo Agglomération Transport
# http://www.rmat.fr/fileadmin/Sites/rmat/documents/timeo/Liste_des_codes_TIMEO_hiver_au_2604.pdf
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
#
# pour mettre à jour les bus_stop
sub rmat_bus_stop_diff {
  my $self = shift;
  warn "rmat_bus_stop_diff() debut";
  my $hash = $self->oapi_get("node(area:3601970852);node(around:1000)[highway=bus_stop];out meta;", "$self->{cfgDir}/rmat_bus_stop_diff.osm");
}
#
# liste des routes avec les arrêts
sub rmat_routes_liste {
  my $self = shift;
  warn "rmat_routes_liste() debut";
  $self->rmat_timeo();
#
# pour remplacer les stop par des platform
#  $self->stop2platform();
  my $hash = $self->oapi_get("relation[network='$self->{network}'][type=route][route=bus];>>;out meta;", "$self->{cfgDir}/rmat_bus_stop_liste.osm");
  $self->{csv} = 'id;ref;name;description;from;to';
  $self->{tags_nodes} = ();
  foreach my $relation (sort tri_tags_ref @{$hash->{relation}}) {
    if ( $relation->{tags}->{ref} !~ m{^$self->{ref}\D*} ) {
      next;
    }
    $self->rmat_route_liste($relation, $hash);
  }
  my $f_txt = "$self->{cfgDir}/routes_osm.txt";
  open(TXT, ">:utf8", $f_txt) or die;
  print TXT $self->{csv};
  close(TXT);
  warn "rmat_routes_liste() $f_txt";
  for my $tag (sort keys %{$self->{tags_nodes}} ) {
    printf("% 20s %5d\n", $tag, $self->{tags_nodes}->{$tag});
  }
  for my $id ( sort keys %{$self->{arrets}} ) {
    my $m = $hash->{osm}->{node}->{$id};
    printf("%s % 30s %s\n", $id, $m->{tags}->{name}, join(',', @{$self->{arrets}->{$id}}));
  }
}
sub rmat_route_liste {
  my $self = shift;
  warn "rmat_route_liste() debut";
  my $relation = shift;
  my $hash = shift;
  printf("r%s ;ref:%s;%s;%s;%s;%s\n", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp}, scalar(@{$relation->{nodes}}), scalar(@{$relation->{ways}}));
  printf("\t%s\n", $relation->{tags}->{name});
  printf("\t%s\n", $relation->{tags}->{description});
  printf("\t%s;%s\n", $relation->{tags}->{from}, $relation->{tags}->{to});
  $self->{csv} .= sprintf("\n%s;%s;%s;%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{tags}->{name}, $relation->{tags}->{description}, $relation->{tags}->{from}, $relation->{tags}->{to});
  my $ref = $relation->{tags}->{'ref:network'};
# vérification du type des nodes
  my $ordre = 0;
  my $osm = '';
  for my $member ( @{$relation->{member}} ) {
    if ( $member->{role} !~ m{(platform|stop)} ) {
      next;
    };
    $ordre++;
    my $m = $hash->{osm}->{$member->{type}}->{$member->{ref}};
    push @{$self->{arrets}->{$m->{id}}}, $relation->{tags}->{ref};
    if ( $member->{type} ne 'node' ) {
      printf("\t*** %s %s %s\n", $member->{type}, $member->{ref}, $m->{tags}->{name} );
#      confess;
    };
#    next;
#    warn Dumper $hash->{osm}->{$member->{type}}->{$member->{ref}};
    printf("\t%02D %s %s n%s %s\n", $ordre, $m->{tags}->{name}, $m->{tags}->{public_transport}, $m->{id}, $self->{routes}->{$ref}->{arrets}->{$ordre});
    $self->rmat_node_valid($m);
    if ( $member->{role} ne $m->{tags}->{public_transport} ) {
      printf("\t*** %s # %s n%s\n", $member->{role}, $m->{tags}->{public_transport}, $m->{id} );
      if ( not defined  $self->{stop2platform}->{$member->{ref}} ) {
        next;
      }
      my $n = $self->{stop2platform}->{$member->{ref}};
      if ( $osm eq '' ) {
        $osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $relation->{id}));
        $osm = $self->{oOSM}->delete_osm($osm);
      }
      my $avant = sprintf('<member type="node" ref="%s"', $member->{ref});
      my $apres = sprintf('<member type="node" ref="%s"', $n);
      printf("\t%s => %s\n", $avant, $apres);
      $osm =~ s{$avant}{$apres};
    }
#    confess Dumper $member;
  }
  if ( $osm ne '' ) {
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . " passage en platform", 'modify');
#    confess $osm;
  }
}
sub rmat_node_valid {
  my $self = shift;
  my $node = shift;
  my $tags = {
    'highway' => 'bus_stop',
    'public_transport:version' => '2',
    'website' => 'https://www.reseau-mat.fr/',
    'network' => 'FR:Réseau MAT',
  };
  for my $tag ( keys %{$node->{tags}} ) {
    $self->{tags_nodes}->{$tag}++;
  }
  my $nb_absent = 0;
  my $nb_diff = 0;
#    confess Dumper $node;
  for my $tag ( keys %{$tags} ) {
    if ( not defined $node->{tags}->{$tag} ) {
      warn "rmat_node_valid() absent $node->{id} tag:$tag";
#      warn Dumper $node;
      $nb_absent++;
      next;
    }
    if ( $tags->{$tag} ne $node->{tags}->{$tag} ) {
      warn "rmat_node_valid() diff $node->{id} tag:$tag " . $node->{tags}->{$tag};
      $nb_diff++;
    }
  }
  if ( $nb_absent == 0 && $nb_diff == 0) {
    return;
  }
  warn "rmat_node_valid() n$node->{id}  $nb_absent == 0 $nb_diff == 0";
#  return;
  my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{id}));
#    confess $node_osm;
  $node_osm = $self->{oOSM}->modify_tags($node_osm, $tags, keys %{$tags});
  $self->{oAPI}->changeset($node_osm, $self->{osm_commentaire} . " correction noeud arret", 'modify');
#  exit;
}
sub rmat_masters {
  my $self = shift;
  warn "rmat_masters()";
  my $f_txt = "$self->{cfgDir}/masters.txt";
  open(TXT, "< :utf8", $f_txt) or die;
  my $ligne = <TXT>;
  while( my $ligne = <TXT>) {
    chomp($ligne);
    my ($id, $ref, $description, $colour, $text_colour) = split(";", $ligne);
#    $name =~ s{(\S)<}{$1 <}g;
#    warn "$ref => $name";
    $self->{masters}->{$ref} = {
      id => $id,
      description => $description,
      colour => uc($colour),
      text_colour => uc($text_colour),
      name => sprintf("%s %s", 'Réseau MAT ligne', $ref)
    };
  }
  close(TXT);
}
#
# lecture du fichier de configuration des routes
sub rmat_routes {
  my $self = shift;
  $self->rmat_masters();
  warn "rmat_routes()";
  my $f_txt = "$self->{cfgDir}/routes.txt";
  open(TXT, "<:utf8", $f_txt) or die;
  my $ligne = <TXT>;
  while( my $ligne = <TXT>) {
    chomp($ligne);
#    warn $ligne;
    my ($id, $ref_network, $ref, $name, $description, $from, $to) = split(";", $ligne);
    if ( not defined $self->{masters}->{$ref} ) {
      confess $ligne;
    }
    $self->{routes}->{$ref_network} = {
      id => $id,
      ref => $ref,
      'ref:network' => $ref_network,
      name => $name,
      description => $description,
      from => $from,
      to => $to,
      text_colour => $self->{masters}->{$ref}->{text_colour},
      colour => $self->{masters}->{$ref}->{colour},
    };
  }
  close(TXT);
}
sub rmat_routes_verif {
  my $self = shift;
  warn "rmat_routes_verif()";
  $self->rmat_routes();
#  confess Dumper %{$self->{routes}};
  for my $ref ( keys %{$self->{routes}} ) {
    warn "ref:$ref";
    my $r = $self->{routes}->{$ref};
    my $osm = get(sprintf("https://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $r->{'id'}));
    delete $r->{'id'};
    $r->{name} = xml_escape($r->{name});
    $r->{description} = xml_escape($r->{description});
    my @keys = keys %{$r};
    $osm = $self->{oOSM}->modify_tags($osm, $r, @keys);
#    warn $osm;
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');
  }
}
sub rmat_masters_verif {
  my $self = shift;
  warn "rmat_masters_verif()";
  $self->rmat_masters();
#  confess Dumper %{$self->{routes}};
  for my $ref ( keys %{$self->{masters}} ) {
    warn "ref:$ref";
    my $r = $self->{masters}->{$ref};
    my $osm = get(sprintf("https://api.openstreetmap.org/api/0.6/%s/%s", 'relation', $r->{'id'}));
    delete $r->{'id'};
    $r->{name} = xml_escape($r->{name});
    $r->{description} = xml_escape($r->{description});

    my @keys = keys %{$r};
    $osm = $self->{oOSM}->modify_tags($osm, $r, @keys);
#    warn $osm;
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'modify');
  }
}
# fichier pourri : accents sur les noms, un seul arrêt
sub rmat_arrets {
  my $self = shift;
  warn "rmat_arrets()";
  my $f_csv = "$self->{cfgDir}/emplacement-des-arrets-de-bus-du-reseau-transport-saint-malo-agglomeration.csv";
  open(CSV, "< :utf8",  $f_csv) or die "...() erreur:$! $f_csv";
  while( my $ligne = <CSV>) {
    chomp($ligne);
    my ($ID, $nom, $Point, $XCOORD, $YCOORD) = split(/;/, $ligne);
  }
  close(CSV);
}
# https://smallpdf.com/fr/pdf-en-excel
sub rmat_timeo {
  my $self = shift;
  warn "rmat_timeo()";
  $self->rmat_routes();
  my $f_csv = "$self->{cfgDir}/Liste_des_codes_TIMEO_ete_2018_3.csv";
  open(CSV, "<:utf8",  $f_csv) or die "...() erreur:$! $f_csv";
  my $Ligne = '';
  my $Desc = '';
  my $ordre = 0;
  my $ref = '';
  my $From = '';
  my $To = '';
  while( my $ligne = <CSV>) {
    chomp($ligne);
#    warn $ligne;
    if ( $ligne =~ m{^(Ligne.*);(.*)} ) {
      $Desc = $1;
      $ref = $2;
      ($Ligne, $From, $To) = ($Desc =~ m{Ligne (.*) : Sens : (.*) vers (.*)}i);
      $ordre=0;
#      printf("%s;%s;%s;%s;%s\n", $Ligne, $From, $To, $self->{routes}->{$ref}->{from}, $self->{routes}->{$ref}->{to});
#      confess Dumper $self->{routes}->{$ref};
      next;
    }
    if ( $ligne =~ m{^Nom des arr} ) {
      next;
    }
    if ( $ligne =~ m{^;} ) {
      next;
    }
    $ordre++;
#    printf("%s;%s;%s\n", $ref, $ordre, $ligne);
    $self->{routes}->{$ref}->{arrets}->{$ordre} = $ligne;
  }
  close(CSV);
}
sub rmat_timeo_v0 {
  my $self = shift;
  warn "rmat_timeo()";
  my $f_txt = "$self->{cfgDir}/timeo.txt";
  open(TXT, "< :utf8", $f_txt) or die;
  while( my $ligne = <TXT>) {
    chomp($ligne);
# Ligne 1 : Sens : INTRA-MUROS vers LA MADELEINE
    if ( $ligne =~ m{^Ligne (.*) : Sens : (.*)} ) {
      my ($ref, $sens) = ($1, $2);
      warn "$ref, $sens";
      next;
    }
  }
  close(TXT);
}
#
# pour mettre à jour les relations "route"
sub rmat_routes_diff {
  my $self = shift;
  warn "rmat_routes_diff() debut";
  $self->rmat_routes();
  my $hash = $self->oapi_get("relation[network='$self->{network}'][type=route][route=bus];out meta;", "$self->{cfgDir}/routes_diff.osm");
  my $level0 = '';
  foreach my $relation (@{$hash->{relation}}) {
    my $ref_network = $relation->{tags}->{'ref:network'};
    warn sprintf("rmat_routes_diff() r%s ;ref:%s;%s;%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp}, scalar(@{$relation->{nodes}}), scalar(@{$relation->{ways}}));
    $level0 .= 'r' . $relation->{id} . ',';
    $self->{id} = $relation->{id};
    if ( $relation->{tags}->{ref} =~ m{P\+R} ) {
#      next;
    }
    $self->rmat_route_diff($relation);
  }
  chop $level0;
  warn "rmat_routes_diff() level0: $level0";
}
sub rmat_route_diff {
  my $self = shift;
  my $relation = shift;
  warn "rmat_route_diff() debut";
  my $id = $relation->{id};
  my $ref = $relation->{tags}->{'ref:network'};
  if ( not defined $self->{routes}->{$ref} ) {
    warn "ref:$ref";
    return;
  }
  my $tags = $self->{routes}->{$ref};
  $tags = { %$tags, %{$self->{tags}} };
  $self->osm_tags_valid($relation, $tags);
  warn "rmat_route_diff() fin";
}
#
# pour mettre à jour les relations "route"
sub rmat_routes_master_diff {
  my $self = shift;
  warn "rmat_routes_master_diff() debut";
  $self->rmat_masters();
  my $hash = $self->oapi_get("relation[network='$self->{network}'][type=route_master][route_master=bus];out meta;", "$self->{cfgDir}/routes_master_diff.osm");
  my $level0 = '';
# on indexe par ref
  my $refs;
  foreach my $relation (@{$hash->{relation}}) {
    $refs->{$relation->{tags}->{ref}} = $relation;
    warn sprintf("rmat_routes_master_diff() r%s ;ref:%s;%s;%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp}, scalar(@{$relation->{nodes}}), scalar(@{$relation->{ways}}));
    $level0 .= 'r' . $relation->{id} . ',';
    $self->rmat_route_master_diff($relation);
#    $self->valid_route_master();
  }
  chop $level0;
  warn "rmat_routes_master_diff() level0: $level0";
  exit;
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
    <tag k="name" v="Bus Saint-Malo Ligne %s"/>
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
    my $osm = sprintf($format , $self->{relation_id}, xml_escape($iti->{name}), $ref, $self->{network}, $self->{operator}, $ref, $iti->{bgcolor}, $iti->{color}, $self->{source});
    $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'create');
  }
}
sub rmat_route_master_diff {
  my $self = shift;
  warn "rmat_route_master_diff() debut";
  my $relation = shift;
  my $id = $relation->{id};
  my $ref = $relation->{tags}->{'ref'};
  if ( not defined $self->{masters}->{$ref} ) {
    warn "ref:$ref";
    return;
  }
  my $tags = $self->{masters}->{$ref};
  $tags = { %$tags, %{$self->{tags}} };
  $self->osm_tags_valid($relation, $tags);
  warn "rmat_route_master_diff() fin";
}
#

sub rmat_network_create {
  my $self = shift;
  warn "rmat_network_create) debut";
  $self->{relation_id}--;
#  warn Dumper $iti;
  my $format = <<'EOF';
  <relation id="%s" timestamp="0" changeset="1" version="1">
    <tag k="network" v="%s"/>
    <tag k="public_transport" v="network"/>
    <tag k="type" v="network"/>
     <tag k="source" v="%s"/>
  </relation>
EOF
  my $osm = sprintf($format, $self->{relation_id}, $self->{network}, $self->{source});
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire}, 'create');
}
#
# pour mettre le tag stop_position
sub stop_position_verif {
  my $self = shift;
  warn "stop_position_verif() début";
  my $hash = $self->oapi_get("node[network='FR:Réseau MAT']->.a;way(bn.a)->.b;node(w.b)[highway=bus_stop];out meta;", "$self->{cfgDir}/stop_position_verif.osm");
  my $osm = '';
  my $nb_osm = 0;
  my $tags = {
    'highway' => 'bus_stop',
    'public_transport' => 'stop_position',
    'public_transport:version' => '2'
  };
  my %tags;
  for my $node ( @{$hash->{node}} ) {
    for my $tag ( keys %{$node->{tags}} ) {
      $tags{$tag}++;
    }
    my $nb_absent = 0;
    my $nb_diff = 0;
#    confess Dumper $node;
    for my $tag ( keys %{$tags} ) {
      if ( not defined $node->{tags}->{$tag} ) {
        warn "bus_stop_tag_next() absent $node->{id} tag:$tag";
#        warn Dumper $node;
        $nb_absent++;
      }
      if ( $tags->{$tag} ne $node->{tags}->{$tag} ) {
        $nb_diff++;
      }
    }
    if ( $nb_absent == 0 && $nb_diff == 0) {
      next;
    }
    warn "stop_position_verif() $node->{id}  $nb_absent == 0 $nb_diff == 0";
    $nb_osm++;
    my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{id}));
#    confess $node_osm;
    $node_osm = $self->{oOSM}->modify_tags($node_osm, $tags, keys %{$tags});
    $osm .= $node_osm . "\n";
    if ( $nb_osm > 10 ) {
#      last;
    }
#    confess Dumper $osm;
  }
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . " correction stop_position", 'modify');
  for my $tag (sort keys %tags) {
    printf("% 20s %5d\n", $tag, $tags{$tag});
  }
  warn "stop_position_verif() fin $nb_osm";
}
# pour mettre le tag public_transport
sub public_transport_verif {
  my $self = shift;
  warn "public_transport_verif() début";
  my $hash = $self->oapi_get("node[network='FR:Réseau MAT'][!'public_transport'];out meta;", "$self->{cfgDir}/public_transport_verif.osm");
  my $osm = '';
  my $nb_osm = 0;
  my $tags = {
    'highway' => 'bus_stop',
    'public_transport' => 'platform',
    'public_transport:version' => '2'
  };
  my %tags;
  for my $node ( @{$hash->{node}} ) {
    for my $tag ( keys %{$node->{tags}} ) {
      $tags{$tag}++;
    }
    my $nb_absent = 0;
    my $nb_diff = 0;
#    confess Dumper $node;
    for my $tag ( keys %{$tags} ) {
      if ( not defined $node->{tags}->{$tag} ) {
        warn "bus_stop_tag_next() absent $node->{id} tag:$tag";
#        warn Dumper $node;
        $nb_absent++;
      }
      if ( $tags->{$tag} ne $node->{tags}->{$tag} ) {
        $nb_diff++;
      }
    }
    if ( $nb_absent == 0 && $nb_diff == 0) {
      next;
    }
    warn "public_transport_verif() $node->{id}  $nb_absent == 0 $nb_diff == 0";
    $nb_osm++;
    my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{id}));
#    confess $node_osm;
    $node_osm = $self->{oOSM}->modify_tags($node_osm, $tags, keys %{$tags});
    $osm .= $node_osm . "\n";
    if ( $nb_osm > 10 ) {
#      last;
    }
#    confess Dumper $osm;
  }
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . " correction public_transport", 'modify');
  for my $tag (sort keys %tags) {
    printf("% 20s %5d\n", $tag, $tags{$tag});
  }
  warn "public_transport_verif() fin $nb_osm";
}

#
# pour ajouter des "platform" à partir des stop_position
sub stop2platform {
  my $self = shift;
  warn "stop2platform() début";
  my $hash_stop = $self->oapi_get("relation[network='FR:Réseau MAT'][type=route][route=bus]->.a;node(r.a)[public_transport=stop_position];out meta;", "$self->{cfgDir}/stop2platform_stop.osm");
  my $hash_platform = $self->oapi_get("node[network='FR:Réseau MAT'][public_transport=platform];out meta;", "$self->{cfgDir}/stop2platform_platform.osm");
  for my $node ( @{$hash_stop->{node}} ) {
#    confess Dumper $node;
    if ( $node->{tags}->{name} =~ m{Gares} ) {
      next;
    }
    if ( $node->{tags}->{name} !~ m{Cottages} ) {
#      next;
    }
    printf("n%s %s\n", $node->{id}, $node->{tags}->{name});
    my $platform = -1;
    for my $n ( @{$hash_platform->{node}} ) {
      my $d = haversine_distance_meters($node->{lat}, $node->{lon}, $n->{lat}, $n->{lon});
#      printf("\t %02d n%s %s\n", $d, $n->{id}, $n->{tags}->{name});
      if ( $d > 6 ) {
        next;
      }
      printf("\t %02d n%s %s\n", $d, $n->{id}, $n->{tags}->{name});
      $platform = $n->{id};
    }
    if ( $platform > 0 ) {
      $self->{stop2platform}->{$node->{id}} = $platform;
      next;
    }
    my $node_stop = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $node->{id}));
    warn $node_stop;
    my $node_platform = $node_stop;
    $node_platform =~ s{stop_position}{platform};
    $self->{node_id}--;
    my $xml = sprintf('<node id="%s" timestamp="0" changeset="1" version="1" lon="%5f" lat="%5f">', $self->{node_id}, $node->{lon}+0.00005, $node->{lat});
    $node_platform =~ s{<node[^>]+}{$xml};
    $node_platform = $self->{oOSM}->delete_osm($node_platform);

    warn $node_platform;
    $self->{oAPI}->changeset($node_platform, $self->{osm_commentaire} . " ajout platform", 'create');
#    confess;
  }
}
#
# les noeuds platforms trop proches
sub rmat_platforms_proche {
  my $self = shift;
  $self->mobibreizh_platform_lit();
  foreach my $n (keys %{$self->{platform}} ) {
    my $node = $self->{platform}->{$n};
#    confess Dumper $node;
    $self->rmat_platform_proche($node);
  }
}
#
# un noeud platform versus les stops
sub rmat_platform_proche {
  my $self = shift;
  my $node = shift;
  my $distance = 500000;
  my $n1;
  foreach my $n (keys %{$self->{platform}} ) {
    my $node1 = $self->{platform}->{$n};
    if ( $node->{id} eq $node1->{id} ) {
      next;
    }
#    confess Dumper $stop;
    my $d = haversine_distance_meters($node->{lat}, $node->{lon}, $node1->{lat}, $node1->{lon});
    if ( $d < $distance ) {
      $distance = $d;
      $n1 = $node1;
    }
  }
  if ( $distance < 8 ) {
    warn "$distance n$node->{id} $node->{tags}->{name} $n1->{name}";
  }
}
#
# validation des tags d'u node/way/relation
sub osm_tags_valid {
  my $self = shift;
  my $osm = shift;
  my $tags = shift;
  my $nb_absent = 0;
  my $nb_diff = 0;
  delete $tags->{'id'};
#  $tags->{name} = xml_escape($tags->{name});
#  $tags->{description} = xml_escape($tags->{description});
#    confess Dumper $node;
  for my $tag ( keys %{$tags} ) {
    if ( not defined $osm->{tags}->{$tag} ) {
      warn "osm_tags_valid() absent $osm->{id} tag:$tag";
#      warn Dumper $node;
      $nb_absent++;
      next;
    }
    if ( $tags->{$tag} ne $osm->{tags}->{$tag} ) {
      warn "osm_tags_valid() diff $osm->{id} tag:$tag " . $osm->{tags}->{$tag};
      $nb_diff++;
    }
  }
  warn "osm_tags_valid() $osm->{osm}/$osm->{id} absent: $nb_absent diff: $nb_diff";
  if ( $nb_absent == 0 && $nb_diff == 0) {
    return 0;
  }
#  return;
#  warn Dumper $tags;
#  warn Dumper $osm->{tags};
#  confess;
  my $xml = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", $osm->{osm}, $osm->{id}));
#    confess $node_osm;
  $tags->{name} = xml_escape($tags->{name});
  $tags->{description} = xml_escape($tags->{description});
  $xml = $self->{oOSM}->modify_tags($xml, $tags, keys %{$tags});
  $self->{oAPI}->changeset($xml, $self->{osm_commentaire} . " correction tags", 'modify');
#  confess;
}
1;
