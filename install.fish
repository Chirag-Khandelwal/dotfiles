#!/usr/bin/env fish

set SCRIPT_DIR (realpath (status dirname))

if ! test -f "/bin/zsh"
	echo "Install zsh first"
	exit 1
end
chsh -s /bin/zsh
echo "Using SCRIPT_DIR=$SCRIPT_DIR"
set -Ux EDITOR nvim
mkdir -p ~/.config/fish/functions ~/.config/nvim
ln -sf "$SCRIPT_DIR/dotzshrc" ~/.zshrc
ln -sf "$SCRIPT_DIR/config.fish" ~/.config/fish/config.fish
ln -sf "$SCRIPT_DIR/dotvimrc" ~/.vimrc
ln -sf "$SCRIPT_DIR/dotvimrc" ~/.config/nvim/init.vim
cp $SCRIPT_DIR/fish_functions/* ~/.config/fish/functions/
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
fisher install IlanCosman/tide@v6
fisher install jorgebucaran/spark.fish
fisher install decors/fish-colored-man
tide configure --auto --style=Rainbow --prompt_colors='16 colors' --show_time='24-hour format' --rainbow_prompt_separators=Slanted --powerline_prompt_heads=Sharp --powerline_prompt_tails=Flat --powerline_prompt_style='Two lines, character and frame' --prompt_connection=Dotted --powerline_right_prompt_frame=Yes --prompt_spacing=Sparse --icons='Many icons' --transient=Yes

echo "Make sure to install 'eza' program for 'l' and 't' commands to work."
