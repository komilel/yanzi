local M = {}

---@param provider string
---@param opts? { optional?: boolean }
---@return string?
function M.get_token(provider, opts)
  local path = vim.fn.expand("~/personal/tokens/" .. provider)
  local file, err, code = io.open(path, "r")
  if not file then
    if opts and opts.optional and code == 2 then -- ENOENT: allow the CLI's own login
      return nil
    end
    error("Cannot read token file (" .. provider .. "): " .. (err or path))
  end

  local token = file:read("*l")
  file:close()
  token = token and vim.trim(token)

  if not token or token == "" then
    error("Token file (" .. provider .. ") is empty: " .. path)
  end

  return token
end

return M
