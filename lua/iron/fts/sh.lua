local sh = {}

sh.bash = {
  command = {"bash"},
}

sh.sh = {
  command = function(meta)
    local bufnr = meta.current_bufnr
    if vim.b[bufnr].is_posix == 1 then
      return {"sh"}
    elseif vim.b[bufnr].is_bash == 1 then
      return {"bash"}
    elseif vim.b[bufnr].is_kornshell == 1 then
      return {"ksh"}
    else
      return {"sh"}
    end
  end,
}

return sh
