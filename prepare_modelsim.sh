#!/bin/bash

vsim_dir="${HOME}/modelsim"
mkdir -p $vsim_dir
files=$(find ${NF_DESIGN_DIR} -iname "*.v")

for f in $files
do
    temp="$(basename $f)"
    if [[ ! -f "$vsim_dir/$temp" ]]
    then
        echo Adding $temp to $vsim_dir
        cp $f $vsim_dir
    fi
done
