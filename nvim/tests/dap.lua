-- Real launch / breakpoint / continue checks; fixtures are generated in isolated HOME.
local dap = require("dap")
dap.set_log_level("DEBUG")
local root = assert(vim.env.NVIM_AUDIT_TMP)
local errors = {}
local notify = vim.notify
vim.notify = function(message, level, opts)
  if level == vim.log.levels.ERROR then
    errors[#errors + 1] = tostring(message)
  end
  notify(message, level, opts)
end
vim.lsp.start = function()
  return nil
end

local function write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines, path)
end
local function command(argv, cwd)
  local result = vim.system(argv, { cwd = cwd, text = true, timeout = 60000 }):wait()
  assert(result.code == 0, table.concat(argv, " ") .. "\n" .. (result.stderr or "") .. (result.stdout or ""))
end
local function exercise(label, path, line, config)
  errors = {}
  vim.cmd.edit(path)
  dap.clear_breakpoints()
  vim.api.nvim_win_set_cursor(0, { line, 0 })
  dap.set_breakpoint()
  local stopped = false
  local output = {}
  dap.listeners.after.event_output["integration"] = function(_, body)
    output[#output + 1] = body.output or ""
  end
  dap.listeners.after.event_stopped["integration"] = function(_, body)
    if body.reason == "breakpoint" then
      stopped = true
    end
  end
  config.console = "internalConsole"
  dap.run(config)
  assert(
    vim.wait(45000, function()
      return stopped or #errors > 0
    end),
    label .. " never hit its breakpoint"
  )
  assert(stopped, label .. ": " .. table.concat(errors, "\n") .. "\n" .. table.concat(output))
  -- event_stopped starts asynchronous thread/stack loading; wait until the
  -- client has a focused frame before invoking Continue, just as the UI does.
  assert(
    vim.wait(10000, function()
      local session = dap.session()
      return session and session.stopped_thread_id and session.current_frame
    end),
    label .. " did not load a stopped stack frame"
  )
  dap.continue()
  assert(
    vim.wait(15000, function()
      return next(dap.sessions()) == nil
    end),
    label .. " did not exit"
  )
  dap.listeners.after.event_stopped["integration"] = nil
  dap.listeners.after.event_output["integration"] = nil
  assert(#errors == 0, table.concat(errors, "\n"))
  print("PASS " .. label .. ": launch, hit breakpoint, continue, exit")
end

local function run()
  assert(vim.v.errmsg == "", vim.v.errmsg)
  vim.cmd.cd(root)
  write(root .. "/main.py", { "value = 42", "print(value)", "print('python done')" })
  local python = vim.deepcopy(dap.configurations.python[1])
  python.program = root .. "/main.py"
  python.cwd = root
  exercise("Python/debugpy", root .. "/main.py", 2, python)

  write(root .. "/main.js", { "const value = 42;", "console.log(value);", "console.log('node done');" })
  local node = vim.deepcopy(dap.configurations.javascript[1])
  node.program, node.cwd = root .. "/main.js", root
  node.type = "node" -- Also exercise the common VS Code launch.json alias.
  exercise("Node/js-debug", root .. "/main.js", 2, node)

  local cs = root .. "/cs"
  write(cs .. "/NuGet.Config", { "<configuration><packageSources><clear /></packageSources></configuration>" })
  write(cs .. "/App.csproj", {
    '<Project Sdk="Microsoft.NET.Sdk">',
    "<PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net10.0</TargetFramework></PropertyGroup>",
    "</Project>",
  })
  write(
    cs .. "/Program.cs",
    { "var value = 42;", "System.Console.WriteLine(value);", 'System.Console.WriteLine("dotnet done");' }
  )
  vim.env.DOTNET_CLI_HOME = root .. "/dotnet"
  vim.env.DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "1"
  vim.env.DOTNET_CLI_TELEMETRY_OPTOUT = "1"
  command({ "dotnet", "build", "App.csproj", "--configuration", "Debug", "--output", cs .. "/bin", "--nologo" }, cs)
  local coreclr = vim.deepcopy(dap.configurations.cs[1])
  coreclr.program, coreclr.cwd = cs .. "/bin/App.dll", cs
  exercise(".NET 10/netcoredbg", cs .. "/Program.cs", 2, coreclr)

  local go = root .. "/go"
  write(go .. "/go.mod", { "module example.test/debug", "", "go 1.24" })
  write(
    go .. "/main.go",
    { "package main", 'import "fmt"', "func main() {", "  value := 42", "  fmt.Println(value)", "}" }
  )
  vim.env.GOPROXY, vim.env.GOSUMDB, vim.env.GOTOOLCHAIN = "off", "off", "local"
  local golang = vim.deepcopy(dap.configurations.go[1])
  golang.program, golang.cwd = go, go
  exercise("Go/Delve", go .. "/main.go", 5, golang)
  write(go .. "/main_test.go", {
    "package main",
    'import "testing"',
    "func TestValue(t *testing.T) {",
    "  value := 42",
    "  if value != 42 { t.Fatal(value) }",
    "}",
  })
  local gotest
  for _, config in ipairs(dap.configurations.go) do
    if config.mode == "test" then
      gotest = vim.deepcopy(config)
      break
    end
  end
  assert(gotest, "Go test configuration is missing")
  exercise("Go tests/Delve", go .. "/main_test.go", 5, gotest)

  write(
    root .. "/native.c",
    { "#include <stdio.h>", "int main(void) {", "  int value = 42;", '  printf("%d\\n", value);', "  return 0;", "}" }
  )
  command({ "cc", "-g", "-O0", root .. "/native.c", "-o", root .. "/native" }, root)
  local native = vim.deepcopy(dap.configurations.rust[1])
  native.program, native.cwd = root .. "/native", root
  exercise("CodeLLDB (shared Rust/Zig adapter)", root .. "/native.c", 4, native)
  print("6 real DAP integration tests passed")
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  dap.terminate({ all = true })
  vim.wait(3000, function()
    return next(dap.sessions()) == nil
  end)
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
