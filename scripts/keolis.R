# <!-- coding: utf-8 -->
# le réseau de bus de Rennes
# utilisation des données d'OpenStreetMap
# auteur : Marc Gauthier
#
# https://github.com/oscarperpinan/spacetime-vis/blob/master/osmar.R
mga  <- function() {
  setwd('d:/web')
  source("geo/scripts/keolis.R");shapes_partiel()
}
#
# les données d'un réseau de transport
transport_get <- function() {
  library(osmdata)
  data <- sprintf("(relation[network='FR:STAR'][type=route][route=bus];>>);out meta;")
  f_osm <- sprintf("%s/relation_route_bus.osm", cfgDir);
  osm_oapi(data, f_osm)
  q <- opq(bbox = c(51.1, 0.1, 51.2, 0.2))
  osm.sp <- osmdata_sp(q, f_osm)
}
#
# les données de cesson
# + les arrêts de bus
cesson <- function() {
  zone <- 'Cesson'
  type <- 'bus_stop'
  data <- oapi_requete(zone, type)
  f_osm <- sprintf("%s/osm/OSM/%s_%s.osm", baseDir, zone, type)
#  osm_oapi(data, f_osm)
  ref <- 'C6'
  data <- sprintf("(relation[network='FR:STAR'][type=route][route=bus][ref=%s];>>);out meta;", ref)
  f_osm <- sprintf("%s/relation_route_bus_%s.osm", cfgDir, ref);
  osm_oapi(data, f_osm)
  plan_ligne(f_osm)
}
osm2sp <- function(source, index, type='lines'){
  idx <- find_down(source, index)
  obj <- subset(source, ids=idx)
  objSP <- as_sp(obj, type)
}
#
# pour faire un plan de la ligne
plan_ligne <- function(f_osm) {
  library(osmar)
  print(sprintf("plan_ligne() %s", f_osm))
  osm <- get_osm(complete_file(), source = osmsource_file(f_osm))
#  plot(osm)
  ajout <- FALSE
  idx_highway <- find(osm, way(tags(k=='highway')))
  sp_highway <- osm2sp(osm, way(idx_highway))
  plot(sp_highway, add = ajout, col = "pink",lwd=5)
# les arrêts
  print(sprintf("plan_ligne() les arrêts"))
  idx_bus_stop <- find(osm, node(tags(k=='highway' & v=="bus_stop")))
  sp_bus_stop <- osm2sp(osm, node(idx_bus_stop), 'points')
# pour ajouter le tag "name"
  tags <- subset(osm$nodes$tags, subset=(k=='name'), select=c('id', 'v'))
  tags_match <- match(idx_bus_stop, tags$id)
  tags <- tags[tags_match,]
  sp_bus_stop$name <- tags$v[tags_match]
  sp_bus_stop$name <- iconv(sp_bus_stop$name, "UTF-8")
  text(coordinates(sp_bus_stop), labels=sp_bus_stop@data$name)
}
#
# lecture des routes, données GTFS
gtfs_routes <- function() {
  dsn <- sprintf("%s/routes.txt", odDir)
  df <- read.table(dsn, header=TRUE, sep=",", blank.lines.skip = TRUE, stringsAsFactors=FALSE, quote='"', encoding="UTF-8")
  df$route_id <- sprintf("%04d", df$route_id)
  print(head(df))
  print(sprintf("gtfs_routes() nrow : %d", nrow(df)))
  return(invisible(df))
}
#
# lecture du tracé des lignes, données GTFS
gtfs_shapes <- function() {
  dsn <- sprintf("%s/shapes.txt", odDir)
  df <- read.table(dsn, header=TRUE, sep=",", blank.lines.skip = TRUE, stringsAsFactors=FALSE, quote='"', encoding="UTF-8")
  print(sprintf("gtfs_shapes() nrow : %d", nrow(df)))
  return(invisible(df))
}
#
# lecture des stop_times, données GTFS
gtfs_stop_times <- function() {
  if ( ! exists("stop_times.df") ) {
    dsn <- sprintf("%s/stop_times.txt", odDir)
    df <- read.table(dsn, header=TRUE, sep=",", blank.lines.skip = TRUE, stringsAsFactors=FALSE, quote='"', encoding="UTF-8")
    print(head(df))
    print(sprintf("gtfs_stop_times() nrow : %d", nrow(df)))
    stop_times.df <<- df
  }
  return(invisible(stop_times.df))
}
#
# lecture des stops, données GTFS
gtfs_stops <- function() {
  dsn <- sprintf("%s/stops.txt", odDir)
  df <- read.table(dsn, header=TRUE, sep=",", blank.lines.skip = TRUE, stringsAsFactors=FALSE, quote='"', encoding="UTF-8")
  print(head(df))
  print(sprintf("gtfs_stops() nrow : %d", nrow(df)))
  return(invisible(df))
}
#
# lecture des trips, données GTFS
gtfs_trips <- function() {
  dsn <- sprintf("%s/trips.txt", odDir)
  df <- read.table(dsn, header=TRUE, sep=",", blank.lines.skip = TRUE, stringsAsFactors=FALSE, quote='"', encoding="UTF-8")
  return(invisible(df))
}
#
# ajout d'info aux shapes
shapes_cpl <- function(df) {
  print(sprintf("shapes_cpl"))
  df$route_id <- gsub("^(\\d+).*", "\\1", df$shape_id, perl=TRUE)
  df$ab <- gsub("^\\d+\\-([ABC]).*", "\\1", df$shape_id, perl=TRUE)
  df$depart_id <- gsub("^\\d+\\-[ABC]\\-(\\d+).*", "\\1", df$shape_id, perl=TRUE)
  df$arrivee_id <- gsub("^.*\\-(\\d+)$", "\\1", df$shape_id, perl=TRUE)
  stops.df <- gtfs_stops()
  stops.df <- stops.df[, c("stop_id", "stop_name")]
  df <- merge(df, stops.df, by.x="depart_id", by.y="stop_id", all.x=TRUE, all.y=FALSE)
  inconnu.df <- subset(df, is.na(df$stop_name))
  if ( nrow(inconnu.df) > 0 ) {
    print(sprintf("shape_cpl() stop_name invalide nb: %d", nrow(inconnu.df)))
    print(head(inconnu.df))
    stop("***")
  }
  base::names(df)[base::names(df)=="stop_name"] <- "depart_name"
  df <- merge(df, stops.df, by.x="arrivee_id", by.y="stop_id")
  inconnu.df <- subset(df, is.na(df$stop_name))
  if ( nrow(inconnu.df) > 0 ) {
    print(sprintf("shape_cpl() stop_name invalide nb: %d", nrow(inconnu.df)))
    print(head(inconnu.df))
    stop("***")
  }
  base::names(df)[base::names(df)=="stop_name"] <- "arrivee_name"
  routes.df <- gtfs_routes()
  routes.df <- routes.df[, c("route_id", "route_short_name", "route_long_name")]
  df <- merge(df, routes.df, by.x="route_id", by.y="route_id", all.x=TRUE, all.y=FALSE)
  inconnu.df <- subset(df, is.na(df$route_short_name))
  if ( nrow(inconnu.df) > 0 ) {
    print(sprintf("shape_cpl() stop_name invalide nb: %d", nrow(inconnu.df)))
    print(head(inconnu.df))
    stop("***")
  }
  df <- df[order(df$shape_id),]
#  print(head(subset(df, 'shape_id' == '0001-A-2126-1024')))
  return(df)
}
#
# conversion des tracés shape en kml
shapes2kml <- function() {
  library(sp)
  library(rgdal)
  df <- gtfs_shapes()
  coordinates(df) = ~ shape_pt_lon + shape_pt_lat
  ids <- unique(df$shape_id)
  liste <- list()
  for ( i in 1:length(ids) ) {
    id <- ids[i]
    print(sprintf("shapes() i : %d, id : %s", i, id))
    df1 <- df[df$shape_id == id,]
    df1 <- df1[with(df1, order(df1$shape_pt_sequence)), ]
#    print(head(df1))
#    plot(df1)
    l <- Lines(Line(coordinates(df1)), ID=id)
    liste[[i]] <- l
  }
  sl <- SpatialLines(liste)
  spdf <- SpatialLinesDataFrame(sl, data.frame(name=ids), match.ID = FALSE)
  proj4string(spdf) <- CRS("+init=epsg:4326")
  plot(spdf)
  dsn <- sprintf("%s/shapes.kml", odDir)
  writeOGR(spdf, dsn, layer="ligne", driver="KML", overwrite_layer=TRUE)
  print(sprintf("shapes2kml() dsn : %s", dsn))
}
#
# recherche des itinéraires partiels
# l'itinéraire est-il inclus dans un autre itinéraire ?
# on ajoute un buffer autour de l'itinéraire => un polygone
# on recherche si un ou plusieurs itinéraires sont à l'intérieur du polygone
# !!! ne fonctionne pas
# si l'itinéraire comporte plusieurs fois le même segment
# !!! il faut calculer la longueur "intersectée"
shapes_partiel <- function() {
  library(sp)
  library(rgdal)
  library(rgeos)
  if ( ! exists("shapes.spdf") ) {
    dsn <- sprintf("%s/shapes.kml", odDir)
    spdf <- readOGR(dsn, layer="ligne", stringsAsFactors=FALSE)
    print(sprintf("shapes2kml() dsn : %s", dsn))
    shapes.spdf <<- spTransform(spdf, CRS("+init=epsg:2154"))
  }
  spdf <- shapes.spdf[, c("Name")]
  spdf@data$longueur <- as.integer(gLength(spdf, byid=TRUE))
  for (i in 1:nrow(spdf@data) ) {
    spdf1 <- spdf[i, ]
    sp <- rgeos::gBuffer(spdf1, width=25, byid=FALSE, id=NULL)
    spdf2 <- SpatialPolygonsDataFrame(sp, spdf@data[i, ], match.ID = FALSE)
    spdf4 <- raster::intersect(spdf1, spdf2)
    spdf4@data$lgi <- as.integer(gLength(spdf4, byid=TRUE))
    spdf@data[i, "lgi"] <- spdf4@data[1, "lgi"]
  }
#  View(spdf);stop("***")
#  spdf$i <- 1:nrow(spdf)
  for (i in 1:nrow(spdf@data) ) {
#    print(summary(spdf[spdf$i == 1, ])); stop("***")
    spdf1 <- spdf[i, ]
    print(sprintf("shapes_partiel() i : %d", i))
#    plot(spdf1);
    sp <- rgeos::gBuffer(spdf1, width=25, byid=FALSE, id=NULL)
    spdf2 <- SpatialPolygonsDataFrame(sp, spdf@data[i, ], match.ID = FALSE)
    spdf3 <- raster::intersect(spdf, spdf2)
    spdf3@data$lg <- as.integer(gLength(spdf3, byid=TRUE))
    df <- spdf3@data
#    View(df); stop("****")

#    df$delta <- df@longueur.1 - df$lg
    df1 <- df[df$Name.1 == df$Name.2, ]
#    print(head(df))
    if ( df1$lgi.1 != df1$lg ) {
      print(df1)
      plot(sp)
      plot(spdf1, add=TRUE)
      stop("*** df1")
    }
    df1 <- df[df$Name.1 != df$Name.2, ]
    if ( nrow(df1) == 0 ) {
      next
    }
    df2 <- df1[df1$lgi.1 <= df1$lg, ]
    if ( nrow(df2) == 0 ) {
      next;
    }
    print(df2)
    plot(sp)
    plot(spdf1, add=TRUE)
#    stop("*** df2")
#    print(df[df$longueur.1 <= df$lg, ])
  }
}
#
# génération des itinéraires par route
shapes2routes <- function() {
  library(sp)
  library(rgdal)
  library(rgeos)
  print(sprintf("shapes2routes()"))
  if ( ! exists("shapes.spdf") ) {
    dsn <- sprintf("%s/shapes.kml", odDir)
    spdf <- readOGR(dsn, layer="ligne", stringsAsFactors=FALSE)
    print(sprintf("shapes2kml() dsn : %s", dsn))
    shapes.spdf <<- spdf
  }
  spdf <- shapes.spdf[, c("Name")]
  colnames(spdf@data) <- c('shape_id')
  spdf <- shapes_cpl(spdf)
  dsn <- sprintf("%s/shapes2routes.geojson", webDir)
  writeOGR(spdf, dsn, layer="routes", driver="GeoJSON", overwrite_layer=TRUE)
  print(sprintf("shapes2routes() dsn : %s", dsn))
  dsn <- sprintf("%s/shapes2routes.csv", odDir)
  write.csv(spdf@data, file=dsn, row.names=FALSE, na="", quote = FALSE, fileEncoding = "UTF-8")
  print(sprintf("shapes2routes() dsn : %s", dsn))
}
#
# génération des itinéraires par shape
shapes2shape <- function() {
  library(sp)
  library(rgdal)
  library(rgeos)
  if ( ! exists("shapes.spdf") ) {
    dsn <- sprintf("%s/shapes.kml", odDir)
    spdf <- readOGR(dsn, layer="ligne", stringsAsFactors=FALSE)
    print(sprintf("shapes2kml() dsn : %s", dsn))
    shapes.spdf <<- spdf
  }
  spdf <- shapes.spdf[, c("Name")]
  colnames(spdf@data) <- c('shape_id')
  spdf <- shapes_cpl(spdf)
  spdf <- spdf[, c("shape_id")]
  for (i in 1:nrow(spdf@data) ) {
    print(summary(spdf[i, ]));
    dsn <- sprintf("%s/%s.gpx", osmDir, spdf@data[i, 'shape_id'])
    print(sprintf("shapes2shape() dsn : %s", dsn))
    writeOGR(spdf[i, ], dsn, layer="routes", driver="GPX", dataset_options="GPX_USE_EXTENSIONS=yes", overwrite_layer=TRUE)
  }
}
#
# détermination pour les voyages (trips) du parcours (shape) et des arrêts (stops)
trips_stops <- function() {
#  library(tidyr)
  library(dplyr)
  df <- gtfs_stop_times()
  df1 <- df %>%
    group_by(trip_id) %>%
    arrange(stop_sequence) %>%
    summarise(nb=n(), depart=first(stop_id), arrivee=last(stop_id), arrets=paste(stop_id, collapse = ";"))
  trips.df <- gtfs_trips()
  trips.df <- trips.df[, c("trip_id", "shape_id")]
  df1 <- merge(df1, trips.df, by.x="trip_id", by.y="trip_id", all.x=TRUE, all.y=FALSE)
  print(head(df1))
  df2 <- df1 %>%
    group_by(shape_id, arrets) %>%
    summarise(nb=n())
  print(head(df2))
  print(sprintf("trips_stops() df2 nrow : %d", nrow(df2)))
  df3 <- df2 %>%
    group_by(shape_id) %>%
    summarise(nb=n())
  df3 <- df3[df3$nb > 1, ]
  options(tibble.width = Inf)
  print(head(df3))
  dsn <- sprintf("%s/trips_stops.csv", odDir)
  write.csv(df2, file=dsn, row.names=FALSE, na="", quote = FALSE, fileEncoding = "UTF-8")
#
# les voyages avec le même parcours
  print(sprintf("trips_stops() df3 nrow : %d", nrow(df3)))
  print(df2[df2$shape_id %in% df3$shape_id, ])
}
#
# téléchargement à partir de https://data.explore.star.fr
star_dl <- function() {
  df <- read.table(text="fic format
tco-bus-topologie-dessertes-td csv
tco-bus-topologie-lignes-td csv
tco-bus-topologie-parcours-td csv
tco-bus-topologie-parcours-td geojson
tco-bus-topologie-pointsarret-td geojson
", header=TRUE, sep=" ", blank.lines.skip = TRUE, stringsAsFactors=FALSE, quote="")
  for(i in 1:nrow(df) ) {
    fic <- df$fic[i]
    if ( grepl('^#', fic) ) {
      next
    }
    dest <- sprintf("%s/%s.%s", odDir, fic, df$format[i])
    url <- sprintf("https://data.explore.star.fr/api/records/1.0/download/?dataset=%s&format=%s", fic, df$format[i])
    print(sprintf("star_dl() dest : %s", dest))
    download.file(url,dest)
  }
}
#
# lecture du fichier en provenance de la star
star_dessertes_lire <- function() {
  dsn <- sprintf("%s/%s.%s", odDir, "tco-bus-topologie-dessertes-td", "csv")
  if ( ! exists("dessertes.df") ) {
    dessertes.df <<- read.csv(dsn,header=TRUE, sep=";", quote = "", stringsAsFactors=FALSE, fileEncoding="utf8")
  }
  return(invisible(dessertes.df))
}
star_parcours_lire <- function() {
  dsn <- sprintf("%s/%s.%s", odDir, "tco-bus-topologie-parcours-td", "geojson")
  if ( ! exists("parcours.spdf") ) {
    parcours.spdf <<- ogr_lire(dsn)
  }
  return(invisible(parcours.spdf))
}
star_pointsarret_lire <- function() {
  dsn <- sprintf("%s/%s.%s", odDir, "tco-bus-topologie-pointsarret-td", "geojson")
  if ( ! exists("pointsarret.spdf") ) {
    pointsarret.spdf <<- ogr_lire(dsn, "wkbPoint")
  }
  return(invisible(pointsarret.spdf))
}
star_parcours_gpx <- function() {
  spdf <- spTransform(parcours.spdf, CRS("+init=epsg:4326"))
  spdf <- spdf[, c("code")]
  colnames(spdf@data) <- c("Name")
  for (i in 1:nrow(spdf) ) {
    spdf1 <- spdf[i, ]
    dsn <- sprintf("%s/%s.gpx", webDir, spdf1$Name)
    writeOGR(spdf1, dsn, layer="routes", driver="GPX", dataset_options="GPX_USE_EXTENSIONS=yes", overwrite_layer=TRUE)
  }
}
#
# lecture des fichiers en provenance d'osm
# http://rpubs.com/RobinLovelace/11962
star_osm_lire <- function() {
  library(raster)
  if ( exists("osm.spdf") ) {
    return(invisible(osm.spdf))
    rm("osm.spdf", pos = ".GlobalEnv")
  }
  files <- list.files(path=transportDir, pattern = "*.gpx", recursive=FALSE)
  for (i in 1:length(files)) {
    file <- files[i]
    dsn <- sprintf("%s/%s", transportDir, file)
    spdf <- ogr_lire(dsn, layer="tracks")
#    print(summary(spdf))
    print(spdf@data$name)
    spdf <- spdf[, c("name")]
    if ( ! exists("osm.spdf") ) {
      osm.spdf <- spdf
    } else {
#      print(class(spdf))
#      print(class(osm.spdf))
      osm.spdf <- rbind(osm.spdf, spdf)
    }
#    break
  }
  osm.spdf <<- osm.spdf
}
#
# comparaison lignes
# on calcule la longueur
star_comparaison <- function() {
  library(sp)
  library(rgdal)
  library(rgeos)
  spdf <- star_osm_lire()
  star_parcours_lire()
  spdf <- spdf[order(spdf@data$name, na.last = TRUE),]
  spdf@data$longueur <- as.integer(gLength(spdf, byid=TRUE))
  parcours.spdf@data$longueur <- as.integer(gLength(parcours.spdf, byid=TRUE))
  print(sprintf("star_comparaison() nrow : %s", nrow(spdf)))
  for (i in 1:nrow(spdf) ) {
#    print(spdf@data$name)
    spdf1 <- spdf[i, ]
    spdf2 <- parcours.spdf[parcours.spdf@data$code == spdf1@data$name, ]
#    print(sprintf("star_comparaison() %-30s %d", spdf1@data$name, nrow(spdf2)))
    if ( nrow(spdf2) == 0 ) {
      next
    }
    sp <- rgeos::gBuffer(spdf2, width=25, byid=FALSE, id=NULL)
    spdf3 <- SpatialPolygonsDataFrame(sp, spdf2@data, match.ID = FALSE)
    spdf4 <- raster::intersect(spdf2, spdf3)
    spdf4@data$longueur <- as.integer(gLength(spdf4, byid=TRUE))
    if ( 1 == 2 ) {
      dev.new()
      plot(spdf3)
      plot(spdf4, add=TRUE, col="red")
    }
    ratio2 <- as.integer(((spdf2@data$longueur-spdf4@data$longueur)/spdf2@data$longueur)*100)
    spdf5 <- raster::intersect(spdf1, spdf3)
    spdf5@data$longueur <- as.integer(gLength(spdf5, byid=TRUE))
    ratio1 <- as.integer(((spdf4@data$longueur-spdf5@data$longueur)/spdf4@data$longueur)*100)
    print(sprintf("%30-s %8s %8s %8s %8s %8s %8s", spdf1@data$name, spdf2@data$longueur, spdf1@data$longueur, spdf4@data$longueur, ratio2, spdf5@data$longueur, ratio1))
  }
}
#
# validation arrets
# on calcule la longueur
star_valide_arrets <- function() {
  library(sp)
  library(rgdal)
  library(rgeos)
  star_pointsarret_lire()
  star_parcours_lire()
  star_dessertes_lire()
  print(sprintf("star_valide_arrets() nrow : %s", nrow(dessertes.df)))
  dessertes.df <- dessertes.df[order(dessertes.df$idparcours, na.last = TRUE),]
  for (i in 1:nrow(dessertes.df) ) {
#    print(dessertes.df[i, ])
    idparcours <- dessertes.df[i, 'idparcours']
    spdf1 <- parcours.spdf[parcours.spdf@data$code == idparcours, ]
    idarret <- dessertes.df[i, 'idarret']
    spdf2 <- pointsarret.spdf[pointsarret.spdf@data$code == idarret, ]
    d <- as.integer(gDistance(spdf1, spdf2))
    if ( d > 20 ) {
      print(sprintf("%-30s %s %-4s %s", idparcours, idarret, d, dessertes.df[i, 'nomarret']))
    }
  }
}
# lecture d'un fichier ogr
# wkbMultiLineString wkbPolygon
ogr_lire <- function(dsn, geomType="wkbLineString", layer=FALSE) {
  require(rgdal)
  require(rgeos)
  Log(sprintf("ogr_lire() dsn:%s", dsn))
  if ( layer == FALSE ) {
    layer <- ogrListLayers(dsn)
    print(sprintf("ogr_lire() %s %s", layer, dsn))
    spdf <- readOGR(dsn, layer=layer, stringsAsFactors=FALSE, use_iconv=TRUE, encoding="UTF-8", require_geomType=geomType)
  } else {
    spdf <- readOGR(dsn, layer=layer, stringsAsFactors=FALSE, use_iconv=TRUE, encoding="UTF-8")
  }
  spdf <- spTransform(spdf, CRS("+init=epsg:2154"))
  return(invisible(spdf))
}
Drive <- substr( getwd(),1,2)
baseDir <- sprintf("%s/web", Drive)
cfgDir <- sprintf("%s/web/geo/KEOLIS", Drive)
odDir <- sprintf("%s/web.var/geo/STAR", Drive)
webDir <- sprintf("%s/web/leaflet/exemples", Drive)
osmDir <- sprintf("%s/web/geo/KEOLIS", Drive)
transportDir <- sprintf("%s/web/geo/TRANSPORT/STAR", Drive)
setwd(baseDir)
DEBUG <- FALSE
source("geo/scripts/misc_osm.R")
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
