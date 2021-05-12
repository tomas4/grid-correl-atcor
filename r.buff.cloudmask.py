#!/usr/bin/env python
#
##############################################################################
#
# MODULE:       r.buff.cloud.mask.py
#
# AUTHOR(S):    Tomas Brunclik, brunclik(at)atlas.cz
#
# PURPOSE:      Script to clean zero value regions in a mask band, erradicating
#		small scattered clumps of few pixels and then growing (buffering) cloud
#       areas.
#		Specifically developed to tune cloud mask created from SCL for use with 
#		i.grid.correl.atcorr.py script. 
#
# DATE:         Wed Jun 12 10:39:04 2019
#
##############################################################################

#%module
#% description: Script to grow zero value (cloudy) regions in a cloud mask band.
#%end
#%Option
#% key: input
#% type: string
#% required: yes
#% multiple: no
#% description: Select the mask raster to be buffered.
#% gisprompt: old,cell,raster
#%End
#%Option G_OPT_R_OUTPUT
#% key: clmask
#% type: string
#% required: no
#% multiple: no
#% description: Name of output cleared mask raster. Leave empty and input name with suffix _clean<size> will be used.
#% gisprompt: new,cell,raster
#%End
#%Option G_OPT_R_OUTPUT
#% key: output
#% type: string
#% required: no
#% multiple: no
#% description: Name of output cleared and buffered raster. Leave empty and input name with suffix _buff<size> will be used.
#% gisprompt: new,cell,raster
#%End
#%Option
#% key: buffsize
#% type: integer
#% required: no
#% multiple: no
#% description: Buffer size in meters.
#% answer: 300
#%End
#%Option
#% key: circlesize
#% type: integer
#% required: no
#% multiple: no
#% description: Size of moving window circular area to filter out few pixel-sized clouds and holes. The value must be an odd number >= 3.
#% answer: 9
#%End




import sys
import os
import atexit

from grass.script import parser, run_command

def cleanup():
    pass

def main():
    # define output names
    # clmask - cleared mask
    if options['clmask']:
    	clmask = options['clmask']	
    else:
    	clmask = options['input'] + "_clean" + options['circlesize']
    # output - the final cleared and buffered output
    if options['output']:
    	output = options['output']
    else:	
    	output = options['input'] + "_buff" + options['buffsize']

    # Clean small clouds
    run_command("r.neighbors",
                flags = 'c',
                input = options['input'],
                output = clmask,
                size = int(options['circlesize']),
                method = "mode",
                overwrite = True)

    # Invert mask before buffering
    run_command("r.mapcalc",
                expression = "invmask = " + clmask + " == 0",
                region = "current", 
                overwrite = True)

    # Buffer clouds in inverted mask
    run_command("r.buffer",
                flags = 'z',
                input = "invmask",
                output = "buffinvmask",
                distances = int(options['buffsize']),
                units = "meters", 
                overwrite = True)

    # Create output (inverting back the buffer output, ie. setting nulls to 1)
    run_command("r.mapcalc",
    	        expression = output + " = isnull(buffinvmask)",
                region = "current",
                overwrite = True)

    # Cleanup
    run_command("g.remove",
                flags = 'f',
                type = "raster",
                name = "invmask,buffinvmask")


    return 0

if __name__ == "__main__":
    options, flags = parser()
    atexit.register(cleanup)
    sys.exit(main())
