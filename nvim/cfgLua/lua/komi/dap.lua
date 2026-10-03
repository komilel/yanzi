local M = {}
local options = {}
local paths = {}

local markers = {
  cs = { "%.csproj$", "%.slnx?$" },
  python = { "^pyproject%.toml$", "^setup%.py$", "^%.venv$", "^venv$", "^requirements%.txt$" },
  go = { "^go%.mod$", "^go%.work$" },
  rust = { "^Cargo%.toml$" },
  zig = { "^build%.zig$" },
  javascript = { "^package%.json$" },
  typescript = { "^package%.json$" },
  javascriptreact = { "^package%.json$" },
  typescriptreact = { "^package%.json$" },
}

function M.root()
  local patterns = markers[vim.bo.filetype] or {}
  return vim.fs.root(0, function(name)
    for _, pattern in ipairs(patterns) do
      if name:match(pattern) then
        return true
      end
    end
    return false
  end) or vim.fs.root(0, ".git") or vim.fn.getcwd()
end

-- nvim-dap evaluates coroutine-valued fields asynchronously. Cancellation must
-- return dap.ABORT, not an empty program name or a random process/port.
local function input(opts, validate)
  return coroutine.create(function(co)
    vim.ui.input(opts, function(value)
      local result = require("dap").ABORT
      if value and vim.trim(value) ~= "" then
        value = vim.trim(value)
        result = validate and validate(value) or value
      end
      vim.schedule(function()
        coroutine.resume(co, result)
      end)
    end)
  end)
end

function M.program(kind, subdir, extension)
  local extensions = type(extension) == "table" and extension or (extension and { extension })
  local root = M.root()
  local key = root .. ":" .. kind
  return input({
    prompt = kind .. " (build first): ",
    default = paths[key] or (root .. "/" .. subdir),
    completion = "file",
  }, function(path)
    path = vim.fn.expand(path)
    if not vim.startswith(path, "/") then
      path = root .. "/" .. path
    end
    path = vim.fs.normalize(path)
    local stat = vim.uv.fs_stat(path)
    local matches_extension = not extensions
      or vim.iter(extensions):any(function(ext)
        return vim.endswith(path:lower(), ext)
      end)
    if not stat or stat.type ~= "file" or not matches_extension then
      vim.notify(
        "Select an existing " .. (extensions and table.concat(extensions, "/") or "executable") .. " file",
        vim.log.levels.ERROR
      )
      return require("dap").ABORT
    end
    if not extensions and vim.fn.executable(path) ~= 1 then
      vim.notify("Selected file is not executable: " .. path, vim.log.levels.ERROR)
      return require("dap").ABORT
    end
    paths[key] = path
    return path
  end)
end

function M.python_path()
  if vim.env.VIRTUAL_ENV then
    local python = vim.env.VIRTUAL_ENV .. "/bin/python"
    if vim.fn.executable(python) == 1 then
      return python
    end
  end
  local root = M.root()
  for _, dir in ipairs({ ".venv", "venv" }) do
    local python = root .. "/" .. dir .. "/bin/python"
    if vim.fn.executable(python) == 1 then
      return python
    end
  end
  local python = vim.fn.exepath("python3")
  return python ~= "" and python or options.python
end

local function port(default)
  return input({ prompt = "Local debug server port: ", default = tostring(default) }, function(value)
    local number = tonumber(value)
    if not number or number % 1 ~= 0 or number < 1 or number > 65535 then
      vim.notify("Debug server port must be an integer between 1 and 65535", vim.log.levels.ERROR)
      return require("dap").ABORT
    end
    return number
  end)
end

function M.setup_go()
  local dap = require("dap")
  local adapter = dap.adapters.go
  dap.adapters.go = function(callback, config)
    adapter(function(value)
      value = vim.deepcopy(value)
      value.executable.cwd = config.cwd or M.root()
      callback(value)
    end, config)
  end
  for _, config in ipairs(dap.configurations.go) do
    config.cwd = config.cwd or M.root
    if config.mode == "test" then
      config.program = "${fileDirname}"
    end
  end
