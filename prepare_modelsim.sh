#!/bin/bash

vsim_dir="${HOME}/modelsim"
mkdir -p $vsim_dir
files=$(find ${NF_DESIGN_DIR} -iname "*.v")
defines=$(find "${NF_ROOT}/lib/verilog/core/common/src/" -iname "*.v")
all="${defines} ${files}"

for f in $all
do
    temp="$(basename $f)"
    if [[ ! -f "$vsim_dir/$temp" ]]
    then
        echo Adding $temp to $vsim_dir
        cp $f $vsim_dir
    fi
done
