#!/bin/bash
# <!-- coding: utf-8 -->
#T interrogation keolis
# http://www.cyclestreets.net/journey/help/osmconversion/
  while read f; do
    [ -f $f ] || die "$0 $f"
    . $f
  done <<EOF
../win32/scripts/misc.sh
../geo/scripts/keolis_postgis.sh
../geo/scripts/keolis_sqlite.sh
../geo/scripts/keolis_net.sh
EOF

#f CONF: configuration de l'environnement de travail du script
CONF() {
  LOG "CONF debut"
  ENV
  CFG=KEOLIS
  [ -d "${CFG}" ] || mkdir -p "${CFG}"
  _ENV_gdal
  cle=NG7IEAO1IE77F3O
  url=http://data.keolis-rennes.com/xml/
#  _ENV_keolis
  _ENV_keolis_sqlite
  LOG "CONF fin"
}
#f _ENV_keolis: l'environnement postgis
_ENV_keolis() {
 [ -f ../win32/scripts/misc_postgis.sh ] || die "_ENV_keolis() misc_postgis"
  _ENV_postgis
  . ../win32/scripts/misc_postgis.sh
  MYDB=keolis
  schema="public."
  user="postgres"
  password="postgres"
  host="localhost"
}
#f _ENV_keolis_sqlite: l'environnement spatilite
_ENV_keolis_sqlite() {
 [ -f ../win32/scripts/misc_sqlite.sh ] || die "_ENV_keolis_sqlite() misc_sqlite"
  _ENV_sqlite
  . ../win32/scripts/misc_sqlite.sh
  code_insee=35000
  db="35000_network"
  Base=${CFG}/${db}.sqlite
  Base=${db}.sqlite
  NetBase=${CFG}/35000_highway2.sqlite
  NetOsm=../osm/OSM/35000_highway2.osm
}
#F e: edition des principaux fichiers
e() {
  LOG "e debut"
  E $0
  while read f; do
    [ -f $f ] || die "$0 $f"
    E $f
  done <<EOF
../geo/scripts/keolis_sqlite.sh
../geo/scripts/keolis.pl
../geo/scripts/OsmApi.pm
../geo/scripts/OsmDb.pm
../geo/scripts/OsmOapi.pm
../osm/scripts/osm.sh
../osm/OSM/35000_network.osm
EOF
  LOG "e fin"
}
#F STAR: les traitements pour le réseau star
STAR() {
  LOG "STAR debut"
  STAR_dl
  STAR_api
  STAR_db
  LOG "STAR fin"
}

