" turbux.vim - Turbo Ruby tests with tmux
" Author:      Joshua Davey <http://joshuadavey.com/>
" Version:     1.0

" Install this file to plugin/turbux.vim.
" Relies on the following plugins:
" - tslime.vim or vimux
" - rails.vim

if exists('g:loaded_turbux') || &cp || v:version < 700
  finish
endif
let g:loaded_turbux = 1

" Default Settings {{{1
function! s:turbux_command_setting(name, default_value)
  let name = 'g:turbux_command_'.a:name
  if !exists(name)
    exec ':let '.name.'= "'.a:default_value.'"'
  endif
endfunction

call s:turbux_command_setting("rspec", "rspec")
call s:turbux_command_setting("test_unit", "ruby -Itest")
call s:turbux_command_setting("turnip", "rspec -rturnip")
call s:turbux_command_setting("cucumber", "cucumber")
call s:turbux_command_setting("prefix", "")
" }}}1

" Utility {{{1
function! s:first_readable_file(files) abort
  let files = type(a:files) == type([]) ? copy(a:files) : split(a:files,"\n")
  for file in files
    if filereadable(rails#app().path(file))
      return file
    endif
  endfor
  return ''
endfunction

function! s:add(array, string)
  if type(a:string) == type("") && !empty(a:string)
    call add(a:array, a:string)
  endif
endfunction

" helper methods to find and parse test names in quotes
function! s:gsub(str,pat,rep)
  return substitute(a:str,'\v\C'.a:pat,a:rep,'g')
endfunction

function! s:prefix_for_test(file)
  if a:file =~# '_spec.rb$'
    return g:turbux_command_rspec
  elseif a:file =~# '\(\<test_.*\|_test\)\.rb$'
    return g:turbux_command_test_unit
  elseif a:file =~# '.feature$'
    if a:file =~# '\<spec/'
      return g:turbux_command_turnip
    else
      return g:turbux_command_cucumber
    endif
  endif
  return ''
endfunction

function! s:alternate_for_file(file)
  let related_file = ""
  if exists('g:autoloaded_rails')
    let alt = s:first_readable_file(rails#buffer().related())
    if alt =~# '\(\<test_.*\|\(_test\|_spec\)\)\.rb$'
      let related_file = alt
    endif
  endif
  return related_file
endfunction

function! s:command_for_file(file)
  let executable = []

  call s:add(executable, g:turbux_command_prefix)

  let alternate_file = s:alternate_for_file(a:file)
  if !empty(s:prefix_for_test(a:file))
    call s:add(executable, s:prefix_for_test(a:file))
    call s:add(executable, a:file)
  elseif !empty(alternate_file)
    call s:add(executable, s:prefix_for_test(alternate_file))
    call s:add(executable, alternate_file)
  endif

  " exectuable: [prefix] command file
  return join(executable, " ")
endfunction

function! s:run_command_in_tmux(command)
  " By default, use vimux when it is available
  if !exists("g:turbux_use_vimux")
    let g:turbux_use_vimux = exists("*RunVimTmuxCommand")
  endif

  let executable = "".a:command

  if g:turbux_use_vimux
    return RunVimTmuxCommand(executable)
  else
    return Send_to_Tmux(executable."\n")
  endif
endfunction

function! s:send_test(executable)
  let executable = a:executable
  if empty(executable)
    if exists("g:tmux_last_command") && !empty(g:tmux_last_command)
      let executable = g:tmux_last_command
    else
      let executable = 'echo "Warning: No command has been run yet"'
    endif
  endif
  return s:run_command_in_tmux(executable)
endfunction

function! s:execute_test_by_name()
  let s:line_no = search('^\s*def\s*test_', 'bcnW')
  if s:line_no
    return " -n \"" . split(getline(s:line_no))[1] . "\""
  else
    return ""
  endif
endfunction

function! s:find_test_name_in_quotes()
  let s:line_no = search('^\s*test\s*\([''"]\).*\1', 'bcnW')
  if s:line_no
    let line = getline(s:line_no)
    let string = matchstr(line,'^\s*\w\+\s*\([''"]\)\zs.*\ze\1')
    return 'test_'.s:gsub(string,' +','_')
  else
    return ""
  endif
endfunction
"}}}1

" Public functions {{{1
function! SendTestToTmux(file) abort
  let executable = s:command_for_file(a:file)
  if !empty(executable)
    let g:tmux_last_command = executable
  endif
  return s:send_test(executable)
endfunction

function! SendFocusedTestToTmux(file, line) abort
  let focus = ":".a:line

  if s:prefix_for_test(a:file) == g:turbux_command_test_unit
    let quoted_test_name = s:find_test_name_in_quotes()
    if !empty(quoted_test_name)
      let focus = " -n \"".quoted_test_name."\""
    else
      let focus = s:execute_test_by_name()
    endif
  endif

  if !empty(s:prefix_for_test(a:file))
    let executable = s:command_for_file(a:file).focus
    let g:tmux_last_focused_command = executable
  elseif exists("g:tmux_last_focused_command") && !empty(g:tmux_last_focused_command)
    let executable = g:tmux_last_focused_command
  else
    let executable = ''
  endif
  return s:send_test(executable)
endfunction
" }}}1

" Mappings {{{1
nnoremap <silent> <Plug>SendTestToTmux :<C-U>w \| call SendTestToTmux(expand('%'))<CR>
nnoremap <silent> <Plug>SendFocusedTestToTmux :<C-U>w \| call SendFocusedTestToTmux(expand('%'), line('.'))<CR>

if !exists("g:no_turbux_mappings")
  nmap <leader>t <Plug>SendTestToTmux
  nmap <leader>T <Plug>SendFocusedTestToTmux
endif
"}}}1


" vim:set ft=vim ff=unix ts=4 sw=2 sts=2:
