# <!-- coding: utf-8 -->
#
#
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
use English;
use XML::Simple;
use OsmMisc;    # quelques fonctions génériques
use OsmApi;     # l'api d'interrogation et de mise à jour
use OsmOapi;    # une api d'interrogation
use OsmDb;      # la base avec les données OSM et gtfs en provenance de la star
use Osm;        # la base avec les données OSM et gtfs en provenance de la star
sub new {
  my( $class, $attr ) = @_;
  my $self = {};
  $self->{cfgDir} = "TRANSPORT";
  $self->{osm_commentaire} = 'maj novembre 2018';
  $self->{seuil} = 200;
#  confess  Dumper $attr;
  bless($self, $class);
  $self->{oAPI} = new OsmApi();
  $self->{oOAPI} = new OsmOapi();
  $self->{oDB} = new OsmDb();
  $self->{oOSM} = new Osm();
  while ( my ($key, $value) = each %{$attr} ) {
    warn "$key:$value";
    $self->{$key} = $value;
    $self->{oOSM}->{$key} = $value;
    $self->{oAPI}->{$key} = $value;
    $self->{oOAPI}->{$key} = $value;
  }
  $self->{oOSM}->{self} = $self;
  if ( not defined $self->{'tag_stop'} ) {
    my $network = $self->{network};
    $network =~ s{^fr_}{};
    $self->{tag_stop} = '["ref:' . $network . '"]';
  }
  if ( not defined $self->{'tag'} ) {
    ($self->{tag}) = ( $self->{'tag_ref'} =~ m{(ref:\w+)} );
  }
  $self->config();
  return $self;
}
sub DESTROY {
  my $self = shift;
# un autre DESTROY
  $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
  warn "DESTROY()";
  print $self->{log};
}
sub config {
  my $self = shift;
  my $file = "scripts/transport.dmp";
  if ( -f $file ) {
    open my $fh, '<', $file or die "in() open $file erreur:$!";
    local $/ = undef;  # read whole file
    my $dumped = <$fh>;
    close $fh or die "new() $file erreur:$!";
#  confess Dumper $dumped;
    my %id =  %{eval $dumped};
    $self->{config} = \%id;
#    confess Dumper $self->{config};
  }
}
#
# récupération des données fichiers
# =================================
sub masters_lire {
  my $self = shift;
  warn "masters_lire()";
  my $f_txt = "$self->{cfgDir}/masters.txt";
  open(TXT, "< :utf8", $f_txt) or die;
  my $ligne = <TXT>;
  while( my $ligne = <TXT>) {
    chomp($ligne);
    my ($ref, $bg, $fg, $name) = split(";", $ligne);
    $self->{masters}->{$ref} = {
      name => $name,
      bg => $bg,
      fg => $fg,
    };
  }
  close(TXT);
}
#
# récupération des données OSM
# ============================
sub oapi_get {
  my $self = shift;
  return $self->{'oOAPI'}->osm_get(@_);
}
sub osm_get {
  my $self = shift;
  return $self->{'oAPI'}->osm_get(@_);
}

