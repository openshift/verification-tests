SHELL=/usr/bin/env bash -o errexit

.PHONY: check-upgrade-tags

check-upgrade-tags:
	find features/upgrade -name "*.feature" -exec ./check-upgrade-tags {} \;
	@if [ -n "$$(git status --porcelain --untracked-files=no)" ] ; then \
		echo "upgrade-prepare and upgrade-check tags mismatch" ; \
		exit 1 ; \
	fi