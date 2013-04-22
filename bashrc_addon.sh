if [[ -z "$NF_ROOT" || "$NF_ROOT" == "" ]]; then
  export NF_ROOT=`pwd`
fi

if [[ -z "$NF_DESIGN_DIR" || "$NF_DESIGN_DIR" == "" ]]; then
  export NF_DESIGN_DIR="${NF_ROOT}/projects/openflow"
fi

if [[ -z "$NF_WORK_DIR" || "$NF_WORK_DIR" == "" ]]; then
  export NF_WORK_DIR="/tmp/${USER}"
fi

ADDPATH="$NF_ROOT/lib/python"
ADDPATH="$ADDPATH:$ADDPATH/NFTest"
if [[ -z "$LD_LIBRARY_PATH" || "$PYTHONPATH" == "" ]]
then
    PYTHONPATH="$ADDPATH"
else
    PYTHONPATH="${ADDPATH}:${PYTHONPATH}"
fi
export PYTHONPATH

ADDPATH="${NF_ROOT}/lib/java/NetFPGAFrontEnd/bin"
if [[ -z "$LD_LIBRARY_PATH" || "$LD_LIBRARY_PATH" == "" ]]
then
    LD_LIBRARY_PATH="$ADDPATH"
else
    LD_LIBRARY_PATH="${ADDPATH}:${LD_LIBRARY_PATH}"
fi
export LD_LIBRARY_PATH

if [ ! -d ${NF_WORK_DIR} ]
then
 mkdir ${NF_WORK_DIR}
fi

if [ ! -d "${HOME}/.qt" ]
then
 mkdir "${HOME}/.qt"
fi

if [ -f "${NF_ROOT}/bin/nf_profile" ]
then
 source "${NF_ROOT}/bin/nf_profile"
fi
