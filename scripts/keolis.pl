#!/usr/bin/perl
# <!-- coding: utf-8 -->
# keolis.pl
# auteur: Marc GAUTHIER
# licence : Paternité - Pas d’Utilisation Commerciale 2.0 France (CC BY-NC 2.0 FR)
# m.starbusmetro.fr
# http://wiki.openstreetmap.org/wiki/OSM_History_Viewer
# https://osm.athemis.de/
# http://www.predim.org/IMG/pdf/notices-donnees-v1.1.pdf
#
# quelques usages
# la mise à jour des arrêts
# perl scripts/keolis.pl  bus_stop diff_bus_stop
# la validation d'une relation route : arrêts versus gtfs
# perl scripts/keolis.pl --ref=33 route diff_route
# la validation des relations route_master
# perl scripts/keolis.pl route_master valid_routes_master 2> toto
# la validation de la relation network
#  perl scripts/keolis.pl  -d network valid_network
use strict;
use warnings;
use Carp;
use utf8;
use Data::Dumper;
use English;
use Cwd;
use LWP::Simple;
use LWP::Debug qw(+);
# use XML::Twig;
use XML::Simple;
use Getopt::Long;
use lib "scripts";


use Transport;
use TransportBicycle;
use TransportBusStop;
use TransportGtfs;
use TransportItiRoute;
use TransportNetwork;
use TransportOsrm;
use TransportParcours;
use TransportRoute;
use TransportRouteMaster;
use TransportStopArea;
use TransportKsma;
use TransportVitre;
use TransportChateaubourg;
use TransportIllenoo;
our $cfgDir = 'KEOLIS';
our $baseDir = getcwd;
our $Drive = substr($baseDir,0,2);
our $varDir = "$Drive/web.var/geo/${cfgDir}";
  $baseDir =~ s{/scripts}{};
  chdir($baseDir);
  select (STDERR);$|=1;
  select (STDOUT);$|=1;
  binmode STDOUT, ":utf8";  # assuming your terminal is UTF-8
  binmode STDERR, ":utf8";  # assuming your terminal is UTF-8
  if ( ! -d "$cfgDir" ) {
    mkdir("$cfgDir");
  }
  if ( ! -d "$varDir" ) {
    mkdir("$varDir");
  }
  our( $sp, $ssp, $ref, $id, $shape, $DEBUG, $DEBUG_GET );

#
# une série de variables globales, oui c'est sale !
our $oOSM; # l'objet pour produire du format OSM
our $oAPI; # l'objet pour faire les modifications avec l'API
our $oOAPI; # l'objet overpass
our $oDB; # l'objet base dedonnées
our $gtfs_routes; # la structure contenant les données des routes gtfs
our $gtfs_iti; # la structure contenant les données des itinéraires gtfs
our $gtfs_stops; # la structure contenant les données des arrêts gtfs
our $hash; # la structure contenant les données OSM
our (@nodes_modif, @stops_ajout); # le tableau des noeuds à modifier, ajouter
#
# les points d'entrée
  $sp = 'liste_routes';
  $sp = 'diff_route_master';
  $sp = 'valid_relation'; $ref= '1258954';
  $sp = 'valid_relation_type'; $ref= '79';
  $sp = 'valid_route_master'; $ref= '';
  $sp = 'valid_network'; $ref= '';
  $sp = 'osm_nodes_bus_stop_ref';
  $sp = 'diff_bus_stop';
  $sp = 'clean_line_bus';
  $sp = 'stop_area';
  $sp = 'route';
#  $sp = 'network';
#  $sp = 'route_master'; $ref='209';
  $sp = 'keolis'; $ssp = 'diff_routes_master'; # comparaision avec le gtfs
  $sp = 'keolis'; $ssp = 'valid_routes_master'; # validation des route_master
  $sp = 'keolis'; $ssp = 'valid_network'; # création d'une relation public_transport=network
#  $sp = 'Illenoo'; $ssp = 'create_network'; # création d'une relation public_transport=network
#  $sp = 'Illenoo'; $ssp = 'valid_network'; # création d'une relation public_transport=network
#  $sp = 'keolis'; $ssp = 'diff_routes'; # traitement de toutes les routes
  $sp = 'keolis'; $ssp = 'diff_bus_stop'; # traitement de tous les arrêts
