#!/bin/bash

files=$@

for file in $files ; do
	echo "Formattting file: $file"
	bundle exec cucumber --dry-run --no-color --no-profile --no-source "$file" | sed '1d' | head --lines=-3 > "${file}.bak"
	mv "${file}.bak" "$file"
done
