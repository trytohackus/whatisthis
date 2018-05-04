#!/bin/bash

# WIP ... A little updater

if [ ! -f git-hacker.sh ]; then
	curl --remote-name https://github.com/trytohackus/whatisthis/raw/master/git-hacker.sh
fi

bash git-hacker.sh