#  $sp = 'keolis'; $ssp = 'diff_route'; $ref="95"; # traitement sur une route
#  $sp = 'keolis'; $ssp = 'stop_area'; #
#  $sp = 'keolis'; $ssp = 'bus_stop_hors'; # les nodes hors relations
#  $sp = 'keolis'; $ssp = 'disused_route_desc'; # modification de la description des disused
#  $sp = 'keolis'; $ssp = 'fromto_route'; # comparaison avec le gtfs + from to

#  $sp = 'illenoo';
#  $sp = 'test_haversine_distance_meters';
  $sp = 'aide';
  $id = '0001-01-A';
  $shape = '0200-A-4001-1007';
#  $sp = 'parcours'; $ssp = 'diff_parcours';
#  $sp = 'parcours'; $ssp = 'valid_parcours';
#  $sp = 'parcours'; $ssp = 'valid_routes_ways';
  $DEBUG = 1;  $DEBUG_GET = 1;
#  $DEBUG = 0;  $DEBUG_GET = 0;
# pour le mode ligne de commandes (cli)
  GetOptions(
    'ref=s' => \$ref,
    'id=s' => \$id,
    'shape=s' => \$shape,
    'debug|d' => \$DEBUG,
    'DEBUG=s' => \$DEBUG,
    'DEBUG_GET=s' => \$DEBUG_GET,
    'g' => \$DEBUG_GET
  );
  $sp = shift if ( @ARGV );

  warn "$0 $] sp:$sp DEBUG:$DEBUG DEBUG_GET:$DEBUG_GET id:$id";
  my $sub = UNIVERSAL::can('main',"$sp");
  if ( defined $sub ) {
    &$sub(@ARGV);
  } else {
    warn "main sp:$sp inconnu";
  }
  warn "$0 $] fin";
  exit 0;
sub aide {
  help();
}
sub help {
  print <<'EOF';
# nettoyage des bus stop
perl scripts/keolis.pl --DEBUG 1 --DEBUG_GET 1 star bus_stop_tag_next
perl scripts/keolis.pl --DEBUG 1 --DEBUG_GET 1 star tags_network
# forcage du tag network sur les routes membres
perl scripts/keolis.pl --DEBUG 1 --DEBUG_GET 1 star tags_network
# validation de la relation reseau
perl scripts/keolis.pl --DEBUG 1 --DEBUG_GET 1 star valid_network
# comparaison gtfs / osm
perl scripts/keolis.pl --DEBUG 1 --DEBUG_GET 1 star diff_bus_stop
perl scripts/keolis.pl --DEBUG 1 --DEBUG_GET 1 star diff_routes
perl scripts/keolis.pl star valid_routes_master
perl scripts/keolis.pl --DEBUG 1 --DEBUG_GET 1 --ref C4 star diff_route
#
# version avec les shapes
perl scripts/keolis.pl --DEBUG 1 --DEBUG_GET 0 star routes_shapes_diff
perl scripts/keolis.pl --DEBUG 1 --DEBUG_GET 0 --shape 0158-B-2319-1615 star route_shape_stops
# continuité des routes star ksma surf vitre chateaubourg
perl scripts/keolis.pl star valid_routes_ways
perl scripts/keolis.pl --id 0001-01-A -- star valid_route_ways
perl scripts/keolis.pl --DEBUG_GET 0 --id 0001-01-A star valid_route_ways
# nettoyage des disused
perl scripts/keolis.pl star valid_network --DEBUG 0
perl scripts/keolis.pl star disused_route_master_delete --DEBUG 0
perl scripts/keolis.pl star disused_route_delete --DEBUG 0
# pour les stops
perl scripts/keolis.pl --DEBUG 1 --DEBUG_GET 1 -- illenoo illenoo_stops_diff
#
# pour la conversion en gpx d'une relation
perl scripts/keolis.pl --DEBUG 1 --DEBUG_GET 1 --id 1743082 -- star gpx_relation_ways
perl scripts/keolis.pl --DEBUG 1 --DEBUG_GET 1 -- star valid_routes_ways
#
# le routage d'un itinéraire
perl scripts/keolis.pl --DEBUG 0 --DEBUG_GET 1 --shape 0203-B-1663-1619 star osrm_get_parcours

EOF

}

