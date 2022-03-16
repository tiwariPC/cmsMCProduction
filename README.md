# cmsMCProduction

Scripts to generate CMS simulation samples using the lxplus HTCondor cluster.

General framework

For each sample, you need to provide the following:
  - A GEN fragment.
    - For existing samples, you can go to MCM, navigate to the GEN step request and click on "get fragment" to see the fragment used there.
  - ```cmsdriver``` command
    - Check run_wmLHEGS_DRPremixNanov7_Fall17.sh or go through the McM request, check ```Get setup command``` option.
    - Look at existing scripts for inspiration. Note that this script can often be reused for multiple samples, so you do not always have to make a new script.

The final step is to write a jdl file that describes the condor job you are about to submit. Check out the .jdl file in template directory for inspiration. 
Make sure to change output paths here to write to an area you control. You can submit the job with condor_submit my_jdl_file.jdl.

NB: If you make up a new workflow, it is highly recommended to submit a single small test job to verify that your setup is OK. 
To do this, it is particularly useful to use the condor_submit commandline syntax, which allows you to overwrite config parameters on the fly, e.g.: condor_submit my_jdl_file.jdl -a njobs=1 -a nevents=10

##spcecific to bbDM
Use ```submit_jobs.py``` file to submit jobs for each mass points, provide  ```njobs``` and ```nevents``` accodingly in this file only and use ```python submit_jobs.py``` command to submit the condor jobs
