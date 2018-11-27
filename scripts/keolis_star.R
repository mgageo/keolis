# <!-- coding: utf-8 -->
# le réseau de bus de Rennes
# utilisation des données opendata
# auteur : Marc Gauthier
#
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