#F STAR_dl: récupération du réseau Star https://data.explore.star.fr/explore/dataset/tco-bus-topologie-pointsarret-td/export/
STAR_dl() {
  LOG "STAR_dl debut"
  local VarDir="${Drive}:/web.var/geo/STAR"
  while read url fic; do
    LOG "STAR_dl $fic"
    _STAR_dl
  done <<EOF
https://data.explore.star.fr/explore/dataset/tco-bus-topologie-parcours-td/download/?format=shp&timezone=Europe/Berlin tco-bus-topologie-parcours-td.zip
https://data.explore.star.fr/explore/dataset/tco-bus-topologie-parcours-td/download/?format=geojson&timezone=Europe/Berlin tco-bus-topologie-parcours-td.geojson
https://data.explore.star.fr/explore/dataset/tco-bus-topologie-pointsarret-td/download/?format=shp&timezone=Europe/Berlin tco-bus-topologie-pointsarret-td.zip
https://data.explore.star.fr/explore/dataset/tco-bus-topologie-pointsarret-td/download/?format=geojson&timezone=Europe/Berlin tco-bus-topologie-pointsarret-td.geojson
http://ftp.keolis-rennes.com/opendata/tco-busmetro-horaires-gtfs-versions-td/attachments/GTFS-20170213.zip GTFS-20170213.zip
https://data.explore.star.fr/explore/dataset/tco-bus-topologie-dessertes-td/download/?format=xls&timezone=Europe/Berlin&use_labels_for_header=true tco-bus-topologie-dessertes-td.xls
https://data.explore.star.fr/explore/dataset/tco-bus-topologie-dessertes-td/download/?format=csv&timezone=Europe/Berlin&use_labels_for_header=true tco-bus-topologie-dessertes-td.csv
https://data.explore.star.fr/explore/dataset/tco-bus-topologie-lignes-td/download/?format=xls&timezone=Europe/Berlin&use_labels_for_header=true tco-bus-topologie-lignes-td.xls
https://data.explore.star.fr/explore/dataset/tco-bus-topologie-lignes-td/download/?format=csv&timezone=Europe/Berlin&use_labels_for_header=true tco-bus-topologie-lignes-td.csv
EOF
#  ls -lR $VarDir
  LOG "STAR_dl fin VarDir: $VarDir"
  cp -pv $VarDir/tco-bus-topologie-parcours-td.geojson ../leaflet/exemples/star_parcours.geojson
  cp -pv $VarDir/tco-bus-topologie-pointsarret-td.geojson ../leaflet/exemples/star_pointsarret.geojson
  LOG "STAR_dl fin"
}
#f _STAR_dl:
_STAR_dl() {
  wget -O "${VarDir}/${fic}" "$url"
  (
    cd "${VarDir}"
    DlDir=20170103
    DlDir=20170227
    DlDir=20170619
    DlDir=20170829
    DlDir=20170928
    DlDir=20171010
    DlDir=$(date +%Y%m%d)
    [ -d "${DlDir}" ] || mkdir "$DlDir"
    [ -f "${DlDir}/${fic}" ] || cp -pv ${fic}  "${DlDir}/${fic}"
    7za -y x ${fic}

  )
}
#F STAR_api: récupération du réseau Star https://data.explore.star.fr/explore/dataset/tco-bus-topologie-pointsarret-td/export/
STAR_api() {
  LOG "STAR_api debut"
  local VarDir="${Drive}:/web.var/geo/STAR"
  while read fic format; do
    LOG "STAR_api $fic"
    _STAR_api
  done <<EOF
tco-bus-topologie-dessertes-td csv
tco-bus-topologie-lignes-td csv
tco-bus-topologie-parcours-td csv
tco-bus-topologie-parcours-td geojson
tco-bus-topologie-pointsarret-td geojson
EOF
  cp -pv $VarDir/tco-bus-topologie-parcours-td.geojson ../leaflet/exemples/star_parcours.json
  cp -pv $VarDir/tco-bus-topologie-pointsarret-td.geojson ../leaflet/exemples/star_pointsarret.json
#  ls -lR $VarDir
  LOG "STAR_api fin VarDir: $VarDir"
}
#f _STAR_api:
_STAR_api() {
  wget -O "${VarDir}/${fic}.$format" "https://data.explore.star.fr/api/records/1.0/download/?dataset=$fic&format=$format"
  fic="$fic.$format"
  (
    cd "${VarDir}"
    DlDir=20170103
    DlDir=20170227
    DlDir=20170619
    DlDir=20170829
    DlDir=20170928
    DlDir=20171010
    DlDir=$(date +%Y%m%d)
    [ -d "${DlDir}" ] || mkdir "$DlDir"
    [ -f "${DlDir}/${fic}" ] || cp -pv ${fic}  "${DlDir}/${fic}"
  )
}
#F STAR_dl: récupération du réseau Star sur l'open data de Rennes Métropole
STAR_dl_v1() {
  LOG "STAR_dl debut"
  local VarDir="${Drive}:/web.var/geo/RENNES"
#  http://www.data.rennes-metropole.fr/fileadmin/user_upload/data/data_sig/deplacement/reseau_star/reseau_star_shp_wgs84.zip
  format=reseau_star_shp_wgs84.zip
  _STAR_dl
  format=reseau_star_kml_wgs84.zip
  _STAR_dl
  format=reseau_star_csv.zip
  _STAR_dl
#  ls -lR $VarDir
  LOG "STAR_dl fin VarDir: $VarDir"
}
#f _STAR_dl:
_STAR_dl_v1() {
  wget -O "${VarDir}/${format}" http://www.data.rennes-metropole.fr/fileadmin/user_upload/data/data_sig/deplacement/reseau_star/${format}
  (
    cd "${VarDir}"
    DlDir=201408
    DlDir=201410
    DlDir=201509
    DlDir=201604
    DlDir=201609
    [ -d "${DlDir}" ] || mkdir "$DlDir"
    [ -f "${DlDir}/${format}" ] || cp -pv ${format}  "${DlDir}/${format}"
    7za -y x ${format}
  )
}
#F STAR_db: les données de Rennes Métropole pour la Star en version spatialite
STAR_db() {
  LOG "STAR_db debut"
  DB star_lignes
  DB star_pointsarret
  DB star_parcours
  DB star_dessertes
  DB star_dessertes_stops
  DB star_parcours_stops
  DB star_parcours_stops_lignes
  LOG "STAR_db fin"
}
#f KEOLIS_dl: récupération des données de Kéolis en format GTFS
KEOLIS_dl() {
  LOG "KEOLIS_dl debut"
  format=GTFS-20140626.zip
  format=GTFS-20140822.zip
  format=GTFS-20141015.zip
  format=GTFS-20141024.zip
  format=GTFS-20141230.zip
  format=GTFS-20150312.zip
  format=GTFS-20150331.zip
  format=GTFS-20150429.zip
  format=GTFS-20150507.zip
  format=GTFS-20150623.zip
  format=GTFS-20150702.zip
  version_prec=20150707
  version=20150824
  version=20150915
  version=20150915
  version=20151214
  version=20151218
  version=20160125
  version=20160209
  version=20160329
  version=20160419
  version=20160525
  version=20160706
  version=20160720
  version=20160831
  version=20160906
  format=GTFS-${version}.zip
  [ -d /${Drive}/web.var/geo/RENNES/$version ] || mkdir -p /${Drive}/web.var/geo/RENNES/$version
  wget -O "${Drive}:/web.var/geo/RENNES/${format}" http://data.keolis-rennes.com/fileadmin/OpenDataFiles/GTFS/${format}
  (
    cd "${Drive}:/web.var/geo/RENNES"
    7za -y x ${format}
    cd $version
    7za -y x ../${format}
  )
  LOG "KEOLIS_dl fin"
}
# https://data.explore.star.fr/explore/dataset/tco-busmetro-horaires-gtfs-versions-td
# http://ftp.keolis-rennes.com/opendata/tco-busmetro-horaires-gtfs-versions-td/attachments/GTFS_2016.9.4_2017-06-26_2017-07-09.zip
#
#f GTFS_dl: récupération des données de Kéolis en format GTFS sur le nouveau site
GTFS_dl() {
  LOG "GTFS_dl debut"
  version=20160921
  version=20161012
  version=20161021
  version=20161214
  version=20161221
  version=20170612
  version=20170626
  version=20170829
  version=20170905
  version=20170927
  version=$(date +%Y%m%d)
  format=GTFS-${version}.zip
  [ -d /${Drive}/web.var/geo/RENNES/$version ] || mkdir -p /${Drive}/web.var/geo/RENNES/$version
  wget -O "${Drive}:/web.var/geo/RENNES/${format}" http://ftp.keolis-rennes.com/opendata/tco-busmetro-horaires-gtfs-versions-td/attachments/GTFS_2017.1.3_2017-10-02_2017-10-15.zip
  (
    cd "${Drive}:/web.var/geo/RENNES"
    7za -y x ${format}
    cd $version
    7za -y x ../${format}
  )
  ls -alrt /d/web.var/geo/RENNES
  LOG "GTFS_dl fin /d/web.var/geo/RENNES"
}
#
# la version de la star data explorer des itinéraires des bus
#f PARCOURS_dl:
PARCOURS_dl() {
  LOG "PARCOURS_dl debut"
  ARCH "${Drive}:/web.var/geo/RENNES/parcours.zip"
  url="https://keolis-rennes.opendatasoft.com/explore/dataset/tco-bus-topologie-parcours-td/download/?format=shp&timezone=Europe/Berlin"
  wget --no-check-certificate -O "${Drive}:/web.var/geo/RENNES/parcours.zip" $url
  (
    cd "${Drive}:/web.var/geo/RENNES"
    7za -y x parcours.zip
  )
  LOG "PARCOURS_dl fin"
}

