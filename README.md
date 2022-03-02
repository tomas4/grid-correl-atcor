README

# grid-correl-atcor
Set of scripts for spatially-variable radiometric normalization of satellite imagery and preparation of Sentinel-2 L2A imagery for use in GIS. The scripts named L2A_*.sh work specifically with Sentinel-2 Level-2A imagery, while the scripts i.grid.correl.atcor.py and r.buff.cloudmask.py can be used on raster data from various sources. Please note: **This code repository is not yet complete. The scripts presented are minimally tested and under development.** 
# The scripts
## i.grid.correl.atcor.py
Provides the core functionality, ie. the radiometric normalization of single band of a satellite image based on reference image. It works within the [GRASS GIS](https:/grass.osgeo.org) 7.x session. When run without arguments, it provides graphical user interface. 
### Installation and initialization
For starting it in GUI mode from the GRASS GIS menu anytime, and also for initial registration of the script within your GRASS GIS, save it somewhere (preferably in some directory you intend for storing also other third-party GRASS scripts) and run it using the GRASS menu *File / Launch Script*. From now on, it is added into that GRASS GIS user search PATH, so you can use its name on the commnad-line, for example to do a loop over all bands of a satellite image imported into GRASS working mapset.
### Basic principle
To achieve its purpose, that is to do the radiometric normalization in spatially-variable manner, it processes the input raster per tiles. In every tile, the correlation coeffitient *r* between the input and reference image is computed for every tile, and if it is better than the minimum and number of valid (ie. pseudo/invariant) pixels is over the minimum, linear regression slope *b* and intercept *a* between reference and input image tiles are computed. The slope and intercept are then interpolated over the whole area of the image. The slope and intercept rasters are then used to compute corrected raster band.
Before the linear regression computation, the image should be masked, so that only the so called pseudo-invariant area pixels are used for the computation. It is user's responsibility to provide the required masks (but the other scripts in the set are here to help with that).
### Synopsis
```
Spatially variable correlation based radiometric normalization.

Usage:
 i.grid.correl.atcor.py [-kv] input=string reference=string output=name
   [masks=string[,string,...]] [gridsize=value] [pixels=value]
   [minr=value] [regression=string] [interpolation=string]
   [lambda_i=value] [--overwrite] [--help] [--verbose] [--quiet] [--ui]

Flags:
  -k   Keep temporary files created during operation.
  -v   Verbose processing information.

Parameters:
          input   Select the band to be corrected.
      reference   Select the reference band.
         output   Select name of output corrected band.
          masks   Select the raster(s) to mask out invalid/changing pixels.
       gridsize   Approx. grid tile size in map units (6000 in m means box 6x6 km).
                  default: 6000
         pixels   Minimal number of valid pixels in tile.
                  default: 100
           minr   Minimal correlation coefficient R to accept.
                  default: 0.85
     regression   Regression method: theil_sen - TheilSen regression, orthogonal - orthogonal regression, least_sq - ordinary least squares.
                  values:theil_sen,orthogonal,least_sq
                  default: theil_sen
  interpolation   Select interpolation method (v.surf.bspline).
                  values:bilinear,bicubic
                  default: bicubic
       lambda_i   Tykhonov regularization parameter (v.surf.bspline)
                  default: 0.1
```
*Older releases of i.grid.correl.atcor.py with some additional documentation can be found at [this Dropbox link](https://www.dropbox.com/s/st5b4p5nkmn8t3k/i.grid.correl.atcor.html?dl=0). (No sign-up required, just close the pop up - but due to changes in Dropbox site you now need to download the html file and open it in browser for it to be rendered if you are not signed in.)*
* * *
## L2A_grass_atcor.sh
This Bash script allows using the script *i.grid.correl.atcor.py* on Sentinel-2 imagery without starting grass manually and process the whole set of bands of L2A Sentinel-2 product in one run. It needs set of input files created using *L2A_vrt-img.sh* script and the reference image already stored in PERMANENT mapset of the location used. Before first use make sure to edit user settings directly within the code.
### Synopsis
```
Usage:  
     L2A_grass_atcor.sh [-a "<atcor parameters>"] <Input_reflective_bands_file.img>
To get help:
     L2A_grass_atcor.sh -h
To get version info:  
     L2A_grass_atcor.sh -v

You can also simply drop the input file to process on the script icon in GUI (no explicit progress indication in the GUI, but you can monitor the log files). The otput file and logs will be generated where the input is stored.
 
DESCRIPTION

L2A_grass_atcor.sh - A wrapper shell script for creating grass temporary mapset 
		in existing location, importing/creating necessary files and
		running i.grid.correl.atcor.py. Supposes input files created with
		L2A_vrt-img and the reference file already stored in PERMANENT 
		mapset of the loaction. This instance invoked as: 
		./L2A_grass_atcor.sh
 
PARAMETERS

-a "<atcor parameters>"
--atcor_parms "<atcor parameters>"
		(optional) Parameters that will be passed to the 
		i.grid.correl.atcor.py script. If used, these replace the whole 
		set of defaults specified within this script (currently: 
		gridsize=4000 minr=0.88 pixels=300 regression=orthogonal). 
		Must be passed as single string enclosed in double quotes. For 
		help run 'i.grid.correl.atcor.py --help' within a GRASS GIS 
		session.

```
* * *
## L2A_vrt-img.sh
Script to take zip file with Sentinel-2 L2A SAFE T33UWR imagery, unzip it and create .vrt and .img files for all resolution image bands for that tile. Also works on already unpacked .SAFE directory. Additionaly, the script creates 20m resolution water and cloud+shade masks and MNDWI, NDMI and NDVI indices.
Files generated by this script are used by *L2A_grass_atcor.sh*, but are also suitable for general use in GIS software, like [QGIS](https://qgis.osgeo.org). For that reason the script creates also some files not used by L2A_grass_atcor.sh, like the 10m and 60m multiband .img files.
Before first use make sure to edit user settings directly within the code.

The multiband .img and .vrt files MSI band order:

10m (file \<TILENAME\>_\<TIMESTAMP\>_10m.img): 02, 03, 04, 08

20m (file \<TILENAME\>_\<TIMESTAMP\>_20m.img): 02, 03, 04, 05, 06, 07, 11, 12, 8A

60m (file \<TILENAME\>_\<TIMESTAMP\>_60m.img): 01, 02, 03, 04, 05, 06, 07, 09, 11, 12, 8A

### Synopsis
```
Usage:                L2A_vrt-img.sh [-o] <Input SAFE format directory or zip archive>
To get help:          L2A_vrt-img.sh -h
To get version info:  L2A_vrt-img.sh -v

Runtime switches:
-o, --overwrite		Overwrite existing files

You can also drop the input file/directory to process on the script icon in GUI. The files will be generated where the input is stored. Existing output files creation is skipped, unless the --overwrite switch is used.
 
L2A_vrt-img.sh - Script to take zip file with Sentinel-2 L2A SAFE T33UWR imagery, unzip it and create .VRT and .IMG files for all resolution image bands for that tile (for other tile than T33UWR - edit the USER VARIABLES in the script). 
          This instance invoked as /home/tom/scripts/L2A_vrt-img.sh
```
***
## r.buff.cloudmask.py
Script to despeckle and buffer cloud mask derived from SCL classification (or other cloud mask containing artifacts in the form of misclassified small few pixel clouds or small holes in them). It works within the [GRASS GIS](https:/grass.osgeo.org) 7.x session. The buffering is there also to mask out areas in close vicinity of detected clouds, where usually are present thin clouds not detected properly and strong neigborhood effects (parasite light reflected off cloud edge etc.). The script is needed by L2A_grass_atcor.sh.
See *i.grid.correl.atcor.py* for installation instructions.

### Synopsis
```
Script to grow zero value (cloudy) regions in a cloud mask band.

Usage:
 r.buff.cloudmask.py input=string [clmask=name] [output=name]
   [buffsize=value] [circlesize=value] [--overwrite] [--help] [--verbose]
   [--quiet] [--ui]

Flags:

Parameters:
       input   Select the mask raster to be buffered.
      clmask   Name of output cleared mask raster. Leave empty and input name with suffix _clean<size> will be used.
      output   Name of output cleared and buffered raster. Leave empty and input name with suffix _buff<size> will be used.
    buffsize   Buffer size in meters.
               default: 300
  circlesize   Size of moving window circular area to filter out few pixel-sized clouds and holes. The value must be an odd number >= 3.
               default: 9
```
***
## L1C_fmask.sh
Simple wrapper script for [FMASK](https://github.com/gersl/fmask) algorithm to create alternative cloud mask to that created by *L2A_vrt_img.sh* from level-2 scene classification of Sentinel-2 imagery. Note that you need FMASK4.x installation (tested with FMASK 4.3) and have to edit the user settings within the *L1C_fmask.sh* file. Also note that you need Level-1C Sentinel-2 image, not Level-2A in this case. In many cases the FMASK 4.3 based cloudmask is higher quality than L2A SCL based cloudmask. To use the resulting cloudmask by the *L2A_grid_atcor.sh* script, make backup of the *L2A_vrt_img.sh* created cloudmask file and rename the FMASK based cloudmask exactly as L2A SCL based cloudmask was named.

### Synopsis
```
Usage:                L1C_fmask.sh [-o] <Input SAFE format directory or zip archive>
To get help:          L1C_fmask.sh -h
To get version info:  L1C_fmask.sh -v

Runtime switches:
-o, --overwrite		Overwrite existing files

You can also drop the input file/directory to process on the script icon in GUI. The files will be generated where the input is stored. Existing output files creation is skipped, unless the --overwrite switch is used.
 
L1C_fmask.sh - Script to take .SAFE folder (or .zip file containing it) with Sentinel-2 L1C imagery and create cloud mask using FMASK. Resulting raster would be named like this: T33UWR_20210306T100029_cloud_fmask_20m.img. T33UWR is granule (tile) name currently set for processing, for other granule edit the user settings within the script. STANDARD NAMING OF FILES DOWNLOADED FROM COPERNICUS OPEN DATA HUB IS SUPPOSED. 
          This instance invoked as /home/tom/scripts/L1C_fmask.sh

```

