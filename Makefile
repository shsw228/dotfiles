all: init link brew

# Init homebrew 
init:
	.bin/init.sh
# brew install
brew:
	.bin/brew.sh
# Link dotfiles.
link:
	.bin/link.sh