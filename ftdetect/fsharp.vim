" F#, fsharp
" this file should be kept -> https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#fsautocomplete
autocmd BufNewFile,BufRead *.fs,*.fsi,*.fsx set filetype=fsharp
autocmd BufNewFile,BufRead *.fsproj         set filetype=fsharp_project syntax=xml
