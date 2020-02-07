# grid-correl-atcor
Set of scripts for spatially-variable radiometric normalization of satellite imagery.
# The scripts
## i.grid.correl.atcor.py
Provides the core functionality, ie. the radiometric normalization of single band of a satellite image based on reference image. It works within the [GRASS GIS](https:/grass.osgeo.org) 7.x session. When run without arguments, it provides graphical user interface. 
### Installation and initialization
For starting it in GUI mode from the GRASS GIS menu anytime, and also for initial registration of the script within your GRASS GIS, save it somewhere (preferably in some directory you intend for storing also other third-party GRASS scripts) and run it using the GRASS menu *File / Launch Script*. From now on, it is added into that GRASS GIS installation PATH, so you can use its name on the commnad-line, for example to do a loop over all bands of a satellite image imported into GRASS working mapset.
### Basic principle ###
To achieve its purpose, that is to do the radiometric normalization in spatially-variable manner, it processes the input raster per tiles. In every tile, the correlation coeffitient *r* between the input and reference image is computed for every tile, and if it is better than the minimum, linear regression slope *a* nad intercept *b* between reference and input image tiles are computed. The slope and intercept are then interpolated over the whole area of the image. Before the linear regression computation, the image should be masked, so that only the so called pseudo-invariant area pixels are used for the computation. It is user's responsibility to provide the required masks (but the other scripts in the set are here to help with that).

