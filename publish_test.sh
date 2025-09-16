#!/bin/sh

pesde run build && pesde update && pesde publish -d && rm package.tar.gz &&
printf "\n\033[1mWALLY FILES LIST:\033[0m\n" && wally package --list
