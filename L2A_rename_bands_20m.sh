#!/bin/bash

# L2A_rename_bands - Take a VRT or HFA (.img) 20m image file created with L2A_vrt_img and other scripts, or any other gdal supported Sentinel-2 product which has bands in this order:
# 1 "B02" 2 "B03" 3 "B04" 4 "B05" 5 "B06" 6 "B07" 7 "B11" 8 "B12" 9 "B8A"
# and rename the bands to have the names above.
#
# For newest version visit http://
#
# CREDITS:
# 
#
# Have fun!
# Tomas IV. (Tomas Brunclik, brunclik@atlas.cz)

# USER VARIABLES (edit to your needs)
#Tile to process
TILE="T33UWR"
#GNU sed utility command (mostly sed, but may be gsed on Mac and BSD)
SED="sed"


## Versioning settings
SCRIPT_NAME=$(basename $0)
SCRIPT_VERSION="0.3 (2019-06-10)" 
SCRIPT_YEAR="2019"
SCRIPT_AUTHOR="Tomas Brunclik"

## Version info (Only if the -v or --version option is the first cmdline parameter)
if [ "-v" = "${1}" -o "--SCRIPT_VERSION" = "${1}" ]
then
    cat <<!
$SCRIPT_NAME $SCRIPT_VERSION (c) $SCRIPT_AUTHOR $SCRIPT_YEAR
Use under terms of GNU General Public License.
See http://www.gnu.org/licenses/gpl.html or file gpl.txt for details.
!
    exit
fi
 
## Help (Only if the -h or --help option is the first cmdline parameter)
if [ "-h" = "${1}" -o "--help" = "${1}" -o "" = "$1" ]
then
    cat <<!
 
Usage:                $SCRIPT_NAME <product(s) and/or filemask(s)>
To get help:          $SCRIPT_NAME -h
To get version info:  $SCRIPT_NAME -v

$SCRIPT_NAME - Script to rename 20m .VRT and .IMG files created with the other L2A_* scripts.
Band order must be: 
1 "B02" 2 "B03" 3 "B04" 4 "B05" 5 "B06" 6 "B07" 7 "B11" 8 "B12" 9 "B8A"

          This instance invoked as ${0}
 
OPTIONS

!
    exit
fi


## Functions
#function name () { list; } [redirection]


## Main program


# Check presence of tools needed
SetBN=$(command -v set_band_desc.py) || { echo >&2 "WARNING: Python script set_band_desc.py needed to set band names, but it was not found in the PATH. Band names won't be set."; }

# Loop over input files
for file in $(ls "$@"); do
    if [ -f "${file}" ]; then
    	# Rename bands of the inputs (NOT possible with GDAL tools, so the python script. DEVIDEA: sed should do the job to avoid another script dependency)
        echo Processing $file
    	$SetBN "${file}" 1 "B02" 2 "B03" 3 "B04" 4 "B05" 5 "B06" 6 "B07" 7 "B11" 8 "B12" 9 "B8A"
    	echo	
        else
			echo "Warning: Unknown image file: ${file}. Skipping."
			echo "Please run L2A_rename_bands_20m.sh --help."
    	fi
done








