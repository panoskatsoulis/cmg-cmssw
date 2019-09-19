#!/bin/bash

## clean outputs
rm -rf /eos/user/k/kpanos/sostrees/test-workflows
rm -rf mcWorkflow-2016 dataWorkflow-2016
rm -rf mcWorkflow-2017 dataWorkflow-2017
rm -rf mcWorkflow-2018 dataWorkflow-2018

## 2016
echo "Submitting workflow-2016-mc..."
./treeProduction-v2.sh --friends-only --task mcWorkflow-2016 --type mc --year 2016 -in /eos/cms/store/cmst3/group/tthlep/peruzzi/NanoTrees_SOS_230819_v5/2016 -out /eos/user/k/kpanos/sostrees/test-workflows --freq 30m --force-rm > workflow-2016-mc.log 2>&1 &
sleep 5s

echo "Submitting workflow-2016-data..."
./treeProduction-v2.sh --friends-only --task dataWorkflow-2016 --type data --year 2016 -in /eos/cms/store/cmst3/group/tthlep/peruzzi/NanoTrees_SOS_230819_v5/2016 -out /eos/user/k/kpanos/sostrees/test-workflows --freq 30m --force-rm > workflow-2016-data.log 2>&1 &
sleep 5s


## 2017
echo "Submitting workflow-2017-mc..."
./treeProduction-v2.sh --friends-only --task mcWorkflow-2017 --type mc --year 2017 -in /eos/cms/store/cmst3/group/tthlep/peruzzi/NanoTrees_SOS_230819_v5/2017 -out /eos/user/k/kpanos/sostrees/test-workflows --freq 30m --force-rm > workflow-2017-mc.log 2>&1 &
sleep 5s

echo "Submitting workflow-2017-data..."
./treeProduction-v2.sh --friends-only --task dataWorkflow-2017 --type data --year 2017 -in /eos/cms/store/cmst3/group/tthlep/peruzzi/NanoTrees_SOS_230819_v5/2017 -out /eos/user/k/kpanos/sostrees/test-workflows --freq 30m --force-rm > workflow-2017-data.log 2>&1 &
sleep 5s


## 2018
echo "Submitting workflow-2018-mc..."
./treeProduction-v2.sh --friends-only --task mcWorkflow-2018 --type mc --year 2018 -in /eos/cms/store/cmst3/group/tthlep/peruzzi/NanoTrees_SOS_230819_v5/2018 -out /eos/user/k/kpanos/sostrees/test-workflows --freq 30m --force-rm > workflow-2018-mc.log 2>&1 &
sleep 5s

echo "Submitting workflow-2018-data..."
./treeProduction-v2.sh --friends-only --task dataWorkflow-2018 --type data --year 2018 -in /eos/cms/store/cmst3/group/tthlep/peruzzi/NanoTrees_SOS_230819_v5/2018 -out /eos/user/k/kpanos/sostrees/test-workflows --freq 30m --force-rm > workflow-2018-data.log 2>&1 &

echo "Done"
