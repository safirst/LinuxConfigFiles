set runtimepath+=~/.vim_runtime

source ~/.vim_runtime/vimrcs/basic.vim
source ~/.vim_runtime/vimrcs/filetypes.vim
source ~/.vim_runtime/vimrcs/plugins_config.vim
source ~/.vim_runtime/vimrcs/extended.vim

try
source ~/.vim_runtime/my_configs.vim
catch
endtry

"Following added by Safirst C. Ke
set nu
set cursorline
"set relativenumber

nmap <F2> :s:echo "\(.*\)":echo -e "\\e[32m\1\\e[0m":g<CR>
