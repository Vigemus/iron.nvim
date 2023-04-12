local markdown = {}

local function replace_tab_by_spaces(line)
  local spaces = string.rep(" ", 8)
  return string.gsub(line, "\t", spaces)
end

local aichat_format = function(lines)
  local cr = "\13"
  local open_code = "{"
  local close_code = "}"
  -- aichat currently use `{` and `}`
  -- to determine whether it is multi line input.
  -- aichat uses tab for invoking completion,
  -- there's no way to insert a real tab,
  -- we can only replace tab by spaces.
  if #lines == 1 then
    return { replace_tab_by_spaces(lines[1]) .. cr }
  else
    local new = { open_code .. replace_tab_by_spaces(lines[1]) .. cr }
    for line = 2, #lines do
      table.insert(new, replace_tab_by_spaces(lines[line]) .. cr)
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