sub Keolis {
  my $oItiRoute = new ItiRoute(&_keolis);
  my $sp = 'osm2route';
  if ( @_ ) {
    $sp = shift @_;
  } else {
    $sp = $ssp;
  }
  $oItiRoute->$sp(@_);
}
sub star {
  my $oTransport = new Transport(&_star);
  $sp = 'diff_route';
#  $sp = 'diff_routes';
  if ( @_ ) {
    $sp = shift @_;
  } else {
    $sp = $ssp;
  }
  $oTransport->$sp(@_);
}
sub _star {
  my $self = {
    DEBUG => $DEBUG,
    DEBUG_GET => $DEBUG_GET,
    ref => $ref,
    id => $id,
    shape => $shape,
    network => 'FR:STAR',
    operator => "Star",
    cfgDir => "TRANSPORT/STAR",
    source => "http://data.keolis-rennes.com 04 novembre 2017",
    osm_commentaire => 'maj novembre 2017',
    k_route => "route",
    k_ref => 'ref:FR:STAR',
    tag_ref => '["ref:FR:STAR"]',
  };
  return $self;
}
sub illenoo {
  my $oTransport = new Transport(&_illenoo);
  my $sp = 'valid_network';
  if ( @_ ) {
    $sp = shift @_;
  } else {
    $sp = $ssp;
  }
  $oTransport->$sp(@_);
}
sub _illenoo {
  my $self = {
    DEBUG => $DEBUG,
    DEBUG_GET => $DEBUG_GET,
    ref => $ref,
    id => $id,
    network => "fr_illenoo",
    operator => "Illenoo",
    cfgDir => "TRANSPORT/ILLENOO",
    source => "Département d'Ille-et-Vilaine - 3 Novembre 2016",
    k_route => "route",
    tag_ref => '[ref]',
    k_ref => 'ref:fr_illenoo',
    osm_commentaire => 'maj novembre 2016',
  };
  return $self;
}
sub ksma {
  my $oTransport = new Transport(&_ksma);
  my $sp = 'valid_network';
  if ( @_ ) {
    $sp = shift @_;
  } else {
    $sp = $ssp;
  }
  $oTransport->$sp(@_);
}
sub _ksma {
  my $self = {
    DEBUG => $DEBUG,
    DEBUG_GET => $DEBUG_GET,
    ref => $ref,
    tag_ref => '["ref:ksma"]',
    id => $id,
    network => "fr_ksma",
    operator => "KSMA",
    cfgDir => "TRANSPORT/KSMA",
    source => "Keolis Saint-Malo - Année 2016",
    overpassQL => 'relation[network=fr_ksma]["route"][ref="%s"];out meta;',
    k_route => "route",
    osm_commentaire => 'maj juin 2016',
  };
  return $self;
}
sub surf {
  my $oTransport = new Transport(&_surf);
  my $sp = 'valid_network';
  if ( @_ ) {
    $sp = shift @_;
  } else {
    $sp = $ssp;
  }
  $oTransport->$sp(@_);
}
sub _surf {
  my $self = {
    DEBUG => $DEBUG,
    DEBUG_GET => $DEBUG_GET,
    ref => $ref,
    network => "fr_surf",
    operator => "Transdev Fougères",
    tag_ref => '["ref:fr_surf"]',
    cfgDir => "TRANSPORT/SURF",
    name => 'Fougères',
    website => 'http://www.lesurf.fr/',
    source => "Service Urbain de la Région Fougeraise - Année 2016",
    overpassQL => 'relation[network=fr_surf]["route"][ref="%s"];out meta;',
    k_route => "route",
    osm_commentaire => 'maj avril 2016',
  };
  return $self;
}
sub vitre {
  my $oTransport = new Transport(&_vitre);
  my $sp = 'valid_network';
  if ( @_ ) {
    $sp = shift @_;
  } else {
    $sp = $ssp;
  }
  $oTransport->$sp(@_);
}
sub _vitre {
  my $self = {
    DEBUG => $DEBUG,
    DEBUG_GET => $DEBUG_GET,
    ref => $ref,
    network => "fr_vitre",
    operator => "Kéolis Armor",
    tag_ref => '["ref"]',
    cfgDir => "TRANSPORT/VITRE",
    name => "Vitré",
    source => "Vitré Communauté - Année 2016",
    website => "http://www.vitrecommunaute.org/transport_commun.html",
    overpassQL => 'relation[network=fr_vitre]["route"][ref="%s"];out meta;',
    k_route => "route",
    osm_commentaire => 'maj juin 2016',
  };
  return $self;
}
sub chateaubourg {
  my $oTransport = new Transport(&_chateaubourg);
  my $sp = 'valid_network';
  if ( @_ ) {
    $sp = shift @_;
  } else {
    $sp = $ssp;
  }
  $oTransport->$sp(@_);
}
sub _chateaubourg {
  my $self = {
    DEBUG => $DEBUG,
    DEBUG_GET => $DEBUG_GET,
    ref => $ref,
    network => "fr_chateaubourg",
    operator => "Kéolis Armor",
    tag_ref => '["ref"]',
    cfgDir => "TRANSPORT/CHATEAUBOURG",
    name => "Vitré Communauté - Châteaubourg",
    source => "Vitré Communauté - Année 2016",
    website => "http://www.vitrecommunaute.org/transport_commun.html",
    overpassQL => 'relation[network=fr_chateaubourg]["route"][ref="%s"];out meta;',
    k_route => "route",
    osm_commentaire => 'maj juin 2016',
  };
  return $self;
}

