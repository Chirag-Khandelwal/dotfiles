if status is-interactive
	# Commands to run in interactive sessions can go here

	# Git commands
	abbr --add ga 'git add'
	abbr --add gb 'git branch'
	abbr --add gc 'git commit'
	abbr --add gd 'git diff'
	abbr --add gp 'git push'
	abbr --add gs 'git status'

	# Neovim
	abbr --add v 'nvim'
	abbr --add vim 'nvim'

	# Feral programs
	abbr --add n 'feral todo'
	abbr --add c 'feral build-project'

	# Stuff to run
	neofetch
	if type -q feral
		feral todo l
		echo
	end
end
