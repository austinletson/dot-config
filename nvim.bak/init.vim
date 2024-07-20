if exists('g:vscode')
    " Integrate with whichkey for spacemacs-style space key
    nnoremap <space> :call VSCodeNotify('whichkey.show')<CR>ode extension
else
    " ordinary Neovim
endif
