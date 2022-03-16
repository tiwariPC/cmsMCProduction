#!/bin/bash
i=1
FRAGMENT=${!i}; i=$((i+1))
NEVENTS=${!i}; i=$((i+1))
NTHREADS=${!i}; i=$((i+1))
OUTPATH=${!i}; i=$((i+1))

date

export X509_USER_PROXY=/afs/cern.ch/user/a/aalbert/x509up_u74570

############################################
# ---------------- wmLHEGS--------------------
############################################
cmssw-cc6 --bind ${PWD} --env WDIR=${PWD},FRAGMENT=${FRAGMENT},NEVENTS=${NEVENTS}<< 'EOF'
cd $WDIR

source /cvmfs/cms.cern.ch/cmsset_default.sh
if [ -r CMSSW_7_1_45/src ] ; then
  echo release CMSSW_7_1_45 already exists
else
  scram p CMSSW CMSSW_7_1_45
fi
cd CMSSW_7_1_45/src
eval `scram runtime -sh`

mkdir -p Configuration/GenProduction/python/
cp ${FRAGMENT}  Configuration/GenProduction/python/

[ -s Configuration/GenProduction/python/$(basename $FRAGMENT) ] || exit $?;

SEED=${RANDOM}
echo "Initial seed in ${SEED}"
scram b
cd ../../

cmsDriver.py Configuration/GenProduction/python/$(basename ${FRAGMENT}) \
            --fileout file:wmLHEGS.root \
            --python_filename wmLHEGS_cfg.py \
            --eventcontent RAWSIM,LHE \
            --customise SLHCUpgradeSimulations/Configuration/postLS1Customs.customisePostLS1,Configuration/DataProcessing/Utils.addMonitoring \
            --datatier GEN-SIM,LHE \
            --conditions MCRUN2_71_V1::All \
            --beamspot Realistic50ns13TeVCollision \
            --customise_commands process.RandomNumberGeneratorService.externalLHEProducer.initialSeed="${SEED}" \
            --step LHE,GEN,SIM \
            --magField 38T_PostLS1 \
            --no_exec \
            --mc \
            -n ${NEVENTS} || exit $? ;

cmsRun wmLHEGS_cfg.py 2&>1 | tee log_wmLHEGS.txt
EOF

if [[ ! -f wmLHEGS.root ]]; then
  echo "ERROR: Cannot find output file wmLHEGS.root"
  exit 1
fi

###########################################
#---------------- DR-----------------
###########################################
source /cvmfs/cms.cern.ch/cmsset_default.sh
if [ -r CMSSW_8_0_21/src ] ; then
  echo release CMSSW_8_0_21 already exists
else
  scram p CMSSW CMSSW_8_0_21
fi
cd CMSSW_8_0_21/src
eval `scram runtime -sh`

scram b
cd ../..

echo "Choose random PU input file."
PULIST=($(cat pulist_summer16.txt))
PUFILE=root://xrootd-cms.infn.it//${PULIST[$RANDOM % ${#PULIST[@]}]}
echo "Chose PU File: ${PUFILE}"


cmsDriver.py  \
--python_filename DRPremix_1_cfg.py \
--eventcontent PREMIXRAW \
--customise Configuration/DataProcessing/Utils.addMonitoring \
--datatier GEN-SIM-RAW \
--fileout file:DRPremix_step1.root  \
--conditions 80X_mcRun2_asymptotic_2016_TrancheIV_v6 \
--step DIGIPREMIX_S2,DATAMIX,L1,DIGI2RAW,HLT:@frozen2016 \
--filein file:wmLHEGS.root \
--pileup_input "$PUFILE" \
--datamix PreMix \
--era Run2_2016 \
--no_exec \
--mc -n ${NEVENTS} || exit $? ;

cmsRun DRPremix_1_cfg.py | tee log_DRPremix_1.txt
rm -v wmLHEGS.root




cmsDriver.py  \
--python_filename DRPremix_2_cfg.py \
--eventcontent AODSIM \
--customise Configuration/DataProcessing/Utils.addMonitoring \
--datatier AODSIM \
--fileout file:AOD.root \
--conditions 80X_mcRun2_asymptotic_2016_TrancheIV_v6 \
--step RAW2DIGI,RECO,EI \
--filein file:DRPremix_step1.root \
--era Run2_2016 \
--runUnscheduled \
--no_exec \
--mc \
-n ${NEVENTS} || exit $? ;

cmsRun DRPremix_2_cfg.py | tee log_DRPremix_2.txt
rm -v DRPremix_step1.root

# ############################################
# # ---------------- MINIAOD-----------------
# ############################################


source /cvmfs/cms.cern.ch/cmsset_default.sh
if [ -r CMSSW_9_4_9/src ] ; then
  echo release CMSSW_9_4_9 already exists
else
  scram p CMSSW CMSSW_9_4_9
fi
cd CMSSW_9_4_9/src
eval `scram runtime -sh`
scram b
cd ../..

cmsDriver.py  \
--filein "file:AOD.root" \
--fileout "file:MiniAOD.root" \
--python_filename MiniAOD_cfg.py \
--eventcontent MINIAODSIM \
--customise Configuration/DataProcessing/Utils.addMonitoring \
--datatier MINIAODSIM \
--conditions 94X_mcRun2_asymptotic_v3 \
--step PAT \
--era Run2_2016,run2_miniAOD_80XLegacy \
--runUnscheduled \
--no_exec \
--mc \
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
cd ../..


cmsDriver.py  \
--filein "file:MiniAOD.root" \
--fileout "file:NanoAOD.root" \
--python_filename NanoAOD_cfg.py \
--eventcontent NANOAODSIM \
--customise Configuration/DataProcessing/Utils.addMonitoring \
--datatier NANOAODSIM \
--conditions 102X_mcRun2_asymptotic_v8 \
--step NANO \
--era Run2_2016,run2_nanoAOD_94X2016 \
--no_exec \
--mc \
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
