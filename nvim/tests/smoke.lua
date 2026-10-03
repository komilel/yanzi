-- Run with tests/smoke.sh against the built configuration, not `nvim --clean`.
-- No language servers or AI requests are started; files and state live in a temp dir.
local function run()
  assert(vim.v.errmsg == "", "startup error: " .. vim.v.errmsg)
  vim.lsp.start = function()
    return nil
  end
  local root = assert(vim.env.NVIM_AUDIT_TMP)
  vim.cmd.cd(root)
  local passed = 0
  local function test(name, fn)
    fn()
    passed = passed + 1
    print("PASS " .. name)
  end
  local function mapping(lhs, mode)
    return vim.fn.maparg(lhs, mode or "n", false, true)
  end
  local function load_plugin(name)
    require("lz.n").trigger_load(name)
    assert(vim.v.errmsg == "", vim.v.errmsg)
  end

  test("format and toggle mappings are distinct, global, and survive LSP attach", function()
    local format = mapping("<leader>lf").callback
    local toggle = mapping("<leader>ltf").callback
    assert(type(format) == "function" and type(toggle) == "function" and format ~= toggle)
    assert(type(mapping("<leader>lf", "x").callback) == "function")
    default_on_attach({}, vim.api.nvim_get_current_buf())
    assert(mapping("<leader>lf").callback == format)
    assert(mapping("<leader>ltf").callback == toggle)
    assert(mapping("]d").buffer == 0 and mapping("[d").buffer == 0)
    toggle()
    assert(vim.b.disableFormatSave == true)
    toggle()
    assert(vim.b.disableFormatSave == false)
  end)

  test("diagnostics use jump and do not shadow DAP stack mappings", function()
    local jump, count = vim.diagnostic.jump, nil
    vim.diagnostic.jump = function(opts)
      count = opts.count
    end
    mapping("]d").callback()
    assert(count == 1)
    mapping("[d").callback()
    assert(count == -1)
    vim.diagnostic.jump = jump
    assert(type(vim.diagnostic.config().jump.on_jump) == "function")
    assert(next(mapping("<leader>dv")) == nil)
    assert(type(mapping("<leader>ud").callback) == "function")
  end)

  test("Conform has one save hook and manual formatting works without an LSP", function()
    load_plugin("conform-nvim")
    local hooks = vim.api.nvim_get_autocmds({ group = "Conform" })
    local pre, post = 0, 0
    for _, hook in ipairs(hooks) do
      if hook.event == "BufWritePre" then
        pre = pre + 1
      end
      if hook.event == "BufWritePost" then
        post = post + 1
      end
    end
    assert(pre == 1 and post == 0, vim.inspect(hooks))
    vim.cmd.edit(root .. "/format.lua")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local x={a=1}", "return x" })
    mapping("<leader>lf").callback()
    assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "local x = { a = 1 }")
    local completed = false
    local attempted = require("conform").format({
      async = false,
      range = { start = { 1, 0 }, ["end"] = { 1, 10 } },
    }, function(err)
      assert(not err, err)
      completed = true
    end)
    assert(attempted and completed)
    vim.b.disableFormatSave = true
    vim.api.nvim_buf_set_lines(0, 0, 1, false, { "local x={a=2}" })
    vim.cmd("write")
    assert(vim.fn.readfile(root .. "/format.lua")[1] == "local x={a=2}")
    vim.b.disableFormatSave = false
    vim.cmd("write")
    assert(vim.fn.readfile(root .. "/format.lua")[1] == "local x = { a = 2 }")
    assert(not vim.bo.modified)
  end)

  test("language parsers and JSX/TSX tooling are available", function()
    for _, lang in ipairs({
      "c_sharp",
      "nix",
      "lua",
      "markdown",
      "markdown_inline",
      "typescript",
      "tsx",
      "python",
      "rust",
      "go",
    }) do
      assert(vim.treesitter.language.add(lang), "missing parser: " .. lang)
    end
    local filetypes = vim.lsp.config["typescript-language-server"].filetypes
    local conform = require("conform")
    local linters = require("lint").linters_by_ft
    for _, ft in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
      assert(vim.tbl_contains(filetypes, ft), "missing LSP filetype: " .. ft)
      assert(vim.deep_equal(conform.formatters_by_ft[ft], { "prettier" }))
      assert(vim.deep_equal(linters[ft], { "eslint_d" }))
    end
  end)

  test("C# indentation is stable on re-entry and Roslyn options are effective", function()
    vim.cmd.edit(root .. "/Indent.cs")
    assert(vim.bo.filetype == "cs")
    assert(vim.bo.indentexpr == "" and vim.bo.smartindent)
    assert(require("roslyn.config").get().filewatching == "off")
    vim.bo.smartindent = false
    vim.api.nvim_exec_autocmds("BufEnter", { buffer = 0 })
    assert(not vim.bo.smartindent, "BufEnter reset a buffer-local preference")
  end)

  test("inlay hints initialize once and manual toggling is buffer-local", function()
    local a = vim.api.nvim_get_current_buf()
    local b = vim.api.nvim_create_buf(false, true)
    local original = vim.lsp.get_client_by_id
    vim.lsp.get_client_by_id = function()
      return {
        supports_method = function()
          return true
        end,
      }
    end
    local function attach()
      vim.api.nvim_exec_autocmds("LspAttach", {
        group = "komi_editor",
        buffer = a,
        data = { client_id = 999 },
      })
    end
    vim.b[a].komi_inlay_hints_initialized = nil
    vim.lsp.inlay_hint.enable(false, { bufnr = a })
    vim.lsp.inlay_hint.enable(true, { bufnr = b })
    attach()
    assert(vim.lsp.inlay_hint.is_enabled({ bufnr = a }))
    mapping("<leader>li").callback()
    attach()
    assert(not vim.lsp.inlay_hint.is_enabled({ bufnr = a }))
    assert(vim.lsp.inlay_hint.is_enabled({ bufnr = b }))
    vim.lsp.get_client_by_id = original
  end)

  test("lsp-overloads v2 registers its handler before any client attaches", function()
    local hooks = vim.api.nvim_get_autocmds({ group = "LspOverloadsAttach", event = "LspAttach" })
    assert(#hooks == 1)
    assert(require("lsp-overloads._core.configuration").current.display_automatically)
  end)

  test("search commands are available before first keypress", function()
    assert(vim.fn.exists(":Telescope") == 2)
    vim.cmd("Telescope keymaps")
    require("telescope.actions").close(vim.api.nvim_get_current_buf())
    assert(vim.fn.executable("fd") == 1 and vim.fn.executable("rg") == 1)
    local pickers = require("telescope.config").pickers
    assert(pickers.find_files.hidden)
    assert(vim.tbl_contains(pickers.find_files.find_command, ".git"))
    assert(vim.tbl_contains(pickers.live_grep.additional_args, "--hidden"))
  end)

  test("AI plugins load without reading tokens or starting a conversation", function()
    assert(vim.fn.exists(":CodeCompanionChat") == 2)
    assert(vim.fn.exists(":ClaudeCode") == 2)
    load_plugin("codecompanion.nvim")
    local config = require("codecompanion.config")
    assert(config.interactions.chat.opts.completion_provider == "blink")
    assert(config.display.chat.opts == nil)
    assert(Snacks.config.picker.ui_select == false)
    assert(vim.ui.select == require("fastaction").select)
  end)

  test("DAP adapters and launch/attach configurations are installed", function()
    local dap = require("dap")
    for _, ft in ipairs({
      "cs",
      "python",
      "go",
      "rust",
      "zig",
      "javascript",
      "typescript",
      "javascriptreact",
      "typescriptreact",
    }) do
      assert(#dap.configurations[ft] >= 2, "missing configurations for " .. ft)
      for _, config in ipairs(dap.configurations[ft]) do
        assert(dap.adapters[config.type], "missing adapter: " .. config.type)
      end
    end
    for _, name in ipairs({ "coreclr", "pwa-node", "codelldb" }) do
      local adapter = dap.adapters[name]
      assert(vim.fn.executable(adapter.command or adapter.executable.command) == 1)
    end
    dap.adapters.debugpy(function(adapter)
      assert(vim.fn.executable(adapter.command) == 1)
    end, { request = "launch" })
    local vscode_config = { type = "node" }
    dap.adapters.node(function(adapter)
      assert(adapter.type == "server")
    end, vscode_config)
    assert(vscode_config.type == "pwa-node")
    assert(type(require("dap-go").debug_test) == "function")
    assert(type(mapping("<leader>dB").callback) == "function")
    assert(type(mapping("<leader>dl").callback) == "function")
  end)

  local function resolve_prompt(thread, value)
    local original_input = vim.ui.input
    vim.ui.input = function(_, callback)
      callback(value)
    end
    local done, result = false, nil
    local co = coroutine.create(function()
      result = coroutine.yield()
      done = true
    end)
    assert(coroutine.resume(co))
    assert(coroutine.resume(thread, co))
    assert(
      vim.wait(1000, function()
        return done
      end),
      "prompt never completed"
    )
    vim.ui.input = original_input
    return result
  end

  test("DAP roots, virtualenv selection and cancellation are predictable", function()
    local helper, dap = require("komi.dap"), require("dap")
    local project = root .. "/app"
    vim.fn.mkdir(project .. "/src", "p")
    vim.fn.writefile({ "<Project/>" }, project .. "/App.csproj")
    vim.cmd.edit(project .. "/src/Test.cs")
    assert(helper.root() == project)
    assert(resolve_prompt(dap.configurations.cs[1].program(), nil) == dap.ABORT)
    assert(resolve_prompt(dap.configurations.cs[1].program(), "missing.dll") == dap.ABORT)
    vim.fn.writefile({ "dummy DLL" }, project .. "/app.dll")
    assert(resolve_prompt(dap.configurations.cs[1].program(), "app.dll") == project .. "/app.dll")
    vim.fn.writefile({ "console.log(42)" }, project .. "/main.mjs")
    assert(resolve_prompt(dap.configurations.typescript[1].program(), "main.mjs") == project .. "/main.mjs")
    assert(resolve_prompt(dap.configurations.javascript[2].port(), "70000") == dap.ABORT)
    assert(resolve_prompt(dap.configurations.javascript[2].port(), "9229") == 9229)
    vim.fn.writefile({}, project .. "/pyproject.toml")
    vim.fn.mkdir(project .. "/.venv/bin", "p")
    vim.fn.writefile({ "#!/bin/sh", "exit 0" }, project .. "/.venv/bin/python")
    assert(vim.uv.fs_chmod(project .. "/.venv/bin/python", 448))
    vim.cmd.edit(project .. "/src/Test.py")
    local venv = vim.env.VIRTUAL_ENV
    vim.env.VIRTUAL_ENV = nil
    assert(helper.root() == project)
    assert(helper.python_path() == project .. "/.venv/bin/python")
    vim.env.VIRTUAL_ENV = project .. "/.venv"
    assert(helper.python_path() == project .. "/.venv/bin/python")
    vim.env.VIRTUAL_ENV = venv
  end)

  test("PlantUML renders unsaved buffers and local includes as text/PNG/SVG", function()
    assert(vim.fn.exists(":PlantumlPreview") == 2)
    assert(vim.fn.exists(":PlantumlExport") == 2)
    assert(vim.fn.exists(":PlantumlStartDocker") == 0)
    local dir = root .. "/diagrams with spaces"
    vim.fn.mkdir(dir, "p")
    vim.fn.writefile({ "participant Alice" }, dir .. "/actors.puml")
    vim.cmd.edit(dir .. "/test.puml")
    assert(vim.bo.filetype == "plantuml")
    vim.api.nvim_buf_set_lines(
      0,
      0,
      -1,
      false,
      { "@startuml", "!include actors.puml", "Alice -> Bob: unsaved", "@enduml" }
    )
    local puml = require("komi.plantuml")
    local function render(format)
      local done, error, output = false, nil, nil
      puml.render(0, format, function(err, data)
        error, output, done = err, data, true
      end)
      assert(
        vim.wait(40000, function()
          return done
        end),
        "renderer timed out"
      )
      return error, output
    end
    local err, text = render("ascii")
    assert(not err, err)
    assert(text:find("Alice", 1, true) and text:find("unsaved", 1, true))
    local png_err, png = render("png")
    assert(not png_err, png_err)
    assert(png:sub(1, 8) == "\137PNG\r\n\26\n", "invalid PNG header")
    local svg_err, svg = render("svg")
    assert(not svg_err, svg_err)
    assert(svg:find("<svg", 1, true))
    local svgpath = dir .. "/export with spaces.svg"
    vim.cmd("PlantumlExport svg " .. svgpath)
    assert(vim.wait(40000, function()
      return vim.fn.filereadable(svgpath) == 1
    end))
    assert(table.concat(vim.fn.readfile(svgpath)):find("<svg", 1, true))
    vim.fn.writefile({ "do not overwrite" }, svgpath)
    vim.cmd("PlantumlExport svg " .. svgpath)
    assert(vim.fn.readfile(svgpath)[1] == "do not overwrite")
    -- ALLOWLIST blocks URL includes rather than fetching them during local render.
    vim.api.nvim_buf_set_lines(
      0,
      0,
      -1,
      false,
      { "@startuml", "!includeurl http://127.0.0.1:9/blocked.puml", "@enduml" }
    )
    assert(render("svg") ~= nil, "remote include was not rejected")
  end)

  test("PlantUML ignores replaced jobs, guards source exports and only opens local files", function()
    local puml = require("komi.plantuml")
    local system, notify = vim.system, vim.notify
    local calls, callbacks, killed, stale = {}, {}, 0, false
    vim.notify = function() end
    vim.system = function(cmd, opts, callback)
      calls[#calls + 1] = { cmd = cmd, opts = opts }
      callbacks[#callbacks + 1] = callback
      return {
        kill = function()
          killed = killed + 1
        end,
      }
    end
    puml.render(0, "ascii", function()
      stale = true
    end)
    puml.preview("svg")
    assert(killed == 1)
    callbacks[1]({ code = 0, stdout = "stale" })
    callbacks[2]({ code = 0, stdout = "<svg/>" })
    assert(vim.wait(1000, function()
      return #calls == 3
    end))
    assert(not stale)
    for i = 1, 2 do
      assert(calls[i].cmd[1]:find("plantuml", 1, true))
      assert(calls[i].opts.env.PLANTUML_SECURITY_PROFILE == "ALLOWLIST")
      assert(calls[i].opts.env["plantuml.allowlist.url"] == "")
    end
    assert(calls[3].cmd[1]:find("xdg-open", 1, true))
    assert(vim.fn.filereadable(calls[3].cmd[2]) == 1)
    puml.export("svg", vim.api.nvim_buf_get_name(0), true)
    assert(#calls == 3, "source export was not blocked")
    puml.render(0, "png", function()
      stale = true
    end)
    vim.api.nvim_buf_delete(0, { force = true })
    assert(killed == 2)
    callbacks[4]({ code = 0, stdout = "stale" })
    vim.wait(50)
    assert(not stale)
    vim.system, vim.notify = system, notify
  end)

  test("token files are optional only when absent, and CRLF is trimmed", function()
    local expand = vim.fn.expand
    local path = root .. "/test-token"
    vim.fn.expand = function()
      return path
    end
    local tokens = require("komi.tokens")
    assert(tokens.get_token("test", { optional = true }) == nil)
    assert(not pcall(tokens.get_token, "test"))
    vim.fn.writefile({ "dummy-token\r" }, path)
    assert(tokens.get_token("test") == "dummy-token")
    vim.fn.writefile({ "   " }, path)
    assert(not pcall(tokens.get_token, "test", { optional = true }))
    vim.fn.expand = expand
  end)

  assert(vim.v.errmsg == "", vim.v.errmsg)
  print(string.format("%d smoke tests passed", passed))
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
