# PCORnet Bariatric Surgery Aim 3 data processing

Here are the files I think you'll need, and a few you probably won't but may be useful for context.  The process was:

1. Download all site submissions from PCORNet query thingie into a central subdir of site-specific zip files
2. Unzip each site's submission files & rename their content dsets so they can all live in a single dir (aim3_unpack.ps1)
3. Mash all the site-specific files into unified versions w/additional 'site' var (aim1_distributed.sas)
3. Create many many interim files (aim1_distributed.sas) which are subsetted/cleaned/censored/otherwise enhanced versions of the raw pcornet files.
4. Elaborate the interim files in prep for spitting out subsets for the analytic files (aim3_wrangle.sas & aim3_wrangle_macros.sas)
5. Create the final analytic files (make_analytic.sas)