#f PARCOURS_db:
PARCOURS_db() {
  LOG "PARCOURS_db debut"
#  DB star_parcours
  DB star_parcours_mga
  LOG "PARCOURS_db fin"
}
#f KEOLIS_wm:
KEOLIS_wm() {
  LOG "KEOLIS_wm debut"
  version_prec=20140822
  version=20150824
  (
    cd "${Drive}:/web.var/geo/RENNES"
    WM ${version}/routes.txt ${version_prec}/routes.txt
  )
  LOG "KEOLIS_wm fin"
}
#f GTFS_pg: les données de Kéolis en version postgis
GTFS_pg() {
  LOG "GTFS_pg debut"
  PG
  PG keolis_routes
  PG keolis_trips
  PG keolis_stop_times
  PG keolis_stops
  PG keolis_iti
  LOG "GTFS_pg fin"
}
#f OSM_oapi: récupération des donnéees OSM avec l'overpass
OSM_oapi() {
  LOG "OSM_oapi debut"
  (
    cd ../osm
    bash scripts/osm.sh OAPI network
  )
  LOG "OSM_oapi fin"
}
#f OSM_map:
OSM_map() {
  LOG "OSM_map debut"
  set -x
#  spatialite_osm_map -o "${Drive}:/web/osm/OSM/${code_insee}_network.osm" -d ${CFG}/osm_map.sqlite
  spatialite_tool -e -shp ${CFG}/ln_route -d ${CFG}/osm_map.sqlite -t ln_route -c UTF-8
  LOG "OSM_map fin"
}
#F OSM_db: les données OSM en version spatialite
OSM_db() {
  LOG "OSM_db debut"
  OSM_oapi
  osm_import "${Drive}:/web/osm/OSM/${code_insee}_network.osm"
  DB lines_way
  DB lines_relation
  DB lines_relation_tags
  DB osm_route_master
  DB osm_route_bus
  DB osm_node_stop
  DB osm_stop_times
  LOG "OSM_db fin"
}
#F GTFS_db: les données de Kéolis en version spatialite
GTFS_db() {
  LOG "GTFS_db debut"
  DB routes
  DB routes_additionals
  DB trips
  DB stops
  DB AddGeometryColumn stops geom2154 2154
  DB stop_times
  DB keolis_stops
  DB keolis_stops_lignes
  DB keolis_iti
  DB keolis_trip
  LOG "GTFS_db fin"
}

