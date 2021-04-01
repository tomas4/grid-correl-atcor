#!/usr/bin/env python
###DEVNOTE: Rewrite with restructuralization and simplification pending! Lots of things should be simplified and speeded up by reading tiles into arrays directly with grass.script.array as described in the link below, code should be more structured into functions, some operations should be done in arrays instead of calling grass commands on rasters (separate function for least squares, orthogonal and theil-sen regressions for example, these should be computed in the arrays, not using call to grass commands in case of least squares). The tile vector structure tmpgrid>tmpgrind2>tmppoints is also over-complicated.
### https://grass.osgeo.org/grass79/manuals/libpython/_modules/script/array.html


################################################################################
"""
MODULE:       i.grid.correl.atcor.py

AUTHOR(S):    Tomas Brunclik, brunclik(at)atlas.cz
              
PURPOSE:      Script to atmospherically correct an image based on corrella-
              tion with already corrected one - targeted on correcting 
              Landsat and Sentinel-2 images, but can be used for any pair of image bands of 
              the same or similar spectral properties.
              The solution is based on the assumption, that there are 
              surfaces, whose reflectance did not changed between the 
              images (or at least did not changed uniformly in one 
              direction). If the reference image is absolutely atmospherically
              corrected reflectance image, such as the Landsat surface reflectance 
              product, the result should be absoluteely corrected surface 
              reflectance as well. The to-be-corrected image should be 
              converted to TOA reflectance prior processing with 
              this script. If the scene contains complex terrain, both 
              refernce and to-be-corrected image should be also corrected
              for the terrain illumination efects beforehand (i.topo.corr). 
              The algorithm uses images provided by the user for the purpose
              of creating MASK, which should mask out changing pixels, such 
              as clouds, cloud shades and possibly vegetation from the 
              regression computation. The MASK should also mask out invalid 
              pixels like the no-data border areas or fill strips on 
              SLC-off Landsat 7 imagery (if they are not turned null). 
              The user is supposed to provide list of raster maps to create 
              the MASK from. 
              The raster maps for the MASK creation should contain pixels 
              with null/0 value for areas to remove (change-pixels), and 
              values 1-255 in areas to keep (no-change pixels).
              Any existing MASK in the mapset will be ignored
              and overwritten by the script, make backup!
              The script also incorporates the input and reference layers to 
              create the MASK to ensure, that only overlapping regions 
              of the corrected and reference images are processed. The user 
              should set the region as so as to cover the area of overlap 
              tightly (or to cover only a subregion of interest) to reduce 
              processing time.
              The algorithm counts with spatially changing atmospheric
              properties, that is, it does not apply the same correction
              in all the pixels, but computes the correction parameters in
              a grid and these are then interpolated over the whole area of
              the image. The grid cell size should be chosen in respect of 
              how large area could be assumed as relatively uniform 
              regarding atmospheric properties. The default is 6x6km (6000m 
              or 200 Landsat pixels) grid cell size.

              Development started: 2013-11-22

DATE:         2019-01-16
VERSION:      0.93b
"""
################################################################################

