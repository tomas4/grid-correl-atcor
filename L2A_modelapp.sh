#!/bin/bash

# L2A_modelapp - Noninteractive script. USAGE:
# 1. EDIT VARIABLES IN <parameters file>
# 2. Run the script within directory with the files created with L2A_vrt-img
#
# TIP: Store this as a template, create and edit a copy in the source directory, then run!
# 
#
# Have fun!
# Tomas IV. (Tomas Brunclik, brunclik@atlas.cz)



## Versioning settings
SCRIPT_NAME=$(basename $0)
SCRIPT_VERSION="0.1 (2019-06-10)" 
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
 
## Help (Only if the -h or --help option is the first cmdline parameter, or the number of parameters is not 2.)
if [ "-h" = "${1}" -o "--help" = "${1}" -o $# -ne 1 ]
then
    cat <<!
 
Usage:                $SCRIPT_NAME <parameters file>
To get help:          $SCRIPT_NAME -h
To get version info:  $SCRIPT_NAME -v

$SCRIPT_NAME - NON-INTERACTIVE script to apply a water quality model on Sentinel-2 satellite level-2 data preprocessed with L2A_vrt-img script. EDIT THE <parameters file> FIRST. Output would be created in current directory. 



          This instance invoked as ${0}
 
!
    exit
fi


## Functions
#function name () { list; } [redirection]


## Main program

# Check existence of the input file with parameters
if [ ! -e ./${1} ]
then
    echo "The file ${1} not found. It should be text file with model parameters in current directory, run '$SCRIPT_NAME -h' for more info."
    exit 1
fi

# Check presence of tools needed
command -v gdal_calc.py >/dev/null 2>&1 || { echo >&2 "I require gdal_calc.py but it's not installed. Please install gdal tools (gdal-bin package or similar).  Aborting."; exit 1; }
# command -v basename >/dev/null 2>&1 || { echo >&2 "I require basename but it's not installed. Please install core linux utilities (coreutils package or similar).  Aborting."; exit 1; }
# command -v dirname >/dev/null 2>&1 || { echo >&2 "I require dirname but it's not installed. Please install core linux utilities (coreutils package or similar).  Aborting."; exit 1; }

# Source the parameters
source ./${1}

# Compute it 
# Distinguish between formulas with 5, 4, 3 or 2 operands
if [ "$E" ]; then
    gdal_calc.py -A "$A" --A_band=$ABAND -B "$B" --B_band=$BBAND -C "$C" --C_band=$CBAND -D "$D" --D_band=$DBAND -E "$E" --E_band=$EBAND  --outfile="$OUTPUT" --type='Float32' --calc="$FORMULA"
elif [ "$D" ]; then
	gdal_calc.py -A "$A" --A_band=$ABAND -B "$B" --B_band=$BBAND -C "$C" --C_band=$CBAND -D "$D" --D_band=$DBAND --outfile="$OUTPUT" --type='Float32' --calc="$FORMULA"
elif [ "$C" ]; then
	gdal_calc.py -A "$A" --A_band=$ABAND -B "$B" --B_band=$BBAND -C "$C" --C_band=$CBAND --outfile="$OUTPUT" --type='Float32' --calc="$FORMULA"
elif [ "$B" ]; then
	gdal_calc.py -A "$A" --A_band=$ABAND -B "$B" --B_band=$BBAND --outfile="$OUTPUT" --type='Float32' --calc="$FORMULA"
fi