#F BUS_STOP: les arrets de bus d'illenoo
BUS_STOP() {
  LOG "BUS_STOP debut"
  Base=${CFG}/bus_stop.sqlite
#  BUS_STOP_dl
  BUS_STOP_db
  DB arrets_logiques_illenoo_cg35
  DB osm_node_stop
  DB arrets_logiques_illenoo_proche
  DBgui
  LOG "BUS_STOP fin"
}
#f BUS_STOP_dl:
BUS_STOP_dl() {
  LOG "BUS_STOP_dl debut"
  (
    cd ../geoportail
    bash scripts/osm.sh Oapi dpt_bus_stop 35
  )
  LOG "ILLENOO_net fin"
}
#f BUS_STOP_db:
BUS_STOP_db() {
  LOG "BUS_STOP_db debut"
  Base=bus_stop.sqlite
  osm_import ../osm/OSM/dpt_bus_stop_35.osm
  LOG "BUS_STOP_db fin"
}
#f PARCOURS:
PARCOURS() {
  LOG "PARCOURS debut"
  HIGHWAY_db
  PARCOURS_db
  PARCOURS_ligne
  LOG "PARCOURS fin"
}
#F HIGHWAY_db: les données OSM en version spatialite
HIGHWAY_db() {
  LOG "HIGHWAY_db debut"
#  ( cd ../osm ; bash scripts/osm.sh --bbox departement35 OAPI highway );  exit
  Base=${CFG}/35_highway.sqlite
  osm_import ../osm/OSM/35_highway.osm
# certaines lignes sortent du département
#  osm_import ../osm/OSM/35_bbox.osm
  DB clean_way
  DB lines_way
  DB lines_way_tags
  DB AddGeometryColumn lines_way_tags geom2154 2154
  LOG "HIGHWAY_db fin"
}
#f PARCOURS_db:
PARCOURS_db() {
  LOG "PARCOURS_db debut"
  Base=${CFG}/35_highway.sqlite
  DB star_parcours
  DB star_parcours_mga
  LOG "PARCOURS_db fin"
}
#f PARCOURS_ligne:
PARCOURS_ligne() {
  LOG "PARCOURS_ligne debut"
  Base=${CFG}/35_highway.sqlite
  ligne="0006-01-A"
  if [ "$1" != "" ] ; then
    ligne=$1
    shift
  fi
  network=star
#  DB dump_kml ligne_star geom2154 NUM_LIGNE item_no
  buf=15
  DB ligne_segments star_parcours_mga
  DB ligne_buf
  DB ligne_way_si3
  DB ligne_way_ko
  DB ligne_way_distances
  DB ligne_way_ok
  LOG "PARCOURS_ligne fin"
}
#F ILLENOO_dl: les données de Rennes Métropole pour ILLENOO, récupération en wfs
ILLENOO_dl() {
  LOG "ILLENOO_dl debut"
  bash scripts/ogc.sh ILLENOO
  LOG "ILLENOO_dl fin"
}
#F ILLENOO_db: les données de Rennes Métropole pour la ILLENOO en version spatialite
ILLENOO_db() {
  LOG "ILLENOO_db debut"
  DB arrets_logiques_illenoo_cg35
  DB arrets_physiques_illenoo_cg35
  DB lignes_illenoo_cg35
  DB dump_csv lignes_illenoo_cg35
  LOG "ILLENOO_db fin"
}
#f ILLENOO_geojson:
ILLENOO_geojson() {
  LOG "GJ debut"
  _ENV_keolis_sqlite
  _ENV_gdald
  DB illenoo_parcours
  table=illenoo_parcours
  f_out="${CFG}/illenoo_parcours.geojson"
  [ -f $f_out ] && rm $f_out
  ogr2ogr -skipfailures -dsco SPATIALITE=yes -f "geojson" $f_out ${CFG}/$Base ${table}
  cp -pv $f_out ../leaflet/exemples
  LOG "ILLENOO_geojson fin"
}
#f ILLENOO_lignes:
ILLENOO_lignes() {
  LOG "ILLENOO_lignes debut"
  network=illenoo
#  DB dump_csv lignes_illenoo_cg35
  while read ligne ; do
    IFS=';' read -a champs <<< "${ligne}"
    ligne="${champs[2]}"
    if [ "$ligne" == "" ] ; then
      continue
    fi
    if [ "$ligne" = "NUM_LIGNE" ] ; then
      continue
    fi
    echo $ligne
    ILLENOO_ligne $ligne
    perl scripts/keolis.pl -g ${network} osm2route
#    exit
  done <  ${CFG}/lignes_illenoo_cg35.csv
  LOG "ILLENOO_lignes fin"
}

