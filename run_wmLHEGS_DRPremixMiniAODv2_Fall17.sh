#!/bin/bash
i=1
FRAGMENT=${!i}; i=$((i+1))
NEVENTS=${!i}; i=$((i+1))
NTHREADS=${!i}; i=$((i+1))
OUTPATH=${!i}; i=$((i+1))

date

export X509_USER_PROXY=/afs/cern.ch/user/p/ptiwari/private/x509up

############################################
# ---------------- GenSim-----------------
############################################
source /cvmfs/cms.cern.ch/cmsset_default.sh
if [ -r CMSSW_9_3_17/src ] ; then
 echo release CMSSW_9_3_17 already exists
else
scram p CMSSW CMSSW_9_3_17
fi
cd CMSSW_9_3_17/src
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
--conditions 93X_mc2017_realistic_v3 \
--beamspot Realistic25ns13TeVEarly2017Collision \
--step LHE,GEN,SIM \
--nThreads ${NTHREADS} \
--geometry DB:Extended \
--era Run2_2017  \
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
if [ -r CMSSW_9_4_7/src ] ; then
 echo release CMSSW_9_4_7 already exists
else
scram p CMSSW CMSSW_9_4_7
fi
cd CMSSW_9_4_7/src
eval `scram runtime -sh`
scram b
cd ../../


echo "Choose random PU input file."
PULIST=($(cat pulist_fall17.txt))
# PUFILE=root://cmsxrootd.fnal.gov//${PULIST[$RANDOM % ${#PULIST[@]}]}
PUFILE=root://xrootd-cms.infn.it//${PULIST[$RANDOM % ${#PULIST[@]}]}
echo "Chose PU File: ${PUFILE}"

cmsDriver.py step1 \
--filein file:wmLHEGS.root \
--fileout file:DRPremix_step1.root  \
--pileup_input "$PUFILE" \
--mc \
--eventcontent PREMIXRAW \
--datatier GEN-SIM-RAW \
--conditions 94X_mc2017_realistic_v11 \
--step DIGIPREMIX_S2,DATAMIX,L1,DIGI2RAW,HLT:2e34v40 \
--nThreads ${NTHREADS} \
--datamix PreMix \
--era Run2_2017  \
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
--conditions 94X_mc2017_realistic_v11 \
--step RAW2DIGI,RECO,RECOSIM,EI \
--nThreads ${NTHREADS} \
--era Run2_2017  \
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
--conditions 94X_mc2017_realistic_v14 \
--step PAT \
--nThreads ${NTHREADS} \
--scenario pp \
--era Run2_2017,run2_miniAOD_94XFall17  \
--filein file:AOD.root \
--fileout file:MiniAOD.root \
--customise Configuration/DataProcessing/Utils.addMonitoring \
--python_filename MiniAOD_cfg.py \
--no_exec \
-n ${NEVENTS};

cmsRun MiniAOD_cfg.py | tee log_miniaod.txt
rm -v AOD.root

### Copy output
OUTTAG=$(echo $JOBFEATURES | sed "s|_[0-9]*$||;s|.*_||")

if [ -z "${OUTTAG}" ]; then
  OUTTAG=$(md5sum *.root | head -1 | awk '{print $1}')
fi

echo "Using output tag: ${OUTTAG}"
mkdir -p ${OUTPATH}
for file in MiniAOD*.root; do 
  mv $file $OUTPATH/$(echo $file | sed "s|.root|_${OUTTAG}.root|g")
done

rm -r *root *txt *py

date
