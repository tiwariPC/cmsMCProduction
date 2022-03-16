import os
import sys

# ma_list = [10, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500]
ma_list = [10, 50, 100 , 200, 250, 300, 350, 400, 450, 500]

for ma_ in ma_list:
  print('###############################################')
  print('Submitting condor job for ma = '+str(ma_)+' mA = '+str('600'))
  tfile_frag = open('template/bbdm_2hdma.py', 'r')
  tfile_jdl = open('template/bbdm_2hdma_miniAOD_v2_2017.jdl', 'r')
  fout_frag = open('bbdm_2hdma.py', 'w')
  fout_jdl = open('bbdm_2hdma_miniAOD_v2_2017.jdl', 'w')
  for line in tfile_frag:
    line = line.replace('XXXX', str(ma_))
    fout_frag.write(line)
  fout_frag.close()
  for line in tfile_jdl:
    line = line.replace('XXXX', str(ma_))
    fout_jdl.write(line)
  fout_jdl.close()
  os.system('grep "args = cms.vstring" bbdm_2hdma.py')
  os.system('grep "tag =" bbdm_2hdma_miniAOD_v2_2017.jdl')
  os.system('condor_submit bbdm_2hdma_miniAOD_v2_2017.jdl -a njobs=1000 -a nevents=200')
