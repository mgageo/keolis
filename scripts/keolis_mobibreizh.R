# <!-- coding: utf-8 -->
# les réseaux de bus de la région Bretagne
# utilisation des données opendata
# auteur : Marc Gauthier
#
#
#
# validation des fichiers gtfs
# source("geo/scripts/keolis.R");mobibreizh_jour()
mobibreizh_jour <- function() {
  mobibreizh_routes()
  stop('***')
  mobibreizh_shapes()
  mobibreizh_star()
}
#
# la validation des routes
# source("geo/scripts/keolis.R");mobibreizh_agency()
mobibreizh_agency <- function() {
  library(tidyverse)
  library(readxl)
  carp()
  dsn <- sprintf("%s/agency.xlsx", odDir)
  df <- readxl::read_excel(dsn, col_names = TRUE, na = "") %>%
   replace(is.na(.), '')
  glimpse(df)
#
# le template wiki
#  template <- readLines(dsn)
  wiki <- "<!-- coding: utf-8 -->
==Par territoire==
{|class='wikitable' width='100%'
|-class='sorttop'
!scope='col'| Territoire
!scope='col'| Collectivité gestionnaire
!scope='col'| Nom du réseau
!scope='col'| {{Tag|network}}
!scope='col'| {{Tag|operator}}
!scope='col'| Site web d'informations
!scope='col'| agency
!scope='col'| Page wiki de suivi
"
  template <- "|-
!scope='row' style='text-align:left'| @$territoire@ || [[@$gestionnaire@]]
| @$reseau@ || {{TagValue|network||@$network@}} || {{TagValue|operator||@$operator@}}||@$site@
| @$agency@ ||
"
  for ( i in 1:nrow(df) ) {
    tpl <- template
    tpl <- template(tpl, df[i,])
    wiki <- sprintf("%s%s", wiki, tpl)
  }
  wiki <- sprintf("%s%s", wiki, '|}')
  dsn <- sprintf("%s/agency_wiki.txt", odDir)
  write(wiki, file = dsn, append = FALSE)
  carp("dsn: %s", dsn);
}
template <- function(tpl, df) {
  attributs <- colnames(df)
  glimpse(attributs)
  for (attribut in attributs) {
    pattern <- sprintf('@\\$%s@', attribut)
    v <- df[1, attribut]
#    carp("pattern: %s v: %s", pattern, v)
    tpl <- gsub(pattern, v, tpl)
  }
#  carp("tpl :%s", tpl)
  return(tpl)
}
#
# la validation des routes
# source("geo/scripts/keolis.R");mobibreizh_routes()
mobibreizh_routes <- function() {
  library(tidyverse)
  carp()
  df <- gtfs_routes()
  df1 <- df %>%
    group_by(agency_id) %>%
    summarize(nb=n()) %>%
    glimpse() %>%
    print(n=100)
}
#
# la validation des shapefiles
mobibreizh_shapes <- function() {
  carp()
  df <- gtfs_shapes_verif()
}
#
# la validation des voyages/arrets
# source("geo/scripts/keolis.R");mobibreizh_gtfs_trips_stops()
mobibreizh_gtfs_trips_stops <- function() {
  carp()
  odDir <<- sprintf("%s/web/geo/TRANSPORT/MOBIBREIZH", Drive)
  df <- gtfs_trips_stops()
}
gtfs_trips_stops
#
# la comparaison sur le réseau STAR
# source("geo/scripts/keolis.R");mobibreizh_star_routes()
mobibreizh_star_routes <- function() {
  library(tidyverse)
  library(stringr)
  odDir <<- sprintf("%s/web/geo/TRANSPORT/MOBIBREIZH", Drive)
  mobibreizh_routes.df <- gtfs_routes()
  odDir <<- sprintf("%s/web/geo/TRANSPORT/STAR", Drive)
  star_routes.df <- gtfs_routes()
  df <- mobibreizh_routes.df %>%
    filter(agency_id == 'STAR') %>%
    glimpse()
  star_routes.df %>%
    glimpse()
  df %>%
    anti_join(star_routes.df,by=(c("route_short_name"="route_short_name"))) %>%
    glimpse() %>%
    print(10)
  star_routes.df %>%
    anti_join(df,by=(c("route_short_name"="route_short_name"))) %>%
    glimpse() %>%
    print(10)
}
#
# la comparaison sur le réseau STAR
mobibreizh_star_stops <- function() {
  library(tidyverse)
  library(stringr)
  odDir <<- sprintf("%s/web/geo/TRANSPORT/MOBIBREIZH", Drive)
  mobibreizh_stops.df <- gtfs_stops()
  odDir <<- sprintf("%s/web/geo/TRANSPORT/STAR", Drive)
  star_stops.df <- gtfs_stops()
  star_stops.df$stop_id <- sprintf('%04d', star_stops.df$stop_id)
  df <- mobibreizh_stops.df %>%
    filter(grepl(':STA', stop_id)) %>%
    mutate(timeo=str_extract(stop_id, "\\d+")) %>%
    glimpse()
  df1 <- df %>%
    group_by(timeo) %>%
    summarise(nb=n()) %>%
    glimpse()
  df2 <- df1 %>%
    left_join(df, by=c("timeo"="timeo")) %>%
    distinct(timeo, .keep_all = TRUE) %>%
    glimpse()
  df3 <- df2 %>%
    left_join(star_stops.df, by=c("timeo"="stop_id")) %>%
    glimpse()
  df3 %>%
    filter(stop_name.x != stop_name.y) %>%
    glimpse()
  df3 %>%
    filter(stop_lon.x != stop_lon.y) %>%
    glimpse()
  df3 %>%
    filter(is.na(stop_name.y)) %>%
    glimpse() %>%
    head(20)
  carp("star versus mobibreiz")
  df3 <- star_stops.df %>%
    left_join(df2, by=c("stop_id"="timeo")) %>%
    glimpse()

  df3 %>%
    filter(is.na(stop_name.y)) %>%
    glimpse() %>%
    head(20)
}
#
# les stops : ajout de la commune
# utilisation de la version IGN pour avoir des informations en plus de la géométrie
#
# source("geo/scripts/keolis.R");mobibreizh_stops()
mobibreizh_stops <- function() {
  library(tidyverse)
  library(stringr)
  odDir <<- sprintf("%s/web/geo/TRANSPORT/MOBIBREIZH", Drive)
  stops.df <- gtfs_stops_verif()
  if ( ! exists("communes.sf") ) {
    communes.sf <<- ign_ade_lire_sf()
  }
  glimpse(communes.sf)
  stops.sf <- st_as_sf(stops.df, coords = c("lon", "lat"), crs = 4326)
  stops.sf <- st_transform(stops.sf, 2154)
  communes.sf <- st_transform(communes.sf, 2154)
  carp("crs: %s", st_crs(stops.sf))
  carp("crs: %s", st_crs(communes.sf))
  nc <- st_join(stops.sf, communes.sf, join = st_intersects) %>%
    glimpse()
  filter(nc, NOM_REG != 'BRETAGNE') %>%
    group_by(NOM_DEP) %>%
    summarize(nb=n()) %>%
    glimpse()
  dsn <- sprintf("%s/mobibreizh_stops.Rds", odDir)
  saveRDS(nc,dsn)
}
#
# lecture du fichier
# source("geo/scripts/keolis.R");mobibreizh_stops_lire()
mobibreizh_stops_lire <- function() {
  odDir <<- sprintf("%s/web/geo/TRANSPORT/MOBIBREIZH", Drive)
  dsn <- sprintf("%s/mobibreizh_stops.Rds", odDir)
  carp("dsn: %s", dsn)
  nc <- readRDS(dsn)
  glimpse(nc)
  return(invisible(nc))
}
#
# validation des stops opendata et des arrêts osm
# source("geo/scripts/keolis.R");mobibreizh_stops_valid()
mobibreizh_stops_valid <- function() {
  nc <- mobibreizh_stops_lire()
# on enlève la SNCF
  nc <- filter(nc, ! grepl(':SNC', stop_id))
  stops.sf <- filter(nc, NOM_REG == 'BRETAGNE')
  stops.sf <- filter(nc, INSEE_DEP == 35)
#  stops.sf <- filter(nc, INSEE_COM == 35051)
  arrets.sf <- oapi_arrets_lire()
  arrets.sf <- st_transform(arrets.sf, 2154)
#  st_distance(stops.sf, arrets.sf) %>%
#    glimpse()
  carp("calcul des distances")
  arrets.sf$name <- as.character(arrets.sf$name)
  for ( i in 1:nrow(stops.sf) ) {
    if ( i%%100 == 0 ) {
      carp("%d/%d", i, nrow(stops.sf))
    }
    g <- st_distance(stops.sf[i,], arrets.sf, byid=TRUE)
    j <- which.min(g)
    d <- g[j]
    stops.sf$distance[i] <- as.integer(d)
    stops.sf$arret[i] <- arrets.sf$name[j]
  }
  glimpse(stops.sf)
# la liste avec une distance grande
  filter(stops.sf, distance > 100) %>%
    select(NOM_COM, stop_id, stop_name, arret, distance) %>%
    arrange(desc(distance)) %>%
    print(n=100)
#  return(invisible(nc))
}