#F HIGHWAY_db: les données OSM en version spatialite
ILLENOO_net() {
  LOG "ILLENOO_net debut"
#  ( cd ../osm ; bash scripts/osm.sh OAPI network_illenoo )
  Base=illenoo.sqlite
  osm_import ../osm/OSM/35000_network_illenoo.osm
  DB lines_way
  DB lines_relation
  DB lines_relation_tags
  LOG "ILLENOO_net fin"
}
#f ILLENOO:
ILLENOO() {
  LOG "ILLENOO debut"
  HIGHWAY_db
  ILLENOO_db
  ILLENOO_ligne 7
  LOG "ILLENOO fin"
}
#f STAR:
STAR_db2() {
  LOG "STAR debut $Base"
  network=star
  rm /tmp/sql.log
#  HIGHWAY_db
  STAR_db
  DB lignes_star_rm
  DB ligne_segments lignes_star_rm
  STAR_lignes
  perl scripts/keolis.pl
  LOG "STAR fin"
}
#F STAR_db: les données de Rennes Métropole pour la Star en version spatialite
STAR_db_v1() {
  LOG "STAR_db debut"
  DB star_arret_logique
  DB star_arret_physique
  DB star_ligne_itineraire
  DB star_ligne_itineraire
  DB star_parcours
  LOG "STAR_db fin"
}

