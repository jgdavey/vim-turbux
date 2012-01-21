" turbux.vim - Turbo Ruby tests with tmux
" Author:      Joshua Davey <http://joshuadavey.com/>
" Version:     1.0

" Install this file to plugin/turbux.vim.
" Relies on the following plugins:
" - tslime.vim
" - rails.vim

if exists('g:loaded_turbux') || &cp || v:version < 700
  finish
endif
let g:loaded_turbux = 1

function! s:first_readable_file(files) abort
  let files = type(a:files) == type([]) ? copy(a:files) : split(a:files,"\n")
  for file in files
    if filereadable(rails#app().path(file))
      return file
    endif
  endfor
  return ''
endfunction

function! s:prefix_for_test(file)
  if a:file =~# '_spec.rb$'
    return "rspec "
  elseif a:file =~# '_test.rb$'
    return "ruby -Itest "
  elseif a:file =~# '.feature$'
    if a:file =~# '\<spec/'
      return "rspec -rturnip "
    else
      return "cucumber "
    endif
  endif
  return ''
endfunction

function! s:alternate_for_file(file)
  let related_file = ""
  if exists('g:autoloaded_rails')
    let alt = s:first_readable_file(rails#buffer().related())
    if alt =~# '.rb$'
      let related_file = alt
    endif
  endif
  return related_file
endfunction

function! s:command_for_file(file)
  let executable=""
  let alternate_file = s:alternate_for_file(a:file)
  if s:prefix_for_test(a:file) != ''
    let executable = s:prefix_for_test(a:file) . a:file
  elseif alternate_file != ''
    let executable = s:prefix_for_test(alternate_file) . alternate_file
  endif
  return executable
endfunction

function! s:send_test(executable)
  let executable = a:executable
  if executable == ''
    if exists("g:tmux_last_command") && g:tmux_last_command != ''
      let executable = g:tmux_last_command
    else
      let executable = 'echo "Warning: No command has been run yet"'
    endif
  endif
  return Send_to_Tmux("".executable."\n")
endfunction

" Public functions
function! SendTestToTmux(file) abort
  let executable = s:command_for_file(a:file)
  if executable != ''
    let g:tmux_last_command = executable
  endif
  return s:send_test(executable)
endfunction

function! SendFocusedTestToTmux(file, line) abort
  let focus = ":".a:line

  if s:prefix_for_test(a:file) != ''
    let executable = s:command_for_file(a:file).focus
    let g:tmux_last_focused_command = executable
  elseif exists("g:tmux_last_focused_command") && g:tmux_last_focused_command != ''
    let executable = g:tmux_last_focused_command
  else
    let executable = ''
  endif

  return s:send_test(executable)
endfunction

" Mappings
nnoremap <silent> <Plug>SendTestToTmux :<C-U>w \| call SendTestToTmux(expand('%'))<CR>
nnoremap <silent> <Plug>SendFocusedTestToTmux :<C-U>w \| call SendFocusedTestToTmux(expand('%'), line('.'))<CR>

if !exists("g:no_turbux_mappings")
  nmap <leader>t <Plug>SendTestToTmux
  nmap <leader>T <Plug>SendFocusedTestToTmux
endif

" vim:set ft=vim ff=unix ts=4 sw=2 sts=2:
