#!/bin/bash

# L2A_grass_atcor - A wrapper shell script for creating grass temporary mapset in  existing location, importing/creating necessary files and running i.grid.correl.atcor.py. Supposes input files created with L2A_vrt-img and the reference files already stored in PERMANENT mapset of the loaction. 
#
# For newest version visit http://
#
# CREDITS:
# 
#
# Have fun!
# Tomas IV. (Tomas Brunclik, brunclik@atlas.cz)

#################### USER VARIABLES (edit to your needs) ####################
#Location full path
THELOC="/home/tom/GISdata/grass/utm33n"
#REFERENCE maps in PERMANENT mapset
REFBASE="s2_20190630_20m"
#REFCLOUDMASK="s2_20190630_20m_cloudmask"
REFCLOUDMASK="s2_20190630_20m_1mask" #because there are no real clouds; original cloudmask has only false positives
REFSCL="s2_20190630_20m_scl"
REFNDMI="s2_20190630_20m_ndmi"
# The GRASS command
GRASSCMD=/usr/bin/grass
#GRASSCMD=grass78
#Directory with python scripts i.grid.correl.atcor.py and r.buff.cloudmask.py
SCRIPTDIR="/home/tom/Dropbox/grass-moje/grass-run"
#i.grid.correl.atcor.py parameters (multiple space separated parameters and/or flags except input/output; leave empty for default values, use the commented example below as a guide for modifications)
#ATCOR_PARMS=""
ATCOR_PARMS="gridsize=4000 minr=0.88 pixels=300 regression=orthogonal"
##NDMI difference mask parameters
# max NDMI difference to pass the mask (to filter out substantial change in vegetation cover and moisture content)
MAXNDMIDIFF="0.1"
# max absolute NDMI to pass the mask (to allow only dry/impervious surfaces which are generally more stable over time). Set it to 1.0 to effectively disable filtering high NDMI
MAXNDMI="0.15"
#Suffixes of INPUT files created with L2A_vrt-img (usually editing not needed)
INPUTSX="_20m.img"
CLOUDSX="_cloud_mask_20m.img"
WATERSX="_water_mask_20m.img"
NDMISX="_ndmi_20m.img"
SCLSX="_SCL_20m.vrt"
OUTPUTSX="_20m_corr3or.img"
#############################################################################


## Versioning settings
SCRIPT_NAME=$(basename $0)
SCRIPT_VERSION="0.2 (2020-01-15)" 
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
if [ "-h" = "${1}" -o "--help" = "${1}" ]
then
    cat <<!
 
Usage:  
     $SCRIPT_NAME [-a "<atcor parameters>"] <Input_reflective_bands_file.img>
To get help:
     $SCRIPT_NAME -h
To get version info:  
     $SCRIPT_NAME -v

You can also simply drop the input file to process on the script icon in GUI (no explicit progress indication in the GUI, but you can monitor the log files). The otput file and logs will be generated where the input is stored.
 
DESCRIPTION

$SCRIPT_NAME - A wrapper shell script for creating grass temporary mapset 
		in existing location, importing/creating necessary files and
		running i.grid.correl.atcor.py. Supposes input files created with
		L2A_vrt-img and the reference file already stored in PERMANENT 
		mapset of the loaction. This instance invoked as: 
		${0}
 
PARAMETERS

-a "<atcor parameters>"
--atcor_parms "<atcor parameters>"
		(optional) Parameters that will be passed to the 
		i.grid.correl.atcor.py script. If used, these replace the whole 
		set of defaults specified within this script (currently: 
		$ATCOR_PARMS). 
		Must be passed as single string enclosed in double quotes. For 
		help run 'i.grid.correl.atcor.py --help' within a GRASS GIS 
		session.
!
    exit
fi

## Functions
#function name () { list; } [redirection]


## Main program

### Parse command-line parameters ############
while [[ "$#" -gt 0 ]]; do case $1 in

  -a|--atcor_parms) 
		ATCOR_PARMS="$2"
		shift
		;;

  *)	
  		if [ -e "$1" ]
  		then
  			INPATHFILE="$1"
  		else
  			echo "ERROR: Can not find input reflective bands file $1 supplied. Make sure it has correct path."; 
  			exit 1
  		fi
  		;;
  		
  esac; shift 
done


### CHECKS ##############################

# get separate dirname and filename
INDNAME="$(dirname $INPATHFILE)"
INFNAME="${INPATHFILE#"${INDNAME}/"}"

# set the base name
L2ABASE="${INFNAME%"$INPUTSX"}"

# Check if output file exists
echo "Checking output file..."
echo "Output directory: $INDNAME"
echo "Output file: ${L2ABASE}${OUTPUTSX}"
if [ -e ${INDNAME}${L2ABASE}${OUTPUTSX} ]
then
  read -t 20 -p "WARNING: Output file already exists and will be OWERWRITTEN. Press N to exit, Y or anything else to continue and overwrite the file in the end." 
  case $REPLY in
	  [yY]*)
	    echo "Going ahead."
	    ;;
	  [nN]*)
	    echo "Exitting."
	    exit 0
	    ;;
	  *) echo "Going ahead."
	     ;;
  esac
