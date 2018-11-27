# <!-- coding: utf-8 -->
# le réseau de bus
# utilisation des données d'OpenStreetMap
# auteur : Marc Gauthier
#
# https://github.com/oscarperpinan/spacetime-vis/blob/master/osmar.R
#
# les données arrêt
# source("geo/scripts/keolis.R");oapi_arrets_get()
oapi_arrets_get <- function() {
  carp()
  data <- sprintf("area[name='Ille-et-Vilaine'];(node['highway'='bus_stop'](area);node[public_transport](area););out meta;")
  f_osm <- sprintf("%s/arrets.osm", cfgDir);
  carp("f_osm: %s", f_osm)
  osm_oapi(data, f_osm)
}
#
# lecture avec sf
# https://github.com/r-spatial/sf/blob/master/tests/read.Rout.save
# source("geo/scripts/keolis.R");oapi_arrets_lire()
oapi_arrets_lire <- function() {
  carp()
  library(sf)
  library(tidyverse)
  if (! "OSM" %in% st_drivers()$name ) {
    stop("*** pas de driver OSM")
  }
  f_osm <- sprintf("%s/arrets.osm", cfgDir);
#  f_osm <- sprintf("geo/KEOLIS/arrets.osm");
  carp("f_osm: %s size: %s", f_osm, file.size(f_osm))
#  osm <- system.file(f_osm, package="sf")
  Sys.setenv(OSM_USE_CUSTOM_INDEXING="NO")
  st_layers(f_osm, do_count = TRUE)
  nc <- st_read(f_osm, "points")
  glimpse(nc)
  return(invisible(nc))
}
oapi_departement_get <- function() {
  carp()
  data <- sprintf("rel[name='Ille-et-Vilaine'][admin_level=6];>>;out meta;")
  f_osm <- sprintf("%s/departement.osm", cfgDir);
  carp("f_osm: %s", f_osm)
  osm_oapi(data, f_osm)
}
#
# les données d'un réseau de transport
oapi_transport_get <- function() {
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
oapi_cesson <- function() {
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
oapi_osm2sp <- function(source, index, type='lines'){
  idx <- find_down(source, index)
  obj <- subset(source, ids=idx)
  objSP <- as_sp(obj, type)
}
#
# pour faire un plan de la ligne
oapi_plan_ligne <- function(f_osm) {
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

