# <!-- coding: utf-8 -->
#
# les traitements sur la relation network
#
#
package Transport;
use utf8;
use strict;
use Carp;
use Data::Dumper;
use LWP::Simple;
use XML::Simple;
sub diff_bicycle {
  my $self = shift;
  warn "diff_bicycle() debut";
  my $hash_bicycle = $self->osm_get('node["network"="Vélo STAR"];out meta;', "$self->{cfgDir}/node_bicycle.osm");
#
# on indexe par ref
  my ( $stations );
  for my $node ( @{$hash_bicycle->{node}} ) {
    if ( ! defined $node->{tags}->{name} ) {
      confess "diff_bicycle() *** name " .Dumper $node;
      next;
    }
    if ( ! defined $node->{tags}->{ref} ) {
      confess "diff_bicycle() *** ref " .Dumper $node;
      next;
    }
    $stations->{$node->{tags}->{ref}}->{osm} = $node;
  }
#  confess Dumper $hash_bicycle;
  my $url = 'http://data.keolis-rennes.com/xml/?version=1.0&key=NG7IEAO1IE77F3O&cmd=getstation&param[request]=all';
  my $api_xml = get($url);
#  confess $api_xml;
  my $hash = XMLin(
    $api_xml,
    ForceArray    => 0,
    KeyAttr       => [],
    SuppressEmpty => ''
  );
#  warn Dumper($hash);
  my @stations = @{$hash->{answer}->{data}->{station}};
  my $osm_create = '';
  my $osm_modify = '';
  warn "diff_bicycle() nb stations: " . scalar(@stations);
  for my $station ( @stations ) {
#    confess "diff_bicycle() *** name " .Dumper $station;
#    warn $station->{name};
    $stations->{$station->{number}}->{keolis} = $station;
  }
  for my $station ( sort keys %{$stations} ) {
    if ( not defined $stations->{$station}->{osm} ) {
      warn "diff_bicycle() *** osm " .Dumper $stations->{$station};
      $osm_create .=  $self->{oOSM}->node_bicycle($stations->{$station}->{keolis});
      next;
    }
    if ( not defined $stations->{$station}->{keolis} ) {
      warn "diff_bicycle() *** keolis " .Dumper $stations->{$station};
      next;
    }
    if ( name_norm($stations->{$station}->{keolis}->{name}) ne name_norm($stations->{$station}->{osm}->{tags}->{name}) ) {
 #     warn "diff_bicycle() *** keolis " .Dumper $stations->{$station};
 #     next;
    }
#    warn $station->{name};
    my $d = haversine_distance_meters($stations->{$station}->{keolis}->{latitude}, $stations->{$station}->{keolis}->{longitude}, $stations->{$station}->{osm}->{lat}, $stations->{$station}->{osm}->{lon});
    if ( $d > 10 ) {
      my $node_osm = get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", 'node', $stations->{$station}->{osm}->{id}));
      $osm_modify .= $self->{oOSM}->modify_latlon($node_osm, $stations->{$station}->{keolis}->{latitude}, $stations->{$station}->{keolis}->{longitude}) . "\n";
    }
    my $nb =  $stations->{$station}->{keolis}->{bikesavailable} +   $stations->{$station}->{keolis}->{slotsavailable};
    if ( $nb != $stations->{$station}->{osm}->{tags}->{capacity} ) {
#      warn "diff_bicycle() *** keolis capacity " .Dumper $stations->{$station};
      next;
    }
  }
  $self->{oAPI}->changeset($osm_create, $self->{osm_commentaire} . ' ajout des nodes manquants' , 'create');
  $self->{oAPI}->changeset($osm_modify, $self->{osm_commentaire} . ' modification des nodes' , 'modify');
}

1;