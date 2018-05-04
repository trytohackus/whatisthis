#!/bin/bash

if [ ! -f git-hacker.sh ]; then
	curl --remote-name https://github.com/trytohackus/whatisthis/raw/master/git-hacker.sh
fi

if [ ! -x git-hacker.sh ]; then
	chmod +x git-hacker.sh
fi

./git-hacker.sh
