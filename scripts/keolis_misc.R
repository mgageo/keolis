# <!-- coding: utf-8 -->
# le réseau de bus
# utilisation des données d'OpenStreetMap
# auteur : Marc Gauthier
#
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