#
# récupération des relations type=route et mise en hash
sub osm_route_get {
  my $self = shift;
  my $ref = shift;
  my ($osm, $f_osm);
  if ( ! $self->{osm_route_get} ) {
    warn "osm_route_get() nouvelle version";
    $f_osm = $self->{cfgDir}. "/relation_routes_bus.osm";
    $osm = "(relation[network='" . $self->{network} . "'][type=route][route=bus];>>);out meta;";
    $self->{osm_route_get} = $self->oapi_get($osm, $f_osm);
    @{$self->{osm_route_get_relations}} = @{$self->{osm_route_get}->{relation}};
  }
  @{$self->{osm_route_get}->{relation}} = @{$self->{osm_route_get_relations}};
  my $hash = $self->{osm_route_get};
  warn "osm_route_get() DEBUG_GET:" . $self->{DEBUG_GET} . " avant $f_osm nb_r:" . scalar(@{$hash->{relation}}) . " nb_w:" . scalar(@{$hash->{way}}) . " nb_n:" . scalar(@{$hash->{node}});
  my @relations;
  foreach my $relation ( @{$hash->{relation}} ) {
    if ( $relation->{tags}->{ref} ne $ref ) {
      next;
    }
#    warn $relation->{tags}->{ref};
    push @relations, $relation;
  }
  @{$hash->{relation}} = @relations;
  warn "osm_route_get() DEBUG_GET:" . $self->{DEBUG_GET} . " apres $f_osm nb_r:" . scalar(@{$hash->{relation}}) . " nb_w:" . scalar(@{$hash->{way}}) . " nb_n:" . scalar(@{$hash->{node}});
#  warn "osm_route_get() DEBUG_GET:" . $self->{DEBUG_GET} . " apres $f_osm nb_r:" . scalar(@{$self->{osm_route_get}->{relation}});
#  exit;
#  confess Dumper \@relations;
  return $hash;
}
#
# récupération des relations type=route_master et mise en hash
sub osm_route_master_get {
  my $self = shift;
  my ($osm, $f_osm);
  $f_osm = "$self->{cfgDir}/relations_route_master.osm";
  $osm = "relation[network=fr_star][route_master=bus];out meta;";
  return $self->oapi_get($osm, $f_osm);
}
#
# récupération des nodes highway=bus_stop mise en hash type osm
sub osm_relations_stop_area_get {
  my $self = shift;
  my ($osm, $f_osm);
  $f_osm = "$self->{cfgDir}/relations_stop_area.osm";
  $osm = "relation[network=fr_star][type=public_transport][public_transport=stop_area];out meta;";
  return $self->oapi_get($osm, $f_osm);
}
#
# récupération des nodes highway=bus_stop mise en hash type osm
sub osm_nodes_bus_stop_get {
  my $self = shift;
  my $DEBUG_GET =  $self->{DEBUG_GET};
  if ( @_ ) {
    $DEBUG_GET = shift;
  }
  my ($osm, $f_osm);
  $f_osm = "$self->{cfgDir}/nodes_bus_stop.osm";
  $osm = "node(area:3602005861);(node(around:1000);)->.a;(node.a[highway=bus_stop];node.a[public_transport=platform]);out meta;";
  $osm = "node(area:3602005861);node(around:1000)[highway=bus_stop];out meta;";
  return $self->oapi_get($osm, $f_osm, $DEBUG_GET);
}
#
# récupération des nodes highway=bus_stop hors route=bus mise en hash type osm
sub osm_nodes_bus_stop_hors_get {
  my $self = shift;
  my ($osm, $f_osm);
  $f_osm = "$self->{cfgDir}/nodes_bus_stop_hors.osm";
  $osm = "node(area:3602005861);node(around:1000)[highway=bus_stop]->.all;relation[network=fr_star][route=bus](bn.all);node(r);( .all; - ._; );out meta;";
  return $self->oapi_get($osm, $f_osm);
}
#
# récupération des nodes highway=bus_stop mise en hash type name/ref
sub osm_nodes_bus_stop_hash {
  my $self = shift;
  warn "osm_nodes_bus_stop_hash()";
  my $hash = $self->osm_nodes_bus_stop_get();

  warn "osm_nodes_bus_stop_hash() indexation osm";
  my ($stops, $names, $names_norm);
  foreach my $node (sort @{$hash->{node}} ) {
    my $name = '';
    my $name_norm = '';
    my $ref = '';
    if ( not defined $node->{tags}->{name} ) {
      if ( $self->{DEBUG} > 1 ) {
        warn "osm_nodes_bus_stop_hash() indexation osm ref pas de name";
      }
 #     warn Dumper $node;
      next;
    }
    $name = $node->{tags}->{name};
    $name_norm = name_norm($name);
    $ref = undef;
    if ( defined $node->{tags}->{ref} ) {
      $ref =  $node->{tags}->{ref};
    }
    if ( defined $node->{tags}->{'ref:FR:STAR'} ) {
      $ref =  $node->{tags}->{'ref:FR:STAR'};
    }
    if ( defined $ref ) {
      if ( $ref !~ m{^\d+$} ) {
        if ( $self->{DEBUG} > 1 ) {
          warn "osm_nodes_bus_stop_hash() indexation osm ref non numérique";
        }
#        warn Dumper $node;
        next;
      }
      push @{$stops->{$ref}->{osm}}, $node;
    }
    push @{$names->{$name}->{osm}}, $node;
    push @{$names_norm->{$name_norm}->{osm}}, $node;
  }
  warn "osm_nodes_bus_stop_hash() indexation nb names: " . scalar(keys %{$names});
  warn "osm_nodes_bus_stop_hash() indexation nb names_norm: " . scalar(keys %{$names_norm});
  warn "osm_nodes_bus_stop_hash() indexation nb ref: " . scalar(keys %{$stops});
  return $stops;
}
our ( $osm_nodes_bus_stop_refs );
sub osm_nodes_bus_stop_ref {
  my $self = shift;
  my $ref = shift;
  if ( not defined $osm_nodes_bus_stop_refs ) {
    $osm_nodes_bus_stop_refs = $self->osm_nodes_bus_stop_hash();
  }
  if ( not defined $osm_nodes_bus_stop_refs->{$ref} ) {
    confess "osm_nodes_bus_stop_ref() *** ref:$ref";
  }
  if ( $self->{DEBUG} > 1 ) {
    warn Dumper $osm_nodes_bus_stop_refs->{$ref}->{osm};
  }
  return  $osm_nodes_bus_stop_refs->{$ref}->{osm}[0];
}
#
# transformation de la réponse osm en hash
sub osm2hash_v1 {
  my $osm = shift;
  confess "osm2hash" .$osm;
  my $hash = XMLin(
    $osm,
    ForceArray    => 1,
    KeyAttr       => [],
    SuppressEmpty => ''
  );
#  warn Dumper($hash);
  $hash->{osm}->{relation} = ();
  $hash->{osm}->{way} = ();
  $hash->{osm}->{node} = ();
  foreach my $relation (@{$hash->{relation}}) {
#    confess Dumper $relation;
    foreach my $tag (@{$relation->{tag}}) {
#     confess Dumper $tag;
      $relation->{tags}->{$tag->{k}} = $tag->{v};
    }
    delete $relation->{tag};
    $hash->{osm}->{relation}->{$relation->{id}} = $relation;
#	confess Dumper $relation->{tags};
#	last;
  }
  foreach my $node (@{$hash->{node}}) {
    foreach my $tag (@{$node->{tag}}) {
      $node->{tags}->{$tag->{k}} = $tag->{v};
    }
    delete $node->{tag};
  }
  foreach my $way (@{$hash->{way}}) {
    foreach my $tag (@{$way->{tag}}) {
      $way->{tags}->{$tag->{k}} = $tag->{v};
    }
    foreach my $nd (@{$way->{nd}}) {
      push @{$way->{nodes}}, $nd->{ref};
    }
    delete $way->{tag};
    delete $way->{nd};
  }
  return $hash;
}
#
# recherche d'un node dans le hash
sub find_node {
  my $id = shift;
  my $hash = shift;
  for my $node ( @{$hash->{node}} ) {
    if ( $id eq $node->{id} ) {
      return $node;
    }
  }
  return undef;
}
sub find_relation {
  my $id = shift;
  my $hash = shift;
  for my $relation ( @{$hash->{relation}} ) {
    if ( $id eq $relation->{id} ) {
      return $relation;
    }
  }
  return undef;
}
sub find_way {
  my $id = shift;
  my $hash = shift;
  for my $way ( @{$hash->{way}} ) {
    if ( $id eq $way->{id} ) {
      return $way;
    }
  }
  return undef;
}

