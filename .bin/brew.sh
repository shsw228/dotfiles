#!/bin/bash

if [ "$(uname)" != "Darwin" ]; 
then
	echo "This environment is not macOS."
	exit 1
else
brew bundle --global
fi

echo "✅ brew.sh is done."