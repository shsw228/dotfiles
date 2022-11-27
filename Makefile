all: init link


# Init homebrew 
init:
	.bin/init.sh

# Link dotfiles.
link:
	.bin/link.sh