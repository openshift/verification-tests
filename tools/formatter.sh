#!/bin/bash

files=$@

for file in $files ; do
	echo "Formattting file: $file"
	bundle exec cucumber --dry-run --no-color --no-profile --no-snippets --no-source "$file" | sed '1d' | head --lines=-3 > "${file}.bak"
	mv "${file}.bak" "$file"
done
