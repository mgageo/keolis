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
use WWW::Mechanize qw();
#
# mise à jour du wiki
#  perl scripts/keolis.pl --DEBUG 0 --DEBUG_GET 1 bretagne wiki_area_maj
sub wiki_area_maj {
  my $self = shift;
  $self->route_area_wiki();
  $self->routemaster_area_wiki();
  my $dsn = "$self->{cfgDir}/route_bretagne_wiki.txt";
  $self->wiki_maj_page($dsn, 'User:Mga_geo/Transports_publics/Bretagne/route%3Dbus');
  $dsn = "$self->{cfgDir}/routemaster_area_wiki.txt";
  $self->wiki_maj_page($dsn, 'User:Mga_geo/Transports_publics/Bretagne/route_master%3Dbus');
  warn "wiki_maj() fin";
}
sub wiki_maj {
  my $self = shift;
  if ( 1 == 2 ) {
    $self->route_wiki();
    $self->routemaster_wiki();
  }
#  return();
  my $dsn = "$self->{cfgDir}/route_wiki.txt";
  $self->wiki_maj_section($dsn, 'User:Mga_geo/Transports_publics/Quimper', '3');
#  $dsn = "$self->{cfgDir}/routemaster_area_wiki.txt";
#  $self->wiki_maj_page($dsn, 'User:Mga_geo/Transports_publics/Quimper&section=3');
  warn "wiki_maj() fin";
}
sub wiki_maj_page {
  my $self = shift;
  if ( not defined $self->{mech} ) {
    $self->wiki_init()
  }
  my $dsn = shift;
  my $page = shift;
  my $mech = $self->{wiki}->{mech};
  open my $fh, '<:utf8', $dsn or die "Can't open file $!";
  my $txt = do { local $/; <$fh> };
  my $url = sprintf('https://%s/wiki/%s', $self->{wiki}->{host}, $page);
  $mech->get($url);
  $mech->success or die " wiki_maj() échec page";
#  $self->wiki_log();
  $mech->follow_link( text_regex => qr/Modifier le wikicode/ ) or do {
    die "follow_link";
  };
#  $self->wiki_log();
  $mech->submit_form(
    with_fields => {
      wpTextbox1   => $txt,
    },
  );
  warn "wiki_maj_page() fin";
}
sub wiki_maj_section {
  my $self = shift;
  my ($dsn, $page, $section) = @_;
  if ( not defined $self->{mech} ) {
    $self->wiki_init()
  }
  my $mech = $self->{wiki}->{mech};
  open my $fh, '<:utf8', $dsn or die "Can't open file $! $dsn";
  my $txt = do { local $/; <$fh> };
  my $url = sprintf('https://%s/w/index.php?title=%s&action=edit&section=%s', $self->{wiki}->{host}, $page, $section);
  warn $url;
  $mech->get($url);
  $mech->success or die "wiki_maj_section() échec page";
#  $self->wiki_log();
  $mech->submit_form(
    with_fields => {
      wpTextbox1   => $txt,
    },
  );
  warn "wiki_update_section() fin";
}
sub wiki_init {
  my $self = shift;
  $self->{wiki} = {
    host        => 'wiki.openstreetmap.org',
    page => 'User:Mga_geo/Transports_publics/Bretagne/route%3Dbus'
  };
  my $mech = WWW::Mechanize->new( cookie_jar => {} );
  $mech->add_header(
    'User-Agent' => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; fr; rv:1.8.1.9) Gecko/20071025 Firefox/2.0.0.9',
    'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, application/vnd.ms-excel, application/vnd.ms-powerpoint, application/msword, application/x-shockwave-flash, */*',
    'Accept-Language' => 'fr,fr-fr;q=0.8,en-us;q=0.5,en;q=0.3',
    'Accept-Charset' => 'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
    'Keep-Alive' => '300',
    'Connection' => 'keep-alive',
#    'Accept-Encoding' => '*;q=0'
  );
  my $url = sprintf('https://%s/w/index.php?title=Special:UserLogin', $self->{wiki}->{host});
  $mech->get($url) or die "wiki_maj() échec login";
#  $self->wiki_log();
  $mech->submit_form(
    form_name => 'userlogin',
    with_fields => {
      wpName => $self->{config}->{wiki}->{user},
      wpPassword => $self->{config}->{wiki}->{password},
  }) or die "wiki_maj() échec user/password";
  $self->{wiki}->{mech} = $mech;
}
# dump du contexte Mechanize
sub wiki_log {
  my $self = shift;
  my $mech = $self->{wiki}->{mech};
  my $f_txt = 'd:/transportwiki.txt';
  open(TXT,">$f_txt") or die "open(TXT,>$f_txt)";
  binmode(TXT, ":utf8");
  print TXT "title=> " . $mech->title() . "\n";
  my $absolute;
  for my $link ( $mech->links ) {
    my $url = $absolute ? $link->url_abs : $link->url;
    my $text = 'UNDEF';
    if ( defined $link->text() ) {
      $text = $link->text();
    }
#    print TXT Dumper $link;
    print TXT "url_regex=> qr/".$url."/ text=>'".$text."'\n";
  }
  my $nb = 0;
  for my $form ( $mech->forms() ) {
    print TXT $form->dump;
    $nb++;
    print TXT "\nform_number($nb)";
    print TXT "\n  \%fields = (";
    for ( $form->inputs ) {
      print TXT "\n    ";
      print TXT "'".$_->name."'" if defined $_->name;
      print TXT "=>'";
      print TXT $_->value if defined $_->value;
      print TXT "',";
    }
    print TXT "\n  );\n";
    print TXT <<EOF;
  \$browser->submit_form(
    form_number => $nb,
    fields => {
EOF
    for ( $form->inputs ) {
      print TXT "\n    ";
      print TXT "'".$_->name."'" if defined $_->name;
      print TXT "=>'";
      print TXT $_->value if defined $_->value;
      print TXT "',";
    }
    print TXT "\n    }\n  );\n";
    print TXT "\n  ".'$browser->set_visible(';
    for ( $form->inputs ) {
      my $type = 'UNDEF';
      my $value = 'UNDEF';
      if ( defined $_->type ) {
        $type = $_->type;
      }
      if ( defined $_->value ) {
        $value = $_->value;
      }
      print TXT "\n    [ ".$type.'=>"'.$value.'" ],';
      print TXT " # ".$_->name if defined $_->name;
    }
    print TXT "\n  );\n";
  }
  exit;
}

1;