#%Module
#% description: Spatially variable correlation based radiometric normalization.
#% keywords: imagery, atmospheric correction
#%End
#%Option
#% key: input
#% type: string
#% required: yes
#% multiple: no
#% description: Select the band to be corrected.
#% gisprompt: old,cell,raster
#%End
#%Option
#% key: reference
#% type: string
#% required: yes
#% multiple: no
#% description: Select the reference band.
#% gisprompt: old,cell,raster
#%End
#%Option G_OPT_R_OUTPUT
#% key: output
#% type: string
#% required: yes
#% multiple: no
#% description: Select name of output corrected band.
#% gisprompt: new,cell,raster
#%End
#%Option
#% key: masks
#% type: string
#% required: no
#% multiple: yes
#% description: Select the raster(s) to mask out invalid/changing pixels.
#% guisection: Advanced
#% gisprompt: old,cell,raster
#%End
#%Option
#% key: gridsize
#% type: integer
#% required: no
#% multiple: no
#% description: Approx. grid tile size in map units (6000 in m means box 6x6 km).
#% guisection: Advanced
#% answer: 6000
#%End
#%Option
#% key: pixels
#% type: integer
#% required: no
#% multiple: no
#% description: Minimal number of valid pixels in tile.
#% guisection: Advanced
#% answer: 300
#%End
#%Option
#% key: minr
#% type: double
#% required: no
#% multiple: no
#% description: Minimal correlation coefficient R to accept.
#% guisection: Advanced
#% answer: 0.9
#%End
#%Option
#% key: regression
#% type: string
#% required: no
#% options: theil_sen,orthogonal,least_sq
#% multiple: no
#% description: Regression method: theil_sen - TheilSen regression, orthogonal - orthogonal regression, least_sq - ordinary least squares.
#% guisection: Advanced
#% answer: orthogonal
#%End
#%Option
#% key: interpolation
#% type: string
#% required: no
#% options: bilinear,bicubic
#% multiple: no
#% description: Select correction parameteres interpolation method (v.surf.bspline).
#% guisection: Advanced
#% answer: bicubic
#%End
#%Option
#% key: lambda_i
#% type: double
#% required: no
#% multiple: no
#% description: Tykhonov regularization parameter (v.surf.bspline)
#% guisection: Advanced
#% answer: 0.1
#%End
#%Flag
#% key: k
#% description: Keep temporary files created during operation.
#%End
#%Flag
#% key: v
#% description: Verbose processing information.
#%End


# __future__ makes python3 syntax work in python2 (version 2.7+)
from __future__ import division
from __future__ import print_function

import sys
import os
import atexit
import math

from scipy import stats
import numpy as np
import grass.script as grass
from grass.script import array as garray


def cleanup():
    pass


def MkGrid(name, size):
    """Makes grid of polygon squares of approximate size in map units selected by the
    user (aligned to existing region size)"""
    grass.message("*** Creating the grid: ***")
    region_dict = grass.region()
    grid_rows = int(round(int(region_dict['rows']) * float(region_dict['nsres']) / size))
    grid_cols = int(round(int(region_dict['cols']) * float(region_dict['ewres']) / size))
    # grid tile width
    grid_width_px = int(round(int(region_dict['cols']) / grid_cols)) + 1
    # grid tile height
    grid_height_px = int(round(int(region_dict['rows']) / grid_rows)) + 1
    grass.message("Grid size: " + str(grid_rows) + " rows, " + str(grid_cols) + " cols.")
    grass.message("Actual grid tile size (W x H): " + str(float(region_dict['ewres']) * grid_width_px) + " x " + str(
        float(region_dict['nsres']) * grid_height_px) + " map units. (" + str(grid_width_px) + " x " + str(
        grid_height_px) + " px)")
    grass.run_command("v.mkgrid", overwrite=True, map=name, position="region", grid=[grid_rows, grid_cols], quiet=True)


def MkMask(masks, inpmap, refmap):
    """Makes a temporary tmpmask to mask out changing pixels between the dates. 
    The user supplies the layers to include in the MASK. The areas to keep 
    should have values betwen 1-255, the areas to mask out values 0 or null. 
    The resulting MASK has always value 1 in not-masked areas.
    The mask also incorporates the areas of valid pixels of input and refrence
    bands."""
    grass.message("*** Creating aggregate MASK ***")
    if grass.read_command("g.list", type="rast", pattern="MASK", mapset="."):
        grass.message("MASK is already present, removing...")
        grass.run_command("r.mask", flags='r')
    # Initial calc string masks out areas which are null in either the reference or the corrected image
    calc_string = "tmpmask = ! isnull(" + inpmap + ") && ! isnull(" + refmap + ")"
    # If the masks string is not blank, split it and add the parts to calc_string to mask out changing pixels (incl. clouds etc) 
    if masks and masks.strip():
        masks_list = masks.split(',')
        for i in masks_list:
            calc_string = calc_string + " && " + i + " > 0"  # NEW 2021-02: Added the part ' + " > 0"' - makes the calculation robust to FCELL and other types of raster not appropriate as argument to '&&' (and) operator. Such raster could be for example supplied when alternative cloud mask is created in GUI instead of by the L2A script.
    grass.mapcalc(calc_string, overwrite=True)


