#!/bin/bash

export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

for filePath in $@ ; do
	fileName="$(basename $filePath)"
	temp="${fileName#query_}"
	tag="@${temp%.json}"

	echo "Adding tag: ${tag}"
	tools/case_id_splitter.rb add-tags --tags "${tag}" --ids $(tools/polarshift.rb query-cases -f "${filePath}" | grep -o -E 'OCP-[0-9]+' | tr '\n' ',')
done
