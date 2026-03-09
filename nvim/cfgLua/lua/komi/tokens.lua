local M = {}

---@param provider string
---@return string
function M.get_token(provider)
	local path = vim.fn.expand("~/personal/tokens/" .. provider)
	local file = io.open(path, "r")
	if not file then
		error("Token file (" .. provider .. ") not found: " .. path)
	end

	local token = file:read("*l")
	file:close()

	if not token or token == "" then
		error("Token file is empty")
	end

	return token
end

return M