else
  echo "OK"
fi
echo

# Check presence of reference maps in PERMANENT mapset
echo "Checking presence of reference maps in PERMANENT mapset..."
echo "Location: ${THELOC}"
for band in 1 2 3 4 5 6 7 8 9 ; do
  $GRASSCMD ${THELOC}/PERMANENT --exec g.findfile element=cell file="${REFBASE}.$band" > /dev/null 2>&1 || { echo "ERROR: map ${REFBASE}.$band not found in PERMANENT mapset. Please check REFERENCE MAPS in USER SETTINGS and in your PERMANENT."; exit 1; }
  echo "${REFBASE}.$band OK"
done
echo

# Check presence of reference auxiliary maps in PERMANENT mapset
echo "Checking presence of reference maps in PERMANENT mapset..."
for map in $REFCLOUDMASK $REFSCL $REFNDMI; do
  $GRASSCMD ${THELOC}/PERMANENT --exec g.findfile element=cell file="$map" > /dev/null 2>&1 || { echo "ERROR: map $map not found in PERMANENT mapset. Please check REFERENCE MAPS in USER SETTINGS and in your PERMANENT."; exit 1; }
  echo "$map OK"
done
echo

# Check presence of all input files
echo "Checking presence of all input files in ${INDNAME}..."
for suffix in $INPUTSX $CLOUDSX $WATERSX $NDMISX $SCLSX; do
  if [ ! -e "${INDNAME}/${L2ABASE}${suffix}" ]
  then
    echo "ERROR: File ${L2ABASE}${suffix} not found. Make sure all the input files were generated correctly by L2A_vrt-img.sh script and check input files suffixes in USER SETTINGS."
    exit 1
  fi
  echo "${L2ABASE}${suffix} OK" 
done
echo

# Check presence of scripts
echo "Checking presence of scripts in ${SCRIPTDIR}..."
[ -e "${SCRIPTDIR}/i.grid.correl.atcor.py" ] || { echo "ERROR: script i.grid.correl.atcor.py not found. Please check SCRIPTDIR path in USER SETTINGS and content of the directory specified."; exit 1; }
echo i.grid.correl.atcor.py OK
[ -e "${SCRIPTDIR}/r.buff.cloudmask.py" ] || { echo "ERROR: script r.buff.cloudmask.py not found. Please check SCRIPTDIR path in USER SETTINGS and content of the directory specified."; exit 1; }
echo r.buff.cloudmask.py OK
echo
#########################################



### PREPARE GRASS MAPSET ################
#create mapset
MAPSETNAME="tmp$$"
echo "Creating mapset $MAPSETNAME in location $THELOC"
$GRASSCMD -c -e ${THELOC}/${MAPSETNAME}

#link/import files 
# New 2021-02: Do not use original ${L2ABASE} within the GRASS mapset, because it can contain unsupported characters. Use "input" and "output" instead. Means to do the replace down to the ## CREATE & EXPORT OUTPUT ## part (inclusive).  
# Also stripping the trailing filetype suffix from the ${suffix}, like this: _cloud_mask_20m.img --> _cloud_mask_20m (i.e. with ${suffix%.*}).
# Also reverted back to full import (r.in.gdal) instead of linking (r.external), since there were problems with ndmi file with nodata values defined as very high number. The parameters of both commands are identical. ###DEVIDEA: This makes it extremely easy to make the link/import method user-selectable.
echo "Importing maps to mapset $MAPSETNAME"
for suffix in $INPUTSX $CLOUDSX $WATERSX $NDMISX $SCLSX; do
  $GRASSCMD ${THELOC}/${MAPSETNAME} --exec r.in.gdal -oe input="${INDNAME}/${L2ABASE}${suffix}" output="input${suffix%.*}" > /dev/null 2>&1 || { echo "ERROR: map ${L2ABASE}$suffix import failed."; exit 1; }
done
echo

#set region and null mask based on imported SCL file
echo "Setting region"
$GRASSCMD ${THELOC}/$MAPSETNAME --exec g.region raster="input${SCLSX%.*}" > /dev/null 2>&1 || { echo "ERROR: Setting region failed."; exit 1; }
echo "Masking no-data areas"
$GRASSCMD ${THELOC}/$MAPSETNAME --exec r.mask -i raster="input${SCLSX%.*}" maskcats=0  > /dev/null 2>&1 2>&1 || echo "WARNING: Creating MASK for bands no-data areas failed." #Missing mask is non-fatal. It only prolongs the atcor processing for Sentinel-2 granules containing substantial nodata areas and makes these areas zero-value.
#########################################



