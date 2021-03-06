fast_merge <- function(x) {
  ## about 3 times faster than reduce(, merge)
  out <- raster::raster(purrr::reduce(purrr::map(x, raster::extent), raster::union), crs = raster::projection(x[[1]]))
  raster::res(out) <- raster::res(x[[1]])
  cells <- unlist(purrr::map(x, ~raster::cellsFromExtent(out, .x)))
  vals <- do.call(rbind, purrr::map(x, ~raster::values(raster::readAll(.x))))
  raster::setValues(raster::brick(out, out, out), vals[order(cells), ])
}


#' Miscellaneous places
#'
#' Visit some nice locales with web tiles.
#'
#' * `cc_macquarie` Macquarie Island
#'
#' @param buffer with in metres to extend around the location
#' @param ... dots, ignored currently
#' @param debug optionally print out files that will be used
#'
#' @return RasterBrick, with RGB
#' @export
#' @name cc_location
#' @examples
#' im <- cc_macquarie()
#' library(raster)
#' plotRGB(im)
cc_location <- function(loc = NULL, buffer = 5000,
                        type = "mapbox.outdoors", ..., debug = FALSE) {
  get_loc(loc = loc, buffer = buffer, type = type, ..., debug = debug)
}
#' @name cc_location
#' @export
cc_macquarie <- function(loc = c(158.93835,-54.49871), buffer = 5000,
                         type = "mapbox.outdoors", ..., debug = FALSE) {
 cc_location(loc, buffer, type = type, ..., debug = debug)
}

#' @name cc_location
#' @export
cc_davis <- function(loc = c(77 + 58/60 + 3/3600,
                              -(68 + 34/60 + 36/3600)),
                     buffer = 5000, type = "mapbox.outdoors", ..., debug = FALSE) {
#  68°34′36″S 77°58′03″E
  cc_location(loc, buffer, type = type, ..., debug = debug)

}
#' @name cc_location
#' @export
cc_mawson <- function(loc = c(62 + 52/60 + 27/3600,
                                  -(67 + 36/60 + 12/3600)), buffer = 5000, type = "mapbox.outdoors", ..., debug = FALSE) {
  # 67°36′12″S 62°52′27″E

  cc_location(loc, buffer, type = type, ..., debug = debug)

}

#' @name cc_location
#' @export
cc_casey <- function(  loc = cbind(110 + 31/60 + 36/3600,
                                    -(66 + 16/60 + 57/3600)), buffer = 5000, type = "mapbox.outdoors", ..., debug = FALSE) {
  #66°16′57″S 110°31′36″E

  cc_location(loc, buffer, type = type, ..., debug = debug)

}
#' @name cc_location
#' @export
cc_heard <- function(loc = c(73 + 30/60 + 30/3600,
                                 -(53 + 0 + 0/3600)), buffer = 5000, type = "mapbox.outdoors",..., debug = FALSE) {
#  53°S 73°30’E.

  cc_location(loc, buffer, type = type, ..., debug = debug)

}
#' @name cc_location
#' @export
cc_kingston <- function(loc = c(-147.70837,
                                    -42.98682), buffer = 5000, type = "mapbox.outdoors", ..., debug = FALSE) {
  cc_location(loc, buffer, type = type, ..., debug = debug)

}
get_loc <- function(loc, buffer, type = "mapbox.outdoors", ..., debug = debug, max_tiles = 4L) {
  if (length(buffer) == 1) buffer <- rep(buffer, 2)
  if (length(loc) > 2) {
    warning("'loc' should be a length-2 vector 'c(lon, lat)' or matrix 'cbind(lon, lat)'")
  }
  if (is.null(dim(loc))) {
    loc <- matrix(loc[1:2], ncol = 2L)
  }

  ## convert loc to mercator meters
  loc <- slippymath::lonlat_to_merc(loc)

  xp <- buffer[1] / 2
  yp <- buffer[2] / 2

  ## xmin, ymin
  ## xmax, ymax
  bb_points <- matrix(c(loc[1,1] - xp, loc[1,2] - yp, loc[1,1] + xp, loc[1,2] + yp), 2, 2, byrow = TRUE)

  if (!slippymath::within_merc_extent(bb_points)){
    warning("The combination of buffer and location extends beyond the tile grid extent. The buffer will be truncated.")
    bb_points <- slippymath::merc_truncate(bb_points)
  }

  ## convert bb_points back to lonlat
  bb_points_lonlat <- slippymath::merc_to_lonlat(bb_points)

  my_bbox <- c(xmin = bb_points_lonlat[1,1], ymin = bb_points_lonlat[1,2],
               xmax = bb_points_lonlat[2,1], ymax = bb_points_lonlat[2,2])

  tile_grid <- slippymath:::bb_to_tg(my_bbox, max_tiles = max_tiles)
  zoom <- tile_grid$zoom

  slippymath::bb_tile_query(my_bbox)

  mapbox_query_string <-
    paste0(sprintf("https://api.mapbox.com/v4/%s/{zoom}/{x}/{y}.jpg90", type),
           "?access_token=",
           Sys.getenv("MAPBOX_API_KEY"))

  files <- down_loader(tile_grid, mapbox_query_string, debug = debug)
  br <- lapply(files, raster::brick)

  for (i in seq_along(br)) {
    br[[i]] <- raster::setExtent(br[[i]],
                         mercator_tile_extent(tile_grid$tiles$x[i], tile_grid$tiles$y[i], zoom = zoom))
  }

  out <- fast_merge(br)
  projection(out) <- "+proj=merc +a=6378137 +b=6378137"
  crop(out, extent(bb_points))
}
