# <!-- coding: utf-8 -->
# le réseau de bus de Rennes
# utilisation des données d'OpenStreetMap
# auteur : Marc Gauthier
#

Drive <- substr( getwd(),1,2)
baseDir <- sprintf("%s/web", Drive)
cfgDir <- sprintf("%s/web/geo/KEOLIS", Drive)
odDir <- sprintf("%s/web.var/geo/STAR", Drive)
odDir <- sprintf("%s/web/geo/TRANSPORT/MOBIBREIZH", Drive)
webDir <- sprintf("%s/web/leaflet/exemples", Drive)
osmDir <- sprintf("%s/web/geo/KEOLIS", Drive)
transportDir <- sprintf("%s/web/geo/TRANSPORT/STAR", Drive)
setwd(baseDir)
DEBUG <- FALSE
source("geo/scripts/misc.R")
source("geo/scripts/misc_couches.R")
source("geo/scripts/misc_datagouv.R")
source("geo/scripts/misc_gtfs.R")
source("geo/scripts/misc_osm.R")
source("geo/scripts/keolis_misc.R")
source("geo/scripts/keolis_mobibreizh.R")
source("geo/scripts/keolis_oapi.R")
source("geo/scripts/keolis_star.R")
if ( interactive() ) {
  DEBUG <- TRUE
  graphics.off()
#  shapes()
} else {
#  cesson()
#  osm_fla()
#  shapes2kml()
#  shapes_partiel()
#  shapes2routes()
  shapes2shape()
#  trips_stops()
#  transport_get()
}
