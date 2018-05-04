#!/bin/bash

# WIP ... A little updater

if [ ! -f git-hacker.sh ]; then
	curl --remote-name https://raw.githubusercontent.com/trytohackus/whatisthis/master/git-hacker.sh
fi

bash git-hacker.sh
