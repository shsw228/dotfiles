#!/bin/bash

if [ "$(uname)" != "Darwin" ] ; then
	echo "This environment is not macOS."
	exit 1
 else
 
# Fetch gitignore
 mkdir -p ~/.config/git
 curl -fsSL 'https://raw.githubusercontent.com/github/gitignore/master/Global/macOS.gitignore' > ~/.config/git/ignore
fi

# Install brew
if ! (type brew > /dev/null 2>&1); then
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > /dev/null
fi

echo "✅ init.sh is done."