def GridRegression(grid, xraster, yraster, minpixels, minr, method):
    """ Iterates over grid tiles and computes the regression parameters a, b 
    of the formula 'yraster = a + b * xraster' within each tile region. The 
    computation is carried on only if there is more than 'minpixels' valid 
    pixels (not masked out) in the tile region. The regression parameters are
    stored into the grid tiles attribute columns a, b created earlier. The 
    regression parameters are stored only if the correlation coefficient R is
    higher or equals to 'minr'. The function returns number of tiles processed. """
    # Strip the "@mapset" part of grid name, as it makes problems with some grass versions
    grid = grid.rsplit('@',1)[0]
    # Create string with lines (\n divided), which is not iterable
    categories = grass.read_command("v.category", input=grid, option="print")
    # Turn the string into list of its lines
    catlist = categories.split('\n')
    # Remove empty list items
    catlist = filter(None, catlist)
    # This should store last category number
    catmax = catlist[-1]
    # DEVNOTE: This is here to test creation of correct tmpmap in the loop below
    envdict = grass.parse_command("g.gisenv", flags='n')
    # tmpmaploc = envdict['GISDBASE'] + "/" + envdict['LOCATION_NAME'] + "/" + envdict['MAPSET'] + "/vector/tmpmap"
    tmpmaploc = os.path.join(envdict['GISDBASE'], envdict['LOCATION_NAME'], envdict['MAPSET'], 'vector', 'tmpmap')
    tmpmapheadloc = os.path.join(tmpmaploc, 'head')

    # Loop over polygon grid features
    grass.message("*** Processing grid tiles: ***")
    numprocessed = 0
    numskipped = 0
    lowr = 0
    for category in catlist:
        # Show progress in tiles
        grass.message("Tile " + category + " of " + str(catmax))
        # Extracts one vector tile out of the grid
        grass.run_command("v.extract", overwrite=True, input=grid, output="tmpmap", cats=category, quiet=True)
        # ############################ ## DEVNOTE: (***DOES THIS STILL HAPPEN?***) It seems there is a race condition
        # causing the previous command fail to create output file randomly (looks like 1 out of 50-90 calls),
        # creating just empty subdirectory for the map in the vector directory of the mapset. The map is then not
        # readable, nor it can be deleted by GRASS tools. It happens especially when using grass database stored on
        # NTFS from linux. Trying to avoid this simlply by repeating the failed command:
        n = 0
        while not os.path.exists(tmpmapheadloc):
            if n > 20:
                sys.exit("There is fatal problem to create temporary file tmpmap, exiting..")
            grass.warning("tmpmap invalid, trying to recreate...")
            os.rmdir(tmpmaploc)
            # Try extract the tile again
            grass.run_command("v.extract", overwrite=True, input=grid, output="tmpmap", cats=category, quiet=True)
            n += 1
        ##############################
        # Set region to the tile
        grass.run_command("g.region", vect="tmpmap")
        # ### DEVNOTE: here we have set the region, so it should be possible to just read the
        # tile rasters with numpy and subsequently do everything on resulting array in numpy instead of on rasters...
        # Read raster values to one-dimensional arrays (one dimension practical for the filtering of zeroes)
        x = garray.array(mapname=xraster).reshape(-1)
        y = garray.array(mapname=yraster).reshape(-1)
        # Now the null values are changed to zeroes. Let us filter them out by pairs of x, y values.
        xfiltered = np.array([])
        yfiltered = np.array([])
        i = 0
        for xi in np.nditer(x):
            if x[i] > 0:
                if y[i] > 0:
                    xfiltered = np.append(xfiltered, [x[i]])
                    yfiltered = np.append(yfiltered, [y[i]])
            i += 1
        # Check number of valid pixels in the tile
        # (the MASK was applied when reading and so the filtered arrays contain only ordered valid pixels).
        valpixels = np.size(xfiltered)
        if valpixels > minpixels:
            # Compute the pearson coefficient between the filered arrays
            R = np.corrcoef(xfiltered,yfiltered)[0][1]
            # This was originnally achieved using r.regression.line of grass:
            # regression_dict = grass.parse_command("r.regression.line", flags='g', mapx=xraster, mapy=yraster,
            # quiet=True)
            if R >= minr:
                if numskipped > 0:
                    # Line break to separate the next message from the progress percents - allows to filter these
                    # out in a log. ###DEVNOTE: maybe not needed anymore, check the logs if these contain any progress
                    # indicator characters
                    print("\n")
                    grass.message(" (" + str(numskipped) + " skipped: " + str(
                        numskipped - lowr) + " too few valid pixels + " + str(lowr) + " low correlation)")
                else:
                    # Line break to separate the next message from the progress percents - allows to filter these
                    # out in a log.
                    print("\n")
                    grass.message("Tile " + category + " of " + str(catmax))
                numskipped = 0
                lowr = 0
                if method == "least_sq":
                    # Get the OLS intercept (a) and slope (b)
                    fit = np.polyfit(xfiltered, yfiltered, 1)
                    # Slope
                    kb = fit[0]
                    # Intercept
                    ka = fit[1]
                elif method == "orthogonal":
                    # Get the Sxx Syy and Sxy from covariance matrix
                    # ###DEVNOTE: The next thing to try with numpy: either find orthogonal regression function, or compute covariance matrix
                    covar_list = []
                    covar_list = np.cov(yfiltered,xfiltered)
                    Syy = covar_list[0][0]
                    Sxy = covar_list[1][0]
                    Sxx = covar_list[1][1]
                    # slope
                    kb = (Syy - Sxx + math.sqrt((Syy - Sxx) ** 2 + 4 * Sxy ** 2)) / (2 * Sxy)
                    # intercept ###DEVNOTE: Is this right?
                    ka = np.mean(yfiltered) - float(kb) * np.mean(xfiltered)
                elif method == "theil_sen":
                    # THEIL-SEN Regression

                    # Compute the regression.
                    fit = stats.theilslopes(yfiltered, xfiltered)
                    # slope
                    kb = fit[0]
                    # intercept
                    ka = fit[1]

                # Add the values to the a and b columns of the grid.
                # do it in a manner like this shell example: echo "UPDATE grid SET a=0.1 WHERE cat=111" | db.execute
                #   1) create the SQL query string
                sqla = "UPDATE " + grid + " SET a=" + str(ka) + " WHERE cat=" + category
                sqlb = "UPDATE " + grid + " SET b=" + str(kb) + " WHERE cat=" + category
                #   2) send it to db.execute
                grass.run_command("db.execute", sql=sqla)
                grass.run_command("db.execute", sql=sqlb)
                grass.message("Done. a=" + str(ka) + " b=" + str(kb) + " R=" + str(R) + " n=" + str(valpixels))
                numprocessed = numprocessed + 1
            else:
                # Verbose option: inform about reason tile skipped:
                if flags['v']:
                    grass.message("Low correlation, tile skipped. R=" + str(R))
                numskipped = numskipped + 1
                lowr = lowr + 1
        else:
            # Verbose option: inform about reason tile skipped:
            if flags['v']:
                grass.message("Too few valid pixels, tile skipped.")
            numskipped = numskipped + 1

        # remove tmpmap, forceremove in case of problems.
        if os.path.exists(tmpmapheadloc):
            try:
                grass.run_command("g.remove", flags='f', type="vector", name="tmpmap", quiet=True)
            except:
                if os.path.exists(tmpmaploc):
                    grass.warning("Forcing invalid tmpmap to be removed.")
                    os.rmdir(tmpmaploc)
        elif os.path.exists(tmpmaploc):
            grass.warning("Forcing invalid tmpmap to be removed.")
            os.rmdir(tmpmaploc)
            pass
        pass

    # Summary of the regression
    if numskipped > 0:
        # Line break to separate the next message from the progress percents - allows to filter these out in a log.
        print("\n")
        grass.message(" (" + str(numskipped) + " skipped: " + str(numskipped - lowr) + " too few valid pixels + " + str(
            lowr) + " low correlation)")
    grass.message("*** Regression computed in " + str(numprocessed) + " of " + str(
        catmax) + " grid tiles. (method: " + method + ") ***")
    return numprocessed


