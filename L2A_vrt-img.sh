#!/bin/bash

# L2A_vrt-img - Take zip file or directory.SAFE with Sentinel-2 L2A SAFE T33UWR (for other tile edit the USER VARIABLES below) imagery, unzip it (if needed) and create .VRT and .IMG files for all resolution image bands for that tile. Needs gdal utilities, basename, dirname and unzip installed somewhere in your $PATH. NOTE THAT IF THE INPUT IS ZIP FILE, THE SCRIPT SUPPOSES NO UNPACKED LEVEL-2 *.SAFE DIRECTORY WITHIN THE WORKING DIRECTORY EXISTS (LEVEL-1 IS OK AND WILL BE IGNORED). STANDARD NAMING OF FILES DOWNLOADED FROM COPERNICUS OPEN DATA HUB IS ALSO SUPPOSED.
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
#UTM zone EPSG code for that tile (just the number)
EPSG="32633"
#GNU sed utility command (mostly sed, but may be gsed on Mac and BSD)
SED="sed"
######################################################################



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
if [ "-h" = "${1}" -o "--help" = "${1}" -o $# -lt 1 -o $# -gt 2 ]
then
    cat <<!
 
Usage:                $SCRIPT_NAME [-o] <Input SAFE format directory or zip archive>
To get help:          $SCRIPT_NAME -h
To get version info:  $SCRIPT_NAME -v

Runtime switches:
-o, --overwrite		Overwrite existing files

You can also drop the input file/directory to process on the script icon in GUI. The files will be generated where the input is stored. Existing output files creation is skipped, unless the --overwrite switch is used.
 
$SCRIPT_NAME - Script to take zip file with Sentinel-2 L2A SAFE $TILE imagery, unzip it and create .VRT and .IMG files for all resolution image bands for that tile (for other tile than $TILE - edit the USER VARIABLES in the script). 
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
			echo "Please run L2A_vrt-img.sh --help."
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
TheProduct=$(basename "$TheInput")
TheDir=$(dirname "$TheInput")

cd "$TheDir"

# If the input product is ZIP file, extract it.
if [ -d "$TheProduct" ]
then
    ImgDataPath="${TheProduct}/GRANULE/[SL]*${TILE}*/IMG_DATA"
else
    # Unzip the product
    echo Extracting "$TheProduct"
    unzip -q "$TheProduct"
    # Base of the outut name
    ImgDataPath="S2*L2A*.SAFE/GRANULE/[SL]*${TILE}*/IMG_DATA"
fi

BName="$(basename ${ImgDataPath}/R60m/*_B02_60m.jp2)"
BName="${BName%_B02_60m.jp2}"


#Create the outputs
for res in 60 20 10; do
  if [ -e ${BName}_${res}m.vrt -a -z "$OverWrite"  ]; then
  	  echo "${BName}_${res}m.vrt already present, skipping."
  else
	  echo "Generating ${BName}_${res}m.vrt"
	  gdalbuildvrt -separate -a_srs epsg:$EPSG -srcnodata 0 -vrtnodata 0 "${BName}_${res}m.vrt" ${ImgDataPath}/R${res}m/*_B??_${res}m.jp2
	  #Convert the virtual raster to Float32 to support GDAL floating point arithmetics (MNDWI etc. later on in this file).
	  echo "Setting ${BName}_${res}m.vrt to Float32 type"
	  $SED -i 's/UInt16/Float32/gI'  "${BName}_${res}m.vrt"
  fi

  if [ -e ${BName}_${res}m.img -a -z "$OverWrite" ]; then
  	  echo "${BName}_${res}m.img already present, skipping."
  else
	  echo "Generating ${BName}_${res}m.img"
	  # Here we revert back to integer (-ot UInt16), since float would mean twice the disk space and the input in is integer in reality anyway. Use the .vrt, where float computing needs it.
	  gdal_translate -of HFA -ot UInt16 -co COMPRESSED=YES -a_nodata 0 "${BName}_${res}m.vrt" "${BName}_${res}m.img"
  fi
done


# Rename bands of the outputs (NOT possible with GDAL tools, so the python script. DEVIDEA: sed should do the job to avoid another script dependency)
if [ -n "$SetBN" ]
then
	echo "Setting band names"
	# 10m
	$SetBN "${BName}_10m.vrt" 1 "B02" 2 "B03" 3 "B04" 4 "B08" 
	$SetBN "${BName}_10m.img" 1 "B02" 2 "B03" 3 "B04" 4 "B08" 
	# 20m
	$SetBN "${BName}_20m.vrt" 1 "B02" 2 "B03" 3 "B04" 4 "B05" 5 "B06" 6 "B07" 7 "B11" 8 "B12" 9 "B8A"
	$SetBN "${BName}_20m.img" 1 "B02" 2 "B03" 3 "B04" 4 "B05" 5 "B06" 6 "B07" 7 "B11" 8 "B12" 9 "B8A"
	# 60m
	$SetBN "${BName}_60m.vrt" 1 "B01" 2 "B02" 3 "B03" 4 "B04" 5 "B05" 6 "B06" 7 "B07" 8 "B09" 9 "B11" 10 "B12" 11 "B8A"
	$SetBN "${BName}_60m.img" 1 "B01" 2 "B02" 3 "B03" 4 "B04" 5 "B05" 6 "B06" 7 "B07" 8 "B09" 9 "B11" 10 "B12" 11 "B8A"
fi

#Create (possibly temporary) null mask (1-valid data, nodata-invalid data)
#The bands juste created have value 0 set to nodata, everything else >=1. This mask would be usable just by multiplying the formula with it.
echo "Creating null-mask file"
gdal_calc.py -A "${BName}_20m.img" --A_band=1 --outfile=nullmask.img --calc="(A>0)" --type=Byte --format=HFA --creation-option="NBITS=1" --creation-option="COMPRESSED=YES" --NoDataValue=0

#Create 20m mndwi
if [ -e ${BName}_mndwi_20m.img -a -z "$OverWrite" ]; then
	echo "${BName}_mndwi_20m.img already present, skipping."
else
	echo "Creating MNDWI file (20m)"
	gdal_calc.py -A "${BName}_20m.vrt" --A_band=2 -B "${BName}_20m.vrt" --B_band=7 --outfile="${BName}_mndwi_20m.img" --calc="(A-B)/(A+B)" --type=Float32 --format=HFA --creation-option="COMPRESSED=YES"
fi

#Create 20m SCL VRT
if [ -e ${BName}_SCL_20m.vrt -a -z "$OverWrite" ]; then
	echo "${BName}_SCL_20m.vrt already present, skipping."
else
	echo "Creating SCL virtual raster (20m)"
	# Current pathname of input scl 
	inputscl1="${ImgDataPath}/R20m/*_SCL_20m.jp2"
	# Older pathname of input scl
	inputscl2="${ImgDataPath}/*_SCL*20m.jp2"

	if [ -e $inputscl1 ]
	then
		gdalbuildvrt -separate -a_srs epsg:$EPSG "${BName}_SCL_20m.vrt" $inputscl1
	elif [ -e $inputscl2 ]
	then
		gdalbuildvrt -separate -a_srs epsg:$EPSG "${BName}_SCL_20m.vrt" $inputscl2
	else
		echo "WARNING: Input SCL files: \n$inputscl1 \n$inputscl2 \nnot found. \nCan't create SCL .vrt NOR cloudmask."
	fi
fi

#Create 20m INTERIM cloud mask (0-cloud,1-valid pixel,null-no data)
#Automatically created cloud mask based solely on SCL file would not be always sufficiently precise, in such case make it by hand in GIS. In some cases it is better mask out also low-probability clouds, in some cases if high clouds are thin and not stratified, it would be better not mask them out and let i.grid.correl.atcor.py to take care of removinhg their effect. It is also good idea to use buffer on ares to mask out and remove too small maked out features. This all then affects water mask below and what areas are included in the model. Also masks out snow,nodata,saturated and defect pixels.
if [ -e ${BName}_SCL_20m.vrt ]; then
	if [ -e ${BName}_cloud_mask_20m.tif -a -z "$OverWrite" ]; then
		echo "${BName}_cloud_mask_20m.tif already present, skipping."
	else
		echo "Creating cloud mask file (20m)"
		# DEVNOTE: nullmask is needed here to produce nodata area
	gdal_calc.py -A "${BName}_SCL_20m.vrt" -B "nullmask.img" --outfile="${BName}_cloud_mask_20m.img" --calc="((A==2)+(A<8)*(A>3))*(B>0)" --type=Byte --format=HFA --creation-option="NBITS=2" --creation-option="COMPRESSED=YES" --NoDataValue=3
	fi
fi

#Create 20m INTERIM water mask (1-water,0-anything else)
#This water mask would contain some non-water areas marked as water, especially in cloudy and cloud shade areas, if the detection of clouds and cloud shade is not perfect in the SCL file. Or it could mask out some water areas completely, if the SCL marks some water areas as cloud shade. In these cases, manually fine-tuned cloud mask and resulting water mask is necessary.
if [ -e ${BName}_cloud_mask_20m.img ]
then
	if [ -e ${BName}_water_mask_20m.img -a -z "$OverWrite" ]; then
		echo "${BName}_water_mask_20m.img already present, skipping."
	else
		echo "Creating water mask (20m)"
		gdal_calc.py -A "${BName}_mndwi_20m.img" -B "${BName}_20m.vrt" --B_band=7 -C "${BName}_cloud_mask_20m.img" --outfile="${BName}_water_mask_20m.img" --calc="(A>0.1)*(B<700)*(C>0)" --type=Byte --format=HFA --creation-option="NBITS=2" --creation-option="COMPRESSED=YES" --NoDataValue=3
	fi
else
	if [ -e ${BName}_water_mask_20m.img -a -z "$OverWrite" ]; then
		echo "${BName}_water_mask_20m.img already present, skipping."
	else
		echo "Creating water mask (20m) (Cloud mask ${BName}_cloud_mask_20m.img not found)"
		gdal_calc.py -A "${BName}_mndwi_20m.img" -B "${BName}_20m.vrt" --B_band=7 --outfile="${BName}_water_mask_20m.img" --calc="(A>0.1)*(B<700)" --type=Byte --format=HFA --creation-option="NBITS=2" --creation-option="COMPRESSED=YES" --NoDataValue=3
	fi
fi
#create float32 zero-turned-to-nodata virtual raster to support GDAl floating point computing of models
if [ -e ${BName}_water_mask_20m_float.vrt -a -z "$OverWrite" ]; then
	echo "${BName}_water_mask_20m_float.vrt already present, skipping."
else
	echo "Creating supplementary float32 virtual raster of water mask."
	gdalbuildvrt  -a_srs epsg:$EPSG -srcnodata 0 "${BName}_water_mask_20m_float.vrt" "${BName}_water_mask_20m.img"
	$SED -i 's/Byte/Float32/gI' "${BName}_water_mask_20m_float.vrt"
fi

#Create 20m ndmi
if [ -e ${BName}_ndmi_20m.img -a -z "$OverWrite" ]; then
	echo "${BName}_ndmi_20m.img already present, skipping."
else
	echo "Creating NDMI file (20m)"
	gdal_calc.py -A "${BName}_20m.vrt" --A_band=7 -B "${BName}_20m.vrt" --B_band=9 --outfile="${BName}_ndmi_20m.img" --calc="(B-A)/(B+A)" --type=Float32 --format=HFA --creation-option="COMPRESSED=YES"
fi

#Create 20m ndvi
# Using max(band value,1) to avoid problem of possible negative and zero reflectance values occuring over dark areas
if [ -e ${BName}_ndvi_20m.img -a -z "$OverWrite" ]; then
	echo "${BName}_ndvi_20m.img already present, skipping."
else
	echo "Creating ndvi file (20m)"
	gdal_calc.py -A "${BName}_20m.vrt" --A_band=2 -B "${BName}_20m.vrt" --B_band=9 --outfile="${BName}_ndvi_20m.img" --calc="(maximum(B,1)-maximum(A,1))/(maximum(B,1)+maximum(A,1))" --type=Float32 --format=HFA --creation-option="COMPRESSED=YES"
fi


