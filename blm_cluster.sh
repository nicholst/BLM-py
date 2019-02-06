#!/bin/bash

# include parse_yaml function
. lib/parse_yaml.sh

# Work out if we have been given multiple analyses configurations
# Else just assume blm_config is the correct configuration
cfgno=1
if [ "$1" == "" ] ; then
  cfgs=$(realpath "blm_config.yml")
else
  cfgs=$@
fi

for cfg in $cfgs
do

  cfg=$(realpath $cfg)
  # read yaml file to get output directory
  eval $(parse_yaml $cfg "config_")
  mkdir -p $config_outdir

  # This file is used to record number of batches
  if [ -f $config_outdir/nb.txt ] ; then
      rm $config_outdir/nb.txt 
  fi
  touch $config_outdir/nb.txt 

  # Make a copy of the inputs file, if the user touches the cfg file this will not mess
  # with anything now.
  inputs=$config_outdir/inputs.yml
  cp cfg inputs

  jID=`fsl_sub -l log/ -N setup_cfg$cfgno bash ./lib/cluster_blm_setup.sh $inputs`
  setupID=`echo $jID | awk 'match($0,/[0-9]+/){print substr($0, RSTART, RLENGTH)}'`

  echo "Setting up distributed analysis..."
  echo "(For configuration: $cfg)"
  cfgno=$(($cfgno + 1))
done

# Now we know how many jobs to submit, submit them all
cfgno=1
for cfg in $cfgs
do

  cfg=$(realpath $cfg)
  # read yaml file to get output directory
  eval $(parse_yaml $cfg "config_")

  # Locate copy of inputs
  inputs=$config_outdir/inputs.yml

  # This loop waits for the setup job to finish before
  # deciding how many batches to run. It also checks to 
  # see if the setup job has errored.
  nb=0
  i=0
  while [ $nb -lt 1 ]
  do
    sleep 1
    if [ -s $config_outdir/nb.txt ]; then
      typeset -i nb=$(cat $config_outdir/nb.txt)
    fi
    i=$(($i + 1))

    if [ $i -gt 30 ]; then
      errorlog="log/setup_cfg$cfgno.e$setupID"
      if [ -s $errorlog ]; then
        echo "Setup has errored"
        exit
      fi
    fi

    if [ $i -gt 500 ]; then
      echo "Something seems to be taking a while. Please check for errors."
    fi
  done

  echo "Submitting analysis jobs..."
  echo "(For configuration: $cfg)"

  i=1
  while [ "$i" -le "$nb" ]; do
    jID=`fsl_sub -j $setupID -l log/ -N batch_cfg${cfgno}_${i} bash ./lib/cluster_blm_batch.sh $i $inputs`
    batchIDs="`echo $jID | awk 'match($0,/[0-9]+/){print substr($0, RSTART, RLENGTH)}'`,$batchIDs"

    i=$(($i + 1))
  done

  #qsub -o log$1/ -e log$1/ -N results -V -hold_jid "batch*" lib/cluster_blm_concat.sh
  jID=`fsl_sub -j $batchIDs -l log/ -N results_cfg$cfgno bash ./lib/cluster_blm_concat.sh $inputs`
  resultsID=`echo $jID | awk 'match($0,/[0-9]+/){print substr($0, RSTART, RLENGTH)}'`
  batchIDs=''

  echo "Submitting results job..."
  echo "(For configuration: $cfg)"
  cfgno=$(($cfgno + 1))
done

echo "Please use qstat to monitor progress."
