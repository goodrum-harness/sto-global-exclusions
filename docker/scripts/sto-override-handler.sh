#!/usr/local/bin/bash
set -eo pipefail

function help(){
    echo "Arguments:"
    echo "    -w LOCAL_DIRECTORY"
    echo "    -s SCANNER NAME"
    echo "    -o HARNESS_ORGANIZATION_NAME"
    echo "    -p HARNESS_PROJECT_NAME"
    echo "    -P HARNESS_PIPELINE_NAME"
    exit 0
}

WORKDIR="/harness"
SCANNER=""
ORGANIZATION=""
PROJECT=""
PIPELINE=""
while getopts ":w:s:o:p:P:" opt; do
  case ${opt} in
    w ) # process option w
      WORKDIR=$OPTARG
      ;;
    s ) # process option s
        SCANNER=$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]')
      ;;
    o ) # process option w
      ORGANIZATION=$OPTARG
      ;;
    p ) # process option w
      PROJECT=$OPTARG
      ;;
    P ) # process option w
      PIPELINE=$OPTARG
      ;;
    \? ) echo "Usage: cmd [-h] -w LOCAL_DIRECTORY -s SCANNER NAME -o HARNESS_ORGANIZATION_NAME -p HARNESS_PROJECT_NAME -P HARNESS_PIPELINE_NAME"
      ;;
  esac
done

if [ -z "$SCANNER" ] || [ -z "$ORGANIZATION" ]|| [ -z "$PROJECT" ]|| [ -z "$PIPELINE" ]; then
    help
    exit 1
fi

echo "Moving into the Working Directory - $WORKDIR"
cd $WORKDIR

OUTPUT=""

globals_scanner_file=$(yq ${SCANNER}.yml --output-format json | jq -c '.')

override_files=(
    ${SCANNER}.yml
    "overrides/${ORGANIZATION}/${SCANNER}.yml"
    "overrides/${ORGANIZATION}/${PROJECT}/${SCANNER}.yml"
    "overrides/${ORGANIZATION}/${PROJECT}/${PIPELINE}/${SCANNER}.yml"
)
echo ${globals_scanner_file} | jq -rc '.' > deployment_values.json

for this_file in ${override_files[@]}; do
    if [[ ! -f $this_file ]]; then
        echo "Skipping this non-existent file - ${this_file}"
        continue
    fi
    echo "DEBUG: ***** Found this ${this_file} *****"

    echo $(yq ${this_file} --output-format json | jq -rc '.')  > values_tmp.json
    output=$(jq -s 'def deepmerge(a;b):
        reduce b[] as $item (a;
            reduce ($item | keys_unsorted[]) as $key (.;
            $item[$key] as $val | ($val | type) as $type | .[$key] = if ($type == "object") then
                deepmerge({}; [if .[$key] == null then {} else .[$key] end, $val])
            elif ($type == "array") then
                (.[$key] + $val | unique)
            else
                $val
            end)
            );
        deepmerge({}; .)' deployment_values.json values_tmp.json)
    echo $output > deployment_values.json
done
globals_scanner_file=$(cat deployment_values.json | jq -c '.')
rm -rf deployment_values.json values_tmp.json

binaries=$(echo $globals_scanner_file | jq -rc '.binaries // {}')
for key in $(echo $binaries | jq -rc 'keys[]');
do
    OUTPUT="${OUTPUT} --$key $(echo $binaries | jq -rc --arg keyName $key '.[$keyName]')"
done

for i in $(echo ${globals_scanner_file} | jq -c '.exclusions // []' | jq -c '.[]');
do
    OUTPUT="${OUTPUT} --exclude $i";
done

for remove_file in $(echo ${globals_scanner_file} | jq -c '.remove_files // []' | jq -c '.[]');
do
    echo "Recursively removing any files that match - ${remove_file}"
    rm -rf /harness/$(echo $remove_file | tr -d '"');
done

for argument in $(echo ${globals_scanner_file} | jq -c '.standard_args // []' | jq -c '.[]');
do
    fmt_arg=$(echo $argument | tr -d '"')
    OUTPUT="${OUTPUT} ${fmt_arg}";
done

echo $OUTPUT > output_file
