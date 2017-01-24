nmap <silent> ctr :set opfunc=IronSendMotion<CR>g@
vmap <silent> ctr :call IronSendMotion('visual')<CR>
"Call previous command again
nmap <silent> cp :call IronSend("\u001b\u005b\u0041")<CR>