#f STAR_lignes:
STAR_lignes() {
  LOG "STAR_lignes debut"
  network=star
#  DB dump_csv lignes_star_rm
  while read ligne ; do
    IFS=';' read -a champs <<< "${ligne}"
    ligne="${champs[0]}"
    if [ "$ligne" == "" ] ; then
      continue
    fi
    if [ "$ligne" = "NUM_LIGNE" ] ; then
      continue
    fi
    echo $ligne
    STAR_ligne $ligne
    perl scripts/keolis.pl $network osm2route
  done <  ${CFG}/lignes_star_rm.csv
  LOG "STAR_lignes fin"
}
#f STAR_ligne:
STAR_ligne() {
  LOG "STAR_ligne debut"
  ligne="0001-01-A"
  if [ "$1" != "" ] ; then
    ligne=$1
    shift
  fi
  network=illenoo
  DB ligne_segments lignes_star_rm
  DB ligne_buf
  DB ligne_way_si3
  DB ligne_way_ko
  DB ligne_way_distances
  DB ligne_way_ok
  LOG "STAR_ligne fin"
}
#f ILLENOO_ligne:
ILLENOO_ligne() {
  LOG "ILLENOO_ligne debut"
  ligne=5
  if [ "$1" != "" ] ; then
    ligne=$1
    shift
  fi
  DB ligne_illenoo
  DB ligne_illenoo_buf
  DB ligne_illenoo_way_si3
  DB ligne_illenoo_way_ko
  DB ligne_illenoo_way_distances
  DB ligne_illenoo_way_ok
  LOG "ILLENOO fin"
}
#f ILLENOO_stops:
ILLENOO_stops() {
  LOG "ILLENOO_stops debut"
# on récupère les bus_stop dans osm
  perl scripts/keolis.pl --DEBUG_GET 1 -- illenoo bus_stop_35
# on les met en base
  DB bus_stop_35
# on recherche les stops illenoo qui ne sont pas dans osm
  DB bus_stop_hors_osm
# et on les ajoute
  perl scripts/keolis.pl --DEBUG 1 --DEBUG_GET 1 -- illenoo bus_stop_35_ajout
  LOG "ILLENOO_stops fin"
}