end

function M.setup(opts)
  options = opts
  local dap = require("dap")
  local pick_process = require("dap.utils").pick_process
  local function native(kind, subdir)
    return {
      {
        type = "codelldb",
        request = "launch",
        name = kind .. ": launch executable (build with debug symbols first)",
        program = function()
          return M.program(kind .. " executable", subdir)
        end,
        cwd = M.root,
        stopOnEntry = false,
        args = {},
      },
      {
        type = "codelldb",
        request = "attach",
        name = kind .. ": attach to process",
        pid = pick_process,
        cwd = M.root,
      },
    }
  end
  dap.configurations.rust = native("Rust", "target/debug/")
  dap.configurations.zig = native("Zig", "zig-out/bin/")
  dap.configurations.cs = {
    {
      type = "coreclr",
      request = "launch",
      name = ".NET: launch DLL (dotnet build first)",
      program = function()
        return M.program(".NET DLL", "bin/Debug/", ".dll")
      end,
      cwd = M.root,
      stopAtEntry = false,
      console = "integratedTerminal",
      args = {},
    },
    {
      type = "coreclr",
      request = "attach",
      name = ".NET: attach to process",
      processId = pick_process,
    },
  }
  dap.configurations.python = {
    {
      type = "debugpy",
      request = "launch",
      name = "Python: launch current file",
      program = "${file}",
      cwd = M.root,
      pythonPath = M.python_path,
      console = "integratedTerminal",
      justMyCode = true,
    },
    {
      type = "debugpy",
      request = "launch",
      name = "Python: launch module",
      module = function()
        return input({ prompt = "Python module (e.g. pytest): " })
      end,
      cwd = M.root,
      pythonPath = M.python_path,
      console = "integratedTerminal",
      justMyCode = true,
    },
    {
      type = "debugpy",
      request = "attach",
      name = "Python: attach to local debugpy (start with --listen)",
      connect = {
        host = "127.0.0.1",
        port = function()
          return port(5678)
        end,
      },
    },
  }

  local js_filetypes = { "javascript", "typescript", "javascriptreact", "typescriptreact" }
  local function out_files()
    local root = M.root()
    return { root .. "/**/*.js", root .. "/**/*.mjs", root .. "/**/*.cjs", "!**/node_modules/**" }
  end
  for _, ft in ipairs(js_filetypes) do
    local program = function()
      return M.program("Built JavaScript", "dist/", { ".js", ".mjs", ".cjs" })
    end
    -- JSX/TSX and TypeScript need the project's build step; don't assume ts-node.
    if ft == "javascript" then
      program = "${file}"
    end
    dap.configurations[ft] = {
      {
        type = "pwa-node",
        request = "launch",
        name = ft == "javascript" and "Node: launch current file" or "Node: launch built JavaScript (source maps)",
        program = program,
        cwd = M.root,
        sourceMaps = true,
        outFiles = out_files,
        console = "integratedTerminal",
      },
      {
        type = "pwa-node",
        request = "attach",
        name = "Node: attach to local inspector (start with --inspect)",
        address = "127.0.0.1",
        port = function()
          return port(9229)
        end,
        cwd = M.root,
        sourceMaps = true,
        outFiles = out_files,
      },
    }
  end

  -- Keep project-specific .vscode/launch.json configurations usable alongside
  -- these defaults. No builds or package installs happen implicitly on launch.
  local vscode = require("dap.ext.vscode")
  vscode.type_to_filetypes.coreclr = { "cs" }
  vscode.type_to_filetypes["pwa-node"] = js_filetypes
  vscode.type_to_filetypes.node = js_filetypes
  dap.adapters.node = function(callback, config)
    config.type = "pwa-node" -- VS Code commonly writes type="node" in launch.json.
    callback(vim.deepcopy(dap.adapters["pwa-node"]))
  end
  vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
  vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "Visual" })
end

return M