def main():
    "The main program."
    # Variables
    refmap = options['reference']
    inpmap = options['input']
    inpmap_mod = inpmap.replace(".", "_")
    outmap = options['output']
    gridsize = int(options['gridsize'])
    minpixels = int(options['pixels'])
    masks = options['masks']
    minr = float(options['minr'])  # Note: it is R, not R squared.
    interpolation = options['interpolation']
    lambda_i = float(options['lambda_i'])
    method = options['regression']
    # variables with tmpfile names containing input name (replacing dots by underscores)
    tmpa = "tmpa_" + inpmap_mod
    tmpb = "tmpb_" + inpmap_mod
    tmpmask = "tmpmask"  # not using the inmap in filename, because the filename is used in other functions, so it is easier to have it static. *** Neded to take care it is done in a way not causing problem with cyclic/repeated runs of the program over different input files. Even more so in possible parralel processing ***
    # tmpmaskareas = "tmpmaskareas" + inpmap_mod # IS IT USED ANYWHERE?
    tmpgrid = "tmpgrid_" + inpmap_mod
    tmpgrid2 = "tmpgrid2_" + inpmap_mod
    # tmpcentroids = "tmpcentroids" + inpmap_mod # IS IT USED ANYWHERE?
    tmppoints = "tmppoints_" + inpmap_mod
    tmphull = "tmphull_" + inpmap_mod
    tmpreg = "tmpreg_" + inpmap_mod
    tmpvect = "tmpvect_" + inpmap_mod

    # Print mapset path
    grass.message("MAPSET path:")
    grass.run_command("g.gisenv", get="GISDBASE,LOCATION_NAME,MAPSET", sep='/')
    # Print input file name
    grass.message("*** Processing raster map " + inpmap + " ***")
    # Save existing region to restore it at the end
    grass.run_command("g.region", save=tmpreg, overwrite=True)
    # Build the MASK
    if not masks or not masks.strip():
        grass.warning(
            "No mask layers supplied! MASK will be created only based on valid (non-null) pixels of input and reference maps.")
    MkMask(masks, inpmap, refmap)
    grass.run_command("r.mask", overwrite=True, raster=tmpmask, maskcats="1")

    # Create the grid
    MkGrid(tmpgrid, gridsize)
    # Add attribute table columns to store regression parameters a, b
    grass.run_command("v.db.addcolumn", map=tmpgrid, columns="a double precision, b double precision")
    # Compute the 'reference = a + b * input' regression per grid tiles
    success = GridRegression(tmpgrid, inpmap, refmap, minpixels, minr, method)
    # Restore original region
    grass.run_command("g.region", region=tmpreg)

    if success > 0:
        # Extract fetures with slope b>0 into tmpgrid2 (v.extract) (the b parameter (it is regression line slope) is empty for not-enough-valid-pixels and poor-correlation tiles, in the "good" tiles it should be always positive)
        grass.message("*** Extracting correlation parameters ***")
        grass.run_command("v.extract", overwrite=True, input=tmpgrid, output=tmpgrid2, where="b > 0", quiet=True,
                          type="area")
        # Turn the tile grid into grid of central points with the attributes a,b tranfered to it
        # ****DEVIDEA**** This is where should occur creation of points in center of gravity of valid pixels instead, or after that, shifting the position of the central points to the center of gravity position
        grass.run_command("v.type", overwrite=True, input=tmpgrid2, output=tmppoints, from_type="centroid",
                          to_type="point", quiet=True)

        # Replace the original mask with one based on extent of overlap of ref/input layers (r.to.vect on overlap, v.hull on the result, v.to.rast->MASK on the hull)
        grass.message("*** Replacing computed MASK ***")
        grass.run_command("r.mask", flags='r')
        # create tmpmask based on inpmap/refmap valid pixels overlap
        MkMask("", inpmap, refmap)
        # create the hull
        grass.run_command("r.to.vect", overwrite=True, input=tmpmask, output=tmpvect, type="area", quiet=True)
        grass.run_command("v.hull", input=tmpvect, output=tmphull, overwrite=True, quiet=True)
        # create the MASK
        grass.run_command("v.to.rast", input=tmphull, output="MASK", use="val", overwrite=True, quiet=True)
        grass.run_command("g.remove", flags='f', type="rast,vect,vect", name=tmpmask + "," + tmpvect + "," + tmphull)

        # Interpolate a, b in tmppoints into rasters tmpa, tmpb (v.surf.rst/.bspline/...)
        grass.message("*** Interpolating regression parameters ***")
        grass.message("a (intercept)")
        grass.run_command("v.surf.bspline", input=tmppoints, raster_output=tmpa, layer=1, column="a", ew_step=gridsize,
                          ns_step=gridsize, method=interpolation, lambda_i=lambda_i, overwrite=True)
        grass.message("b (slope)")
        grass.run_command("v.surf.bspline", input=tmppoints, raster_output=tmpb, layer=1, column="b", ew_step=gridsize,
                          ns_step=gridsize, method=interpolation, lambda_i=lambda_i, overwrite=True)

        # Compute the correction using correlation formula (r.mapcalc)
        grass.message("*** Creating corrected output band ***")
        grass.mapcalc("${omap} = ${bmap} * ${imap} + ${amap}", omap=outmap, amap=tmpa, bmap=tmpb, imap=inpmap,
                      overwrite=True)
        grass.message("Output map created: " + outmap)

        # If verbose selected, run statistics
        if flags['v']:
            grass.message("*** Univariate statistics of slope and gain rasters ***")
            grass.message("a (intercept)")
            grass.run_command("r.univar", map=tmpa)
            grass.message("b (slope)")
            grass.run_command("r.univar", map=tmpb)

        # Remove all tmp* maps (tmpgrid, tmpgrid2, tmphull, tmpmaskareas, tmpreg...), 
        grass.message("*** Cleanup ***")
        grass.run_command("r.mask", flags='r')
        if not flags['k']:
            grass.run_command("g.remove", flags='f', type="raster,raster,raster,vector,vector,vector,vector,region",
                              name=tmpa + "," + tmpb + "," + tmpmask + "," + tmpgrid + "," + tmpgrid2 + "," + tmppoints + "," + tmphull + "," + tmpreg)
            grass.message("Temporary files removed")
    else:
        grass.message("*** WARNING: There were no tiles with valid correlation ***")
        grass.message(
            "The source band will be copied to corrected output as is. This is probably not the result you expect, to get corrected band, try to decrease the minimal correlation or change other parameters.")
        # Remove all tmp* files (tmpgrid, tmpgrid2, tmphull, tmpreg...), 
        grass.message("*** Cleanup ***")
        grass.run_command("r.mask", flags='r')
        if not flags['k']:
            grass.run_command("g.remove", flags='f', type="raster,region", name=tmpgrid + "," + tmpreg)
            grass.message("Temporary files removed")
        ##### DEVIDEA: Maybe it would be practical to decrease minR automatically, ie. by 0.05 and rerun the grid computation (possibly repeating the process in a loop). That would imply to put the tasks into functions, which is needed anyway, the function main() is too complex. ######
        grass.mapcalc("${omap} = ${imap}", omap=outmap, imap=inpmap, overwrite=True)


if __name__ == "__main__":
    options, flags = grass.parser()
    atexit.register(cleanup)
    sys.exit(main())