#F OSM_KEOLIS: comparaison OSM Kéolis
OSM_KEOLIS() {
  LOG "OSM_KEOLIS debut"
  [ -f ${Base} ] && rm ${Base}
  OSM_db
  GTFS_db
  DB osm_routes_keolis
#  DB osm_stops_keolis
#  keolis_route_master
  LOG "OSM_KEOLIS fin"
}
#F NET_db: routage d'une ligne
NET_db() {
  LOG "OSM_db debut"
  (
    cd ../osm
    bash scripts/osm.sh OAPI highway2
  )
  net_import
  DB osm_stop_times
  DB osm_stop_ligne
  NET osm_stop_ligne_csv
  NET osm_stop_ligne_node
  NET etapes
  NET from_to
  LOG "NET_db fin"
}
#
#F exemples: les fichiers pour la partie web
exemples() {
  LOG "exemples debut"
  sqlite_keolis_iti
  cp -pv /d/web.var/geo/RENNES/reseau_star_kml_wgs84/donnees/*.kml ../geoportail/exemples
  LOG "exemples fin"
}
#F AD: envoi sur AlwaysData
AD() {
  LOG "AD debut"
  . ../win32/WEB/always.site
  source ../win32/scripts/file.sh
  (
    cd ../geoportail
    for f in exemples/star_lignes*.html exemples/star_lignes*.js exemples/star_ligne*.kml exemples/*.gif; do
      P $f
    done
  )
  LOG "AD fin"
}
#
#f T: quelques tests sur l'api Kéolis
T() {
  LOG "T debut"
  set -x
#  wget -O /tmp/keolis.xml "${url}?version=1.0&key=${cle}&cmd=getstation&param[request]=number&param[value]=5"
#  wget -O /tmp/keolis.xml "${url}?version=2.0&key=${cle}&cmd=getlines"
  wget -O /tmp/keolis.xml "${url}?version=1.0&key=${cle}&cmd=getstation&param[request]=all"
#  wget -O /tmp/keolis.xml "http://data.keolis-rennes.com/xml/?cmd=getbusnextdepartures&version=2.2&key=${cle}&param%5Bmode%5D=line&param%5Broute%5D=0001&param%5Bdirection%5D=1"
#  wget -O /tmp/keolis.xml "http://data.keolis-rennes.com/xml/?cmd=getbusnextdepartures&version=2.2&key=${cle}&param%5Bmode%5D=stopline&param%5Broute%5D%5B%5D=0077&param%5Bdirection%5D%5B%5D=0&param%5Bstop%5D%5B%5D=3115&param%5Broute%5D%5B%5D=0061&param%5Bdirection%5D%5B%5D=1&param%5Bstop%5D%5B%5D=2706"
  cat /tmp/keolis.xml
  LOG "T fin"
}
#f DIFF:
DIFF() {
  LOG "DIFF debut"
  while read ref; do
    echo "DIFF() ref:$ref"
    perl scripts/keolis.pl -d --ref=$ref diff_route
  done <<EOF
1
2
3
C4
5
6
8
9
11
14
31
34
35
50
64
67
EOF
  LOG "DIFF fin"
}
#F RESEAU: verification du reseau par rapport au gtfs
RESEAU() {
  LOG "RESEAU debut"
# on commence par les stations
  perl scripts/keolis.pl -d -g gtfs diff_bus_stop
  LOG "RESEAU fin"
}
#F DIFF_ROUTES: verification de l'ensemble des routes
DIFF_ROUTES() {
  LOG "DIFF_ROUTES debut"
  rm ${CFG}/*.osm
  perl scripts/keolis.pl -d diff_routes 2>toto
  LOG "DIFF_ROUTES fin"
}
#f P: pour changer les scripts perl en version module
P() {
  LOG "P debut"
  cat <<'EOFPL' > /tmp/perl
  while (<>) {
    s/\$DEBUG/\$self->{DEBUG}/;
    s/\$DEBUG_GET/\$self->{DEBUG_GET}/;
    s/\$oOSM/\$self->{oOSM}/;
    s/\$oAPI/\$self->{oAPI}/;
    s/\$oOAPI/\$self->{oOAPI}/;
    s/\$oDB/\$self->{oDB}/;
    print;
  }
EOFPL
  perl /tmp/perl scripts/KeolisRouteMaster.pm > scripts/KeolisGtfs.pmi
  LOG "P fin"
}
#f GPX:
GPX() {
  LOG "GPX debut"
  _ENV_gdald
  local VarDir="${Drive}:/web.var/geo/RENNES"
# ${VarDir}/reseau_star_kml_wgs84/donnees/star_ligne_itineraire.kml
  rm ${CFG}/iti.gpx
#
#  ogr2ogr -skipfailures -nlt LINESTRING -dsco GPX_USE_EXTENSION=YES -f "GPX" ${CFG}/iti.gpx  ${CFG}/iti.kml star_ligne_itineraire
  gpsbabel -i kml -f ${CFG}/iti.kml -o gpx -F ${CFG}/iti.gpx
  LOG "GPX fin"
}
#F GJ: production du fichier geojson
GJ() {
  LOG "GJ debut"
  _ENV_keolis_sqlite
  _ENV_gdald
  table=star_parcours
  f_out="${CFG}/star_parcours.geojson"
  [ -f $f_out ] && rm $f_out
  ogr2ogr -skipfailures -dsco SPATIALITE=yes -f "geojson" $f_out ${CFG}/$Base ${table}
  cp -pv $f_out ../leaflet/exemples
  LOG "GJ fin $Base"
}
#F OSM: génération des fichiers gpx pour JOSM
OSM() {
  LOG "OSM debut"
  _ENV_keolis_sqlite
  _ENV_gdal210
  _ENV_gpsbabel
  table=star_parcours;champ=nomcourtlig;CFG=KEOLIS
#  table=illenoo_parcours;champ=NOM_LIGNE
  DB dump_txt ${table} id
  while read id ; do
    _OSM
  done < ${CFG}/${table}.txt
  LOG "OSM fin"
}
#f _OSM:
_OSM() {
  f_out="${CFG}/${table}.kml"
  [ -z "$id" ] && id='0068-01-A'
  [ -f $f_out ] && rm $f_out
#  ogr2ogr -sql "SELECT * FROM 'star_parcours' WHERE id='0036-01-B'" -skipfailures -dsco SPATIALITE=yes -f "GPX" $f_out $Base
  DB dump_kml ${table} geometry id ${champ} "id='$id'"
  gpsbabel -i kml -f $f_out -o gpx -F ${CFG}/${id}.gpx
  LOG "_OSM fin ${CFG}/${id}.gpx"
}
#F GPX
# http://www.underdiverwaterman.com/building-a-gps-track-database-with-spatialite/
#f GPX:
GPX() {
  LOG "GPX debut"
  _ENV_keolis_sqlite
  _ENV_gdal210
  set -x
#  ogrinfo KEOLIS/relation_route_4259842.gpx tracks
  ogr2ogr -skipfailures \
    -append -f "SQLite" -dsco SPATIALITE=yes -dsco INIT_WITH_EPSG=yes -t_srs epsg:4326 \
    ${CFG}/$Base KEOLIS/relation_route_4259842.gpx tracks -nln gpx

  LOG "GPX fin"
}
#f T43: test difference spatialite 4.2 # 4.3
T43() {
  LOG "T43 debut"
   . ../win32/scripts/misc_sqlite_test.sh
  rm KEOLIS/35000_network.sqlite
#  DB delete
  DB t43
  LOG "T43 fin"
}

#f T:
T() {
  LOG "T debut"
  rm KEOLIS/35000_network.sqlite
  table="star_ligne_itineraire"
#  table="test_geom"
#  DB test_geom
#  DB DissolveSegments ${table} ${table}_ds Geometry
#  DB DissolvePoints ${table} ${table}_firstlast Geometry
#  DB ElementaryGeometries ${table} ${table}_eg Geometry
  DB startend ${table} ${table}_firstlast Geometry
  LOG "T fin"
}
#F JOUR: les traitements journaliers
JOUR() {
  LOG "JOUR debut"
  PW 60
  rm TRANSPORT/*/*.osm
  _reseaux
  _keolis
  PW 10
  LOG "JOUR fin"
}
#f _keolis:
_keolis() {
  perl scripts/keolis.pl --DEBUG 1 --DEBUG_GET 0 --ref 77 star diff_routes
}
#f _reseaux:
_reseaux() {
  while read reseau; do
    echo $reseau
    perl scripts/keolis.pl --DEBUG 1 --DEBUG_GET 0 -- $reseau valid_routes_ways
#    perl scripts/keolis.pl --DEBUG 1 --DEBUG_GET 1 -- $reseau wiki_routes
  done <<'EOF'
star
illenoo
ksma
chateaubourg
surf
EOF

}
#F GIT: pour mettre à jour le dépot git
GIT() {
  LOG "GIT debut"
  Local="${DRIVE}/web/geo";  Depot=keolis; Remote=frama
  export Local
  export Depot
  export Remote
  _git_lst
  bash ../win32/scripts/git.sh INIT $*
#  bash ../win32/scripts/git.sh PUSH
  LOG "GIT fin"
}
#f _git_lst: la liste des fichiers pour le dépot
_git_lst() {
  cat  <<'EOF' > /tmp/git.lst
scripts/keolis.sh
EOF
  ls -1 scripts/keolis*.R >> /tmp/git.lst
  ls -1 scripts/keolis*.pl >> /tmp/git.lst
  ls -1 scripts/Transport*.pm>> /tmp/git.lst
  ls -1 TRANSPORT/RMAT/*.txt>> /tmp/git.lst
  cat  <<'EOF' > /tmp/README.md
# keolis : OpenStreetMap et réseaux de transport bus en Ille-et-Vilaine

Scripts en environnement Windows 10 : MinGW R MikTex

Les données de "Réseau Malo Agglomération Transport" sont dans le dossier TRANSPORT/RMAT
EOF
}

[ $# -eq 0 ] && ( HELP; exit )
CONF
while [ "$1" != "" ]; do
  case $1 in
    -b | --base )
      shift
      Base=$1
      $bbox
      ;;
    * )
      $*
      exit 1
  esac
  shift
done