if exists('g:nvim_ionide')
  finish
endif
let g:nvim_ionide = 1

au BufReadCmd dotnet://* lua require('ionide').open_classfile(vim.fn.expand('<amatch>'))
" au BufReadCmd *.class lua require("ionide").open_classfile(vim.fn.expand("<amatch>"))
command! FSWipeDataAndRestart lua require('ionide.workspace_cmds').wipe_data_and_restart()
command! FSShowLogs lua require('ionide.workspace_cmds').show_logs()