sub get_relation_tag_ref {
  my $hash = shift;
  my $ref = shift;
  my @relations = ();
  foreach my $relation ( @{$hash->{relation}}) {
    if (  $relation->{tags}->{ref} eq $ref ) {
      push @relations, $relation;
    }
  }
  return @relations;
}
sub display_relation_route_member_node {
  my $relation = shift;
  my @nodes = get_relation_route_member_node($relation);
  warn sprintf("\n%s;%s;%s", $relation->{id},$relation->{user}, $relation->{timestamp});
  warn "display_relation_route_member_node ". join(",", @nodes);
  return @nodes;
}
#
# calcul de la distance entre 2 points en mètre
sub haversine_distance_meters {
#  warn Dumper @_;
  my $O = 3.141592654/180 ;
  my $lat1 = shift(@_) * $O;
  my $lon1 = shift(@_) * $O;
  my $lat2 = shift(@_) * $O;
  my $lon2 = shift(@_) * $O;
  my $dlat = $lat1 - $lat2;
  my $dlon = $lon1 - $lon2;
  my $f = 2 * &asin( sqrt( (sin($dlat/2) ** 2) + cos($lat1) * cos($lat2) * (sin($dlon/2) ** 2)));
  return sprintf("%d",$f * 6378137) ; 		# Return meters
  sub asin {
   atan2($_[0], sqrt(1 - $_[0] * $_[0])) ;
  }
}
sub test_haversine_distance_meters {
  warn haversine_distance_meters(48.09062505, -1.69500771, 48.09053717, -1.69493887);
}
# pour trier dans un ordre naturel la référence de la ligne
sub tri_ref {
  my $aa = $a;
  my $bb = $b;
  my ($an) = $aa =~ /^(\d+)/;
  my ($bn) = $bb =~ /^(\d+)/;
  if ( $an && $bn ) {
    $an <=> $bn;
  } else {
    $aa cmp $bb;
  }
}
sub tri_tags_network {
  my $aa = $a->{tags}->{network};
  my $bb = $b->{tags}->{network};
  if ( $aa eq $bb ) {
    tri_tags_ref()
  } else {
    $aa cmp $bb;
  }
}
sub tri_tags_ref {
  my $aa = $a->{tags}->{ref};
  my $bb = $b->{tags}->{ref};
  my ($an, $as) = $aa =~ /^(\d+)(.*)$/;
  my ($bn, $bs) = $bb =~ /^(\d+)(.*)$/;
  if ( $an && $bn ) {
    if ( $an == $bn ) {
      $as cmp $bs;
    } else {
      $an <=> $bn;
    }
  } else {
    $aa cmp $bb;
  }
}
sub tri_tags_refstar {
  my $aa = $a->{tags}->{'ref:FR:STAR'};
  my $bb = $b->{tags}->{'ref:FR:STAR'};
  my ($an) = $aa =~ /^(\d+)/;
  my ($bn) = $bb =~ /^(\d+)/;
  if ( $an && $bn ) {
    $an <=> $bn;
  } else {
    $aa cmp $bb;
  }
}
1;