sub stop_area {
#  $oTransport->diff_stop_area(@_);
#  $oTransport->valid_stop_area(@_);
}

sub route {
  my $sp = 'diff_route';
  $sp = 'valid_route_hors_master';
  if ( @_ ) {
    $sp = shift @_;
  }
#  $oTransport->$sp(@_);
}
sub gtfs {
  my $sp = 'liste_iti';
  if ( @_ ) {
    $sp = shift @_;
  }
#  $oTransport->$sp(@_);
}
#
# lister les informations d'osm
# =============================
#
sub liste_routes {
  $hash = osm_get("relation[network=fr_star][route=bus];out meta;", "$cfgDir/relations_routes.osm");
#  confess Dumper $hash;

  my $wiki = "{|";
  $wiki .= "\n|" . join("\n|", qw(ref description name destination from to id user timestamp));
  foreach my $relation (sort tri_tags_ref  @{$hash->{relation}}) {
#    warn sprintf("liste_routes() ref:%s;%s;%s;%s", $relation->{id}, $relation->{tags}->{ref}, $relation->{user}, $relation->{timestamp});
#    confess Dumper $relation->{tags};
    my $tags = '';
    $wiki .= "\n|-";
    for my $k ( qw(ref description name destination from to) ) {
      $wiki .= "\n|";
      if ( exists $relation->{tags}->{$k} ) {
        $tags .= $relation->{tags}->{$k};
        $wiki .= $relation->{tags}->{$k};
      }
      $tags .= ';';
    }
    $wiki .= sprintf("\n|{{Relation|%s|%s}}", $relation->{id}, $relation->{id});
    for my $k ( qw(user timestamp) ) {
      $wiki .= "\n|" . $relation->{$k};
      $tags .= $relation->{$k};
      $tags .= ';';
    }
#    last;
#    warn $tags;
  }
  $wiki .= "\n|}";
  print $wiki;

}
#
# les différences entre osm et gtfs
# =================================
#


#
# pour les lignes
sub diff_route_master {
  $gtfs_routes = gtfs_routes_get();
  $hash = osm_route_master_get();
#  relations_route_master();
  relations_route_master_iti();
}
#
# pour la relation network
sub valid_network {
  my $hash_network = osm_get("relation[network=fr_star][type=network];out meta;", "$cfgDir/relation_network.osm");;
  my $hash_routes = osm_get("relation[network=fr_star][type=route][route=bus];out meta;", "$cfgDir/relation_routes_bus.osm");
}
#
# pour les lignes
sub valid_routes_master {
  my $hash_route_master = osm_get("relation[network=fr_star][type=route_master];out meta;", "$cfgDir/relation_route_master.osm");;
  my $hash_route = osm_get("relation[network=fr_star][type=route][route=bus];out meta;", "$cfgDir/relation_route_bus.osm");
  my $hash_line = osm_get("relation[network=fr_star][type=route][line=bus];out meta;", "$cfgDir/relation_line_bus.osm");
  foreach my $relation (sort tri_tags_ref  @{$hash_route_master->{relation}}) {
    my @routes = get_relation_tag_ref($hash_route, $relation->{tags}->{ref});
    my @lines = get_relation_tag_ref($hash_line, $relation->{tags}->{ref});
    warn "valid_route_master() ref:" . $relation->{tags}->{ref} . " id: " . $relation->{id} . " nb_routes:" . scalar(@routes) . " nb_lines:" . scalar(@lines);
  }
}



#
# les vérifications
# =================

# http://interoperating.info/courses/perl4data/node/26
#
# nettoyage des relations avec des noeuds
sub clean_line_bus {
#  my $hash = osm_get("relation[network=fr_star][line=bus][route!=bus];out meta;", "$cfgDir/line_bus.osm");
  my $hash = osm_get("relation[network=fr_star][public_transport=stop_area];out meta;", "$cfgDir/stop_area.osm");
  warn "clean_line_bus()";
  my $osm_member = '';
  foreach my $relation (@{$hash->{relation}}) {
    if ( not defined $relation->{member} ) {
      next;
    }
    if ( $relation->{changeset} != '9232436' ) {
#      next;
    }
#    confess Dumper $relation;
# vérification du type des nodes
    my $ok = 0;
    for my $member ( @{$relation->{member}} ) {
      if ( $member->{type} ne 'node' ) {
        next;
      };
      $ok = 1;
      last;
    }
    if ( $ok ) {
      warn "clean_line_bus() n" . $relation->{id};
      my $osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'relation',  $relation->{id} ));
#    warn $osm;
      $osm_member .=  $oOSM->relation_delete_member_platform($osm) . "\n";
#      last;
    }
  }
#  confess  $osm_latlon;
  if ( $osm_member ne '' ) {
    $oAPI->changeset($osm_member, 'maj Keolis octobre 2014 stop_area', 'modify');
  }
}




sub osm_delete {
  my $osm = shift;
  $osm =~ s{.*<relation}{<relation}sm;
  $osm =~ s{</relation>.*}{</relation>\n}sm;
#  confess $osm;
  return $osm;
}
sub osm_delete_members {
  my $osm = shift;
  my @members = @_;
  my ( $ligne );
  foreach my $m ( @members ) {
#    warn "osm_delete_members() m:" . $m;
    $ligne = sprintf('  <member type="%s" ref="%s" role="%s"/>', 'relation', $m, '');
    if ( $osm !~ m{$ligne} ) {
      warn "osm_delete_members() *** manque $ligne";
      next;
    } else {
       $osm =~ s{$ligne}{};
    }
  }
  $osm =~ s{.*<relation}{<relation}sm;
  $osm =~ s{</relation>.*}{</relation>}sm;
  $osm =~ s{\n+}{\n}gsm;
#  confess $osm;
  return $osm;
}
sub osm_modify_members {
  my $osm = shift;
  my $members = shift;
  my ( $lignes, $ligne );
  $lignes = '';
  foreach my $m ( @{$members} ) {
#    warn "osm_modify_members() " . Dumper $m;
    $ligne = sprintf('  <member type="%s" ref="%s" role="%s"/>' . "\n", $m->{type}, $m->{ref}, $m->{role});
    if ( $osm =~ m{$ligne} ) {
      warn "osm_modify_members() *** double";
      next;
    }
    $lignes .= $ligne;
  }
  warn "osm_modify_members() lignes:$lignes";
  if ( $lignes eq '' ) {
    return '';
  }
  $osm =~ s{(  <tag k=")}{$lignes$1};
  $osm =~ s{.*<relation}{<relation}sm;
  $osm =~ s{</relation>.*}{</relation>}sm;
#  confess $osm;
  return $osm;
}

sub osm_modify_tags {
  my $osm = shift;
  my $tags = shift;
  my @tags = @_;
  foreach my $tag (sort @tags ) {
    warn "osm_modify_tags() $tag";
    my $ligne = '<tag k="' . $tag . '" v="' . $tags->{$tag} . '"/>';
#  <tag k="from" v="Saint-Laurent"/>
    if ( $osm =~ m{<tag k="$tag" v="[^"]+"/>}sm ) {
      warn $MATCH;
      $osm = $PREMATCH . $ligne . $POSTMATCH;
    } else {
      $osm =~ s{</relation>}{ $ligne\n</relation>};
    }
  }
  $osm =~ s{.*<relation}{<relation}sm;
  $osm =~ s{</relation>.*}{</relation>}sm;
  return $osm;
}

# http://search.cpan.org/~mirod/XML-Twig-3.48/Twig.pm
sub get_twig {
  my $oOAPI = new OsmOapi();
  my $osm = $oOAPI->get_relations_route_master;
#  confess $osm;
  my $oTWIG = XML::Twig->new();
  $oTWIG->parse($osm);
  my $root = $oTWIG->root;
  my @relation = $root->children('relation');
  foreach my $elt (@relation) {
#	confess Dumper $relation;
    warn $elt->{'att'}->{'id'};
  }
}
sub get_api {
  my $oAPI = new OsmApi();
  exit;
  if ( ! $oDB ) {
    $oDB = new OsmDb();
  }
  $oDB->init();
  $oDB->table_select('stops');
#  warn Dumper $oDB->{table};
  my $oOSM = new OSM();
  my $osm = $oOSM->node_stops($oDB->{table}->{stops});
  print $osm;
}

