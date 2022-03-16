#!/bin/bash
i=1
FRAGMENT=${!i}; i=$((i+1))
NEVENTS=${!i}; i=$((i+1))
NTHREADS=${!i}; i=$((i+1))
OUTPATH=${!i}; i=$((i+1))

date

export X509_USER_PROXY=/afs/cern.ch/user/a/aalbert/x509up_u74570

############################################
# ---------------- wmLHEGS-----------------
############################################
source /cvmfs/cms.cern.ch/cmsset_default.sh
if [ -r CMSSW_10_2_7/src ] ; then
 echo release CMSSW_10_2_7 already exists
else
scram p CMSSW CMSSW_10_2_7
fi
cd CMSSW_10_2_7/src
eval `scram runtime -sh`

mkdir -p Configuration/GenProduction/python/
cp ${FRAGMENT}  Configuration/GenProduction/python/

[ -s Configuration/GenProduction/python/$(basename $FRAGMENT) ] || exit $?;

SEED=${RANDOM}
echo "Initial seed in ${SEED}"
scram b
cd ../../
cmsDriver.py Configuration/GenProduction/python/$(basename $FRAGMENT) \
--fileout file:wmLHEGS.root \
--mc \
--eventcontent RAWSIM,LHE \
--datatier GEN-SIM,LHE \
--conditions 102X_upgrade2018_realistic_v11 \
--beamspot Realistic25ns13TeVEarly2018Collision \
--step LHE,GEN,SIM \
--nThreads ${NTHREADS} \
--geometry DB:Extended \
--era Run2_2018 \
--python_filename wmLHEGS_cfg.py \
--no_exec \
--customise Configuration/DataProcessing/Utils.addMonitoring \
--customise_commands process.RandomNumberGeneratorService.externalLHEProducer.initialSeed="${SEED}" \
-n ${NEVENTS} || exit $? ;

cmsRun wmLHEGS_cfg.py | tee log_wmLHEGS.txt

###########################################
#---------------- DR-----------------
###########################################
source /cvmfs/cms.cern.ch/cmsset_default.sh
if [ -r CMSSW_10_2_5/src ] ; then
 echo release CMSSW_10_2_5 already exists
else
scram p CMSSW CMSSW_10_2_5
fi
cd CMSSW_10_2_5/src
eval `scram runtime -sh`
scram b
cd ../../

echo "Choose random PU input file."
PULIST=($(cat pulist_autumn18.txt))
PUFILE=root://xrootd-cms.infn.it//${PULIST[$RANDOM % ${#PULIST[@]}]}

echo "Chose PU File: ${PUFILE}"

cmsDriver.py step1 \
--filein file:wmLHEGS.root \
--fileout file:DRPremix_step1.root  \
--pileup_input "$PUFILE" \
--mc \
--eventcontent PREMIXRAW \
--datatier GEN-SIM-RAW \
--conditions 102X_upgrade2018_realistic_v15 \
--step DIGI,DATAMIX,L1,DIGI2RAW,HLT:@relval2018 \
--procModifiers premix_stage2 \
--nThreads ${NTHREADS} \
--geometry DB:Extended \
--datamix PreMix \
--era Run2_2018 \
--python_filename DRPremix_1_cfg.py \
--no_exec \
--customise Configuration/DataProcessing/Utils.addMonitoring \
-n ${NEVENTS} || exit $? ;

cmsRun DRPremix_1_cfg.py | tee log_DRPremix_1.txt
rm -v wmLHEGS.root



cmsDriver.py step2 \
--filein file:DRPremix_step1.root \
--fileout file:AOD.root \
--mc \
--eventcontent AODSIM \
--runUnscheduled \
--datatier AODSIM \
--conditions 102X_upgrade2018_realistic_v15 \
--step RAW2DIGI,L1Reco,RECO,RECOSIM,EI \
--procModifiers premix_stage2 \
--nThreads ${NTHREADS} \
--era Run2_2018 \
--python_filename DRPremix_2_cfg.py \
--no_exec \
--customise Configuration/DataProcessing/Utils.addMonitoring -n ${NEVENTS} || exit $? ;

cmsRun DRPremix_2_cfg.py | tee log_DRPremix_2.txt
rm -v DRPremix_step1.root

# ############################################
# # ---------------- MINIAOD-----------------
# ############################################

cmsDriver.py step1 \
--filein "file:AOD.root" \
--fileout "file:MiniAOD.root" \
--mc \
--eventcontent MINIAODSIM \
--runUnscheduled \
--datatier MINIAODSIM \
--conditions 102X_upgrade2018_realistic_v15 \
--step PAT \
--nThreads ${NTHREADS} \
--geometry DB:Extended \
--era Run2_2018 \
--python_filename MiniAOD_cfg.py \
--no_exec \
--customise Configuration/DataProcessing/Utils.addMonitoring \
-n ${NEVENTS} || exit $? ; 

cmsRun MiniAOD_cfg.py | tee log_miniaod.txt

# ############################################
# # ---------------- NANO-----------------
# ############################################
source /cvmfs/cms.cern.ch/cmsset_default.sh
if [ -r CMSSW_10_2_22/src ] ; then 
 echo release CMSSW_10_2_22 already exists
else
scram p CMSSW CMSSW_10_2_22
fi
cd CMSSW_10_2_22/src
eval `scram runtime -sh`


scram b
cd ../../
cmsDriver.py step1 \
--filein "file:MiniAOD.root" \
--fileout "file:NanoAOD.root" \
--mc \
--eventcontent NANOAODSIM \
--datatier NANOAODSIM \
--conditions 102X_upgrade2018_realistic_v21 \
--step NANO \
--nThreads ${NTHREADS} \
--era Run2_2018,run2_nanoAOD_102Xv1 \
--python_filename NanoAOD_cfg.py \
--no_exec \
--customise Configuration/DataProcessing/Utils.addMonitoring \
-n ${NEVENTS} || exit $? ; 

cmsRun NanoAOD_cfg.py | tee log_nanoaod.txt

### Copy output
OUTTAG=$(echo $JOBFEATURES | sed "s|_[0-9]*$||;s|.*_||")

if [ -z "${OUTTAG}" ]; then
    OUTTAG=$(md5sum *.root | head -1 | awk '{print $1}')
fi

echo "Using output tag: ${OUTTAG}"
mkdir -p ${OUTPATH}
for file in Nano*.root; do 
    mv $file $OUTPATH/$(echo $file | sed "s|.root|_${OUTTAG}.root|g")
done

# rm pulist*
# for file in *.txt; do 
#     mv $file $OUTPATH/$(echo $file | sed "s|.root|_${OUTTAG}.txt|g")
# done

rm -r *root *txt *py

date
