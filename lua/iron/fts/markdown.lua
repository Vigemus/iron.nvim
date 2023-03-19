local markdown = {}

local aichat_format = function(lines)
  local cr = "\13"
  local open_code = "{"
  local close_code = "}"
  -- aichat currently use `{` and `}`
  -- to determine whether it is multi line input.
  if #lines == 1 then
    return { lines[1] .. cr }
  else
    local new = { open_code .. lines[1] .. cr }
    for line = 2, #lines do
      table.insert(new, lines[line] .. cr)
    end

    table.insert(new, close_code .. cr)

    return new
  end
end

markdown.aichat = {
  command = "aichat",
  format = aichat_format,
}

return markdown
