nnoremap <silent> <Plug>(iron-send-motion)
      \ :<c-u>let b:iron_cursor_pos = winsaveview()<CR>:<c-u>set opfunc=IronSendMotion<CR>g@
vnoremap <silent> <Plug>(iron-send-motion)
      \ :<c-u>let b:iron_cursor_pos = winsaveview()<CR>:<c-u>call IronSendMotion('visual')<CR>
"Call previous command again
nnoremap <silent> <Plug>(iron-repeat-cmd)
      \ :<c-u>call IronSend("\u001b\u005b\u0041")<CR>

if !hasmapto('<Plug>(iron-send-motion)')
  if maparg('c','n') ==# ''
    nmap ctr <Plug>(iron-send-motion)
  endif
  if maparg('c','v') ==# ''
    vmap ctr <Plug>(iron-send-motion)
  endif
endif

if !hasmapto('<Plug>(iron-repeat-cmd)')
  if maparg('c','n') ==# ''
    nmap cp <Plug>(iron-repeat-cmd)
  endif
endif
