#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(dirname $0)
SPIKE_DTS_DIR=${SCRIPT_DIR}/spike

OUTPUT_PATH="build/ldscript-generator"
DEFAULT_OUTPUT="${OUTPUT_PATH}/metal.default.lds"
RAMRODATA_OUTPUT="${OUTPUT_PATH}/metal.ramrodata.lds"
SCRATCHPAD_OUTPUT="${OUTPUT_PATH}/metal.scratchpad.lds"

wake --init .

wake -v "runLdScriptGenerator (makeLdScriptGeneratorOptions (source \"${SPIKE_DTS_DIR}/design.dts\") (sources \"${SPIKE_DTS_DIR}\" \`core.dts\`) \"${DEFAULT_OUTPUT}\")"
wake -v "runLdScriptGenerator ((makeLdScriptGeneratorOptions (source \"${SPIKE_DTS_DIR}/design.dts\") (sources \"${SPIKE_DTS_DIR}\" \`core.dts\`) \"${RAMRODATA_OUTPUT}\") | setLdScriptGeneratorOptionsRamrodata True)"
wake -v "runLdScriptGenerator ((makeLdScriptGeneratorOptions (source \"${SPIKE_DTS_DIR}/design.dts\") (sources \"${SPIKE_DTS_DIR}\" \`core.dts\`) \"${SCRATCHPAD_OUTPUT}\") | setLdScriptGeneratorOptionsScratchpad True)"

OUTPUTS=($DEFAULT_OUTPUT $RAMRODATA_OUTPUT $SCRATCHPAD_OUTPUT )
for file in ${OUTPUTS[@]}; do
        >&2 echo "$0: Checking for ${file}"
        if [ ! -f ${file} ] ; then
                >&2 echo "$0: ERROR Failed to produce ${file}"
                exit 1
        fi

        >&2 echo "$0: Checking for non-empty ${file}"
        if [ `grep -c 'OUTPUT_ARCH' ${file}` -ne 1 ] ; then
                >&2 echo "$0: ERROR ${file} has bad contents"
                exit 2
        fi
done
