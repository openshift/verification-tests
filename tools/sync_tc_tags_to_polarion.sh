#!/bin/bash

declare -a ARRAY_IDS
ARRAY_IDS=($(echo `find . -name '*.feature' -exec grep 'case[-_]id.*OCP-' {} \; | rev | cut -d'@' -f1 | rev | sed 's/case_id //g;s/,/ /g' | sort -V`))

echo "Total IDs: ${#ARRAY_IDS[@]}"
echo "The first ID: ${ARRAY_IDS[0]}"
echo "The last ID: ${ARRAY_IDS[-1]}"

function sync() {
	INDEX_L="$1"
	INDEX_R="$2"
	echo "Sync from index ${INDEX_L}, till ${INDEX_R}"
	echo "Sync from ${ARRAY_IDS[$INDEX_L]}, till ${ARRAY_IDS[$INDEX_R-1]}"
	IDs=''
	for (( i=INDEX_L; i<INDEX_R; ++i )) ; do
		IDs+="${ARRAY_IDS[$i]} "
	done
	echo $IDs
	tools/polarshift.rb update-automation --no-wait $IDs
	if [ $? -ne 0 ] ; then
		let INDEX_R=(INDEX_R+INDEX_L+1)/2
	else
		INDEX_L=${INDEX_R}
		INDEX_R=${#ARRAY_IDS[@]}
	fi
	if [ $INDEX_L -ge $INDEX_R ] ; then
		exit
	fi
	# In case the only test case can not found, we are looping this failure one
	# we just try the next test case
	let INC=INDEX_R-INDEX_L
	if [ $INC -eq 1 ] ; then
		tools/polarshift.rb update-automation --no-wait ${ARRAY_IDS[$INDEX_L]}
		let INDEX_L+=1
		let INDEX_R+=1
	fi
	sync $INDEX_L $INDEX_R
}

sync 0 ${#ARRAY_IDS[@]}
