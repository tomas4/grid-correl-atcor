#!/bin/bash

# L2A_fmask - Take directory.SAFE with Sentinel-2 L2A SAFE and create cloud mask using FMASK. Resulting raster would be named like this: T33UWR_20210306T100029_cloud_fmask_20m.img (where T33UWR is granule name and  and in the directory where directory.SAFE resides. STANDARD NAMING OF FILES DOWNLOADED FROM COPERNICUS OPEN DATA HUB IS SUPPOSED.
#
# For newest version visit http://
#
# CREDITS:
# 
#
# Have fun!
# Tomas IV. (Tomas Brunclik, brunclik@atlas.cz)

############# USER VARIABLES (edit to your needs) ####################
#Tile to process
TILE="T33UWR"
#Path to the FMASK binary
FMASK_RUN="/usr/local/GERS/Fmask_4_3/application/Fmask_4_3"
#Path to MATLAB installation (the default for matlab v96 installed in /usr/local).
MR="/usr/local/MATLAB/MATLAB_Runtime/v96"
#GNU sed utility command (mostly sed, but may be gsed on Mac and BSD)
SED="sed"
#Processing directory 
#(FMASK is sensitive to directory structure depth, so it should be relatively short path, like /home/user or /tmp, but with enough free space, about 2GB or few MB more than the size of unpacked L1C SAFE directory. Note that the processing goes on copy of the original data)
PROC_DIR=$HOME
######################################################################

#### DEVNOTE: /home/tom/GISdata/DPZ/Chlorofyl-vzorkovani/2021-03-06_R122_S2B_ns/S2B_MSIL2A_20210306T100029_N0214_R122_T33UWR_20210306T125018.SAFE/GRANULE/L2A_T33UWR_A020883_20210306T100025/


## Versioning settings
SCRIPT_NAME=$(basename $0)
SCRIPT_VERSION="0.1 (2021-03-08)" 
SCRIPT_YEAR="2021"
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
if [ "-h" = "${1}" -o "--help" = "${1}" -o $# -lt 1 -o $# -gt 2 ]
then
    cat <<!
 
Usage:                $SCRIPT_NAME [-o] <Input SAFE format directory or zip archive>
To get help:          $SCRIPT_NAME -h
To get version info:  $SCRIPT_NAME -v

Runtime switches:
-o, --overwrite		Overwrite existing files

You can also drop the input file/directory to process on the script icon in GUI. The files will be generated where the input is stored. Existing output files creation is skipped, unless the --overwrite switch is used.
 
$SCRIPT_NAME - Script to take .SAFE folder (or .zip file containing it) with Sentinel-2 L1C imagery and create cloud mask using FMASK. Resulting raster would be named like this: ${TILE}_20210306T100029_cloud_fmask_20m.img. ${TILE} is granule (tile) name currently set for processing, for other granule edit the user settings within the script. STANDARD NAMING OF FILES DOWNLOADED FROM COPERNICUS OPEN DATA HUB IS SUPPOSED. 
          This instance invoked as ${0}
 
OPTIONS

!
    exit
fi


## Functions
#function name () { list; } [redirection]


## Main program

# Parse commandline parameters
while [[ $# -gt 0 ]]
do
    key="${1}"

    case ${key} in

    -o|--overwrite)
        OverWrite="yes"
        echo "Overwrite mode. Existing files will be silently overwritten."
        shift # past argument
        ;;


    *)  if [ -e "${key}" ]; then
    		TheInput="${key}"
    	else
			echo "ERROR: Unknown argument/file: ${key}."
			echo "Please run $0 --help."
			exit 1
    	fi
        shift # past argument
        ;;

    esac
done

# Check presence of tools needed
command -v unzip >/dev/null 2>&1 || { echo >&2 "I require unzip but it's not installed. Please install unzip. Aborting."; exit 1; }
command -v gdalbuildvrt >/dev/null 2>&1 || { echo >&2 "I require gdalbuildvrt but it's not installed. Please install gdal tools (gdal-bin package or similar). Aborting."; exit 1; }
command -v gdal_translate >/dev/null 2>&1 || { echo >&2 "I require gdal_translate but it's not installed. Please install gdal tools (gdal-bin package or similar).  Aborting."; exit 1; }
command -v basename >/dev/null 2>&1 || { echo >&2 "I require basename but it's not installed. Please install core linux utilities (coreutils package or similar).  Aborting."; exit 1; }
command -v dirname >/dev/null 2>&1 || { echo >&2 "I require dirname but it's not installed. Please install core linux utilities (coreutils package or similar).  Aborting."; exit 1; }
command -v $SED >/dev/null 2>&1 || { echo >&2 "I require gnu sed but it's not installed. Please install gnu sed (package sed, gnu-sed, gsed or similar).  Aborting."; exit 1; }
SetBN=$(command -v set_band_desc.py) || { echo >&2 "WARNING: Python script set_band_desc.py needed to set band names, but it was not found in the PATH. Band names won't be set."; }

# Input names
# name of the .SAFE directory
TheProduct=$(basename "$TheInput")
# path to the directory containing .SAFE directory
TheDir=$(dirname "$TheInput")

#### TODO Check free space in $PROC_DIR
#size=$(du -s $TheInput | cut -f1)
#space=$(df )#### FINISH

if [ -e $TheDir/${BNAME}_Fmask4.img -a -z "$OverWrite" ]; then
	echo "${BName}_cloud_fmask_20m.tif already present, skipping."
else
    # Copy product to $PROC_DIR
    cp -r $TheInput $PROC_DIR || echo "Something went wrong, check the $PROC_DIR has more than $(du -hs $TheInput) free space) and is writable. Also check for partially copied product $TheProduct in $PROC_DIR and eventually delete it."
    cd $PROC_DIR

    # Granule data path (GrnDataPath) = the path to directry, where MTD_TL.xml is residing
    GrnDataPath=$(dirname "${TheProduct}/GRANULE/"[SL]*${TILE}*/MTD_TL.xml)
    # BName = base of the name of granule image data band, i.e. the part of the filename from the start of the name, which does not change for different bands and resolutions. It is used as the base of output file name
    BName="$(basename ${GrnDataPath}/IMG_DATA/R60m/*_B02_60m.jp2)"
    BName="${BName%_B02_60m.jp2}"
    #Create the 20m cloud mask (0-cloud,1-valid pixel,null-no data)
    #Create alternative cloudmask using FMASK algorithm. Also masks out cloud shadow, snow and nodata pixels. It does *not* mask out thin cirrus clouds.
    echo "Creating cloud mask file (20m)"
	cd "$GrnDataPath"
    # Set environment for FMASK and MATLAB
    export XAPPLRESDIR=${MR}/X11/app-defaults
    export LD_LIBRARY_PATH=${MR}/runtime/glnxa64:${MR}/bin/glnxa64:${MR}/sys/os/glnxa64:${MR}/sys/opengl/lib/glnxa64
    $FMASK_RUN
    # Copy result to $TheDir, converting it to HFA .img.
    echo "Creating output ${BNAME}_Fmask4.img"
    gdal_calc.py --format=HFA --co=COMPRESSED=YES --co=NBITS=1 -A FMASK_DATA/L1C_${TILE}_*_Fmask4.tif --outfile=$TheDir/${BNAME}_Fmask4.img --calc="A<2" --overwrite
    # Clean the working copy of data in $PROC_DIR
    cd $PROC_DIR
    echo "All done. The script created a working copy of the input data folder in $(pwd):"
    echo $TheProduct
    echo "To delete it, press Y key as YES (or your language equivalent, if set), any other key to preserve it."
    rm -rI $TheProduct
fi