### CREATE CHANGE AND FEATURE MASKS #####
echo "Creating SCL difference mask"
$GRASSCMD ${THELOC}/$MAPSETNAME --exec r.mapcalc expression="scldiffmask = $REFSCL == input${SCLSX%.*}" > /dev/null 2>&1 || { echo "ERROR: Creating SCL difference mask failed."; exit 1; }
echo "Creating NDMI difference mask"
# NEW 2020-02: Using smoothing of both ndmi rasters first to mitigate image noise influence and to get true PIFs as features (areas) as opposed to scattered pixels.
$GRASSCMD ${THELOC}/$MAPSETNAME --exec r.neighbors input="input${NDMISX%.*}" output=ndmi_in_smooth method=average size=3
$GRASSCMD ${THELOC}/$MAPSETNAME --exec r.neighbors input="$REFNDMI" output=ndmi_ref_smooth method=average size=3
# NEW 2020-02: Limit the mask to areas with low moisture content (NDMI<0.15) 
$GRASSCMD ${THELOC}/$MAPSETNAME --exec r.mapcalc expression="ndmidiffmask = ( (ndmi_in_smooth - ndmi_ref_smooth) > -$MAXNDMIDIFF && (ndmi_in_smooth - ndmi_ref_smooth) < $MAXNDMIDIFF && (input${NDMISX%.*} < $MAXNDMI) && ($REFNDMI < $MAXNDMI) )" > /dev/null 2>&1 || { echo "ERROR: Creating NDMI difference mask failed."; exit 1; }
echo "Buffering and cleaning cloud mask"
$GRASSCMD ${THELOC}/$MAPSETNAME --exec python ${SCRIPTDIR}/r.buff.cloudmask.py input="input${CLOUDSX%.*}" buffsize=300 output="input${CLOUDSX%.*}_buff300" > /dev/null 2>&1 || { echo "ERROR: Buffering and cleaning cloud mask failed."; exit 1; }
#########################################



### CREATE & EXPORT OUTPUT ##############
read -p "Starting the i.grid.correl.atcor.py for all bands (press Ctrl-C to abort now)" -t 5
echo
#run i.grid.correl.atcor.py
time for i in 1 2 3 4 5 6 7 8 9
do 
    LOG=${L2ABASE}${OUTPUTSX}.${i}_$(date +%s).log
    # 
    $GRASSCMD ${THELOC}/$MAPSETNAME --exec python ${SCRIPTDIR}/i.grid.correl.atcor.py --overwrite -k $ATCOR_PARMS input=input${INPUTSX%.*}.$i reference=${REFBASE}.$i output=input${OUTPUTSX%.*}.$i masks=${REFCLOUDMASK},input${CLOUDSX%.*},input${CLOUDSX%.*}_buff300,ndmidiffmask,scldiffmask 2>&1 | tee tmplog_$$ || exit 1
    #Tidy up the log
    #The sed filter removes terminal codes for progress percents, grep empty lines with spaces
    cat tmplog_$$ | sed 's/\x1B\[[0-9;]\+[A-Za-z]//g' | grep "\S" > $LOG
    rm tmplog_$$
done 

# create group of images, export
#group
$GRASSCMD ${THELOC}/$MAPSETNAME --exec i.group group=input${OUTPUTSX%.*} input=input${OUTPUTSX%.*}.1,input${OUTPUTSX%.*}.2,input${OUTPUTSX%.*}.3,input${OUTPUTSX%.*}.4,input${OUTPUTSX%.*}.5,input${OUTPUTSX%.*}.6,input${OUTPUTSX%.*}.7,input${OUTPUTSX%.*}.8,input${OUTPUTSX%.*}.9 > /dev/null 2>&1 || { echo "ERROR: Creating image group input${OUTPUTSX%.*} failed."; exit 1; }
#export
$GRASSCMD ${THELOC}/$MAPSETNAME --exec r.out.gdal -f --overwrite input=input${OUTPUTSX%.*} output=${INDNAME}/${L2ABASE}${OUTPUTSX} format=HFA type=Float32 createopt=COMPRESSED=YES
#########################################



### REMOVE MAPSET #######################
# Rather check the $MAPSETNAME variable is not empty before deleting (because if it was, the command would delete the whole location!)
#echo "Removing mapset $MAPSETNAME"
#[ "$MAPSETNAME" ] && rm -rf "${THELOC}/$MAPSETNAME"
echo
echo "The script used temporay GRASS GIS mapset $MAPSETNAME in the location ${THELOC}. It is now safe to delete that mapset (but you may want to inspect it first for the purpose of fine tuning input parameters, quality checking, etc...)."
echo
if [ -e ${INDNAME}/${L2ABASE}${OUTPUTSX} ]
then
    echo "Output file ${INDNAME}/${L2ABASE}${OUTPUTSX} created."
else
    echo "Something went wrog. Check the messages above and the logs."
fi
echo "All done."
#########################################



