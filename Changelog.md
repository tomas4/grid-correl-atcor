# Changelog

**DATE: (future release)
VERSION: (target 0.93b)**

**New features:**

*THIS IS CURRENTLY NOT IN SYNC WITH CHANGES ALREADY IMPLEMENTED/INCOMPLETE*
- Internal change of temporary files naming - now the names contain input file name. It allows for example to use loops over bands of an image and keep the temporary files for every band with the -k flag.
- Theil-Sen regression - (EXPERIMENTAL) regression robust to both x- and y- line noise and outliers - should enhance the results in case of imperfect cloud and other change areas masking considerably. Note that it can be computer-intensive, especially has high memory requirements - if it fails because of low memory, reduce tile size. NOTE: In reality this regression does not work as expected so far. Probably usable only in special cases.
- In case there is no tile with good correlation, a warning message is isuued and the source band is copied to output as is. 
- (PLANNED: The center points for regression parameters interpolation should not be in the center of every tile, but in the center of gravity of valid pixels in the tile. It should improve the resulting correction precision.)
- Added -v (verbose) switch.

**Formal improvements:**

- Information messages now contain the input file name and mapset path in the first few lines.
- When processing tiles, the information messages about series of skipped tiles were aggregated into one summary message.
- Small changes in formulation of GUI and messages texts.
- (distribution) Created github project https://github.com/tomas4/grid-correl-atcor, all this and future releases can be found there.

**DATE: 2015-07-23
VERSION: 0.92b**

Download: https://www.dropbox.com/s/g8v2edcdihr4hsu/i.grid.correl.atcor_0.92b.tar.gz?dl=0

**Beta version, compatible with GRASS 7
New features:** 

- OrtInformation messages now contain the input file name and mapset path in the first few lines.
- hogonal regression - new method of regression, made default.

**Fixes:**

- Removed the stddev_mean and combined methods of regression, these were wrong.

**Other changes:**

- The regression parameter now has options least_sq and orthogonal, for "ordinary least squares" nad "orthogonal regression" methods of linear regression.
- .py suffix in the command file name reintroduced, since it is needed on Windows.
- (internal) Some code streamlining (mostly simplification of second stage mask creation, removal of old comments and commented out pieces of code).

**Known isssues:**

- The script does not work for the author in current versions of WinGRASS 7 (tested with 7.0.0 and 7.0.1 RC1, please report if it does for you) due to remaining issues in these Windows versions of GRASS. Works fine on Linux and probaly OSX. This is also true for the previous script version 0.91b.

**DATE: 2015-04-08
VERSION: 0.91b**

Download: https://www.dropbox.com/s/fc3s4b697g3vnhf/i.grid.correl.atcor_0.91b.zip?dl=0

Beta version, first release compatible with GRASS 7
**New features:**

- GRASS 7 compatibility (no longer compatible with GRASS 6.4)
- New method to compute the regression line (based on stdev and mean of input bands)

**New options:**

- regression - chooses method of computing regression parameters (least_squares,mean_stdev,combined).

**Fixes:**

- The WxGUI option to add created map to layer tree now works.
- The resulting corrected band now should cover the whole area of input bands overlap within region bounds (no rounnded corners anymore).
- Other changes:
- minR parameter default relaxed to 0.8.
- Masks parameter moved to optional (advanced) parameters.
- Prints number of tiles used for regression computation.
- (internal) r.sum (removed from GRASS 7) replaced by r.univar for counting valid pixels within tile.
- Removed .py suffix in the command name.

**DATE: released 2015-02-12 as 0.9a, re-released with updated documentation 2015-02-23 as 0.9b**

VERSION: 0.9b, 0.9a
Downloads:
https://www.dropbox.com/s/cqykxrjja0zo9yc/i.grid.correl.atcor_0.9b.zip?dl=0
https://www.dropbox.com/s/2urin9zw7k3clze/i.grid.correl.atcor_0.9a.zip?dl=0

- Internal alpha version, later first public release together with short html documentation with workflow description.
- New features: Interpolation methods bilinear, bicubic (using v.surf.bspline) and their parmeters, IDW interpolation method dropped. Switch (k) to keep temporary files.
- New options: interpolation, lamda_i, k
- Other changes: Advanced parameters section in the GUI, with interpolation parameters. Some default values of parameters altered.

**DATE: 2014-01-20
VERSION: 0.7a**

- Unfinished alpha, internal.
- New features: Raster(s) to mask out invalid/changing pixels. Removal of temporary files.
- New options: masks

**DATE: 2014-01-16
VERSION: 0.6a**

- Unfinished alpha, internal. First version producing an corrected image. IDW interpolation not good.
- New features: Minimal correlation coefficient R to accept, storing regression parameters to vector point file attributes, interpolation of the regession parameters into rasters (using v.surf.idw), computation of the output map.
- New options: minR

**DATE: 2014-01-14
VERSION: 0.5a**

- Unfinished alpha, internal. Incomplete.
- Implemented: Grid size and creation, parsing the tiles, minimal number of valid pixels in grid tile, computation of regression parameters (just reported on command line), storing and restoring region.
- Options: input, reference, output, gridsize, pixels

**Development started: 2013-11-22**
