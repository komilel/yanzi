local M = {}
local options = { command = "plantuml", viewer = "xdg-open", timeout = 30000 }
local jobs, previews = {}, {}
local tempdir
local formats = { ascii = "utxt", txt = "txt", utxt = "utxt", png = "png", svg = "svg" }

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "PlantUML" })
end

local function directory(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  return name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()
end

-- Render a snapshot of the buffer, not the saved file. One job per source buffer;
-- replacing a job or wiping its buffer cancels it and discards stale results.
function M.render(bufnr, format, callback)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  format = formats[format]
  if not format then
    callback("Supported formats: ascii, txt, utxt, png, svg")
    return
  end
  local previous = jobs[bufnr]
  if previous and previous.process then
    pcall(previous.process.kill, previous.process, 15)
  end
  local job = {}
  jobs[bufnr] = job
  local cwd = directory(bufnr)
  local source = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n") .. "\n"
  local ok, process = pcall(vim.system, {
    options.command,
    "--format",
    format,
    "--pipe",
    "--stop-on-error",
    "--no-error-image",
  }, {
    stdin = source,
    cwd = cwd,
    text = format == "utxt" or format == "txt",
    timeout = options.timeout,
    env = {
      PLANTUML_SECURITY_PROFILE = "ALLOWLIST",
      ["plantuml.allowlist.path"] = cwd,
      ["plantuml.include.path"] = cwd,
      ["plantuml.allowlist.url"] = "",
    },
  }, function(result)
    vim.schedule(function()
      if jobs[bufnr] ~= job then
        return
      end
      jobs[bufnr] = nil
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      if result.code ~= 0 then
        local detail = vim.trim(result.stderr or "")
        callback("Rendering failed (exit " .. result.code .. ")" .. (detail ~= "" and ":\n" .. detail or ""))
      elseif not result.stdout or result.stdout == "" then
        callback("PlantUML produced no output; check for @startuml / @enduml")
      else
        callback(nil, result.stdout, format)
      end
    end)
  end)
  if not ok then
    jobs[bufnr] = nil
    callback("Cannot start local renderer: " .. tostring(process))
    return
  end
  job.process = process
  return job
end

local function write(path, data, overwrite)
  -- Exclusive creation avoids silently overwriting files if an export races a
  -- second render or another application. Exports require ! to replace a file.
  local fd, err = vim.uv.fs_open(path, overwrite and "w" or "wx", 384)
  if not fd then
    return nil, err
  end
  local written, write_err = vim.uv.fs_write(fd, data, 0)
  vim.uv.fs_close(fd)
  if written ~= #data then
    return nil, write_err or "Incomplete write"
  end
  return true
end

local function preview_text(bufnr, text)
  local preview = previews[bufnr]
  if not preview or not vim.api.nvim_buf_is_valid(preview) then
    preview = vim.api.nvim_create_buf(false, true)
    previews[bufnr] = preview
    vim.bo[preview].buftype = "nofile"
    vim.bo[preview].bufhidden = "wipe"
    vim.bo[preview].swapfile = false
    vim.bo[preview].filetype = "text"
    vim.api.nvim_buf_set_name(preview, "PlantUML://" .. bufnr)
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = preview, silent = true, desc = "Close PlantUML preview" })
  end
  vim.bo[preview].modifiable = true
  vim.api.nvim_buf_set_lines(preview, 0, -1, false, vim.split(text:gsub("\n$", ""), "\n", { plain = true }))
  vim.bo[preview].modifiable = false
  local windows = vim.fn.win_findbuf(preview)
  local win = windows[1] or vim.api.nvim_open_win(preview, false, { split = "right" })
  vim.wo[win].wrap = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
end

function M.preview(format)
  local bufnr = vim.api.nvim_get_current_buf()
  M.render(bufnr, format or "ascii", function(err, data, output_format)
    if err then
      notify(err, vim.log.levels.ERROR)
      return
    end
    if output_format == "utxt" or output_format == "txt" then
      preview_text(bufnr, data)
      return
    end
    if not tempdir then
      tempdir = vim.fn.tempname()
      vim.fn.mkdir(tempdir, "p", 448)
    end
    local path = tempdir .. "/" .. bufnr .. "." .. output_format
    local ok, write_err = write(path, data, true)
    if not ok then
      notify("Cannot write preview: " .. tostring(write_err), vim.log.levels.ERROR)
      return
    end
    local started, viewer_err = pcall(vim.system, { options.viewer, path }, {}, function(result)
      if result.code ~= 0 then
        vim.schedule(function()
          notify("Cannot open preview: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
        end)
      end
    end)
    if not started then
      notify("Cannot start viewer: " .. tostring(viewer_err), vim.log.levels.ERROR)
    end
  end)
end

function M.export(format, path, overwrite)
  local bufnr = vim.api.nvim_get_current_buf()
  local output_format = formats[format or "png"]
  if not output_format then
    notify("Supported formats: ascii, txt, utxt, png, svg", vim.log.levels.ERROR)
    return
  end
  if not path or path == "" then
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == "" then
      notify("An unnamed buffer needs an explicit export path", vim.log.levels.ERROR)
      return
    end
    path = vim.fn.fnamemodify(name, ":r") .. "." .. (output_format == "utxt" and "txt" or output_format)
  end
  path = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
  -- Never overwrite the source file, even with :PlantumlExport!.
  local source = vim.api.nvim_buf_get_name(bufnr)
  local target_stat, source_stat = vim.uv.fs_stat(path), vim.uv.fs_stat(source)
  if
    vim.fs.normalize(path) == vim.fs.normalize(source)
    or (target_stat and source_stat and target_stat.dev == source_stat.dev and target_stat.ino == source_stat.ino)
  then
    notify("Export path is the source file", vim.log.levels.ERROR)
    return
  end
  if target_stat and not overwrite then
    notify("Export already exists; use :PlantumlExport! to overwrite: " .. path, vim.log.levels.ERROR)
    return
  end
  M.render(bufnr, format or "png", function(err, data)
    if err then
      notify(err, vim.log.levels.ERROR)
      return
    end
    local ok, write_err = write(path, data, overwrite)
    if ok then
      notify("Exported " .. path)
    else
      notify("Cannot export: " .. tostring(write_err), vim.log.levels.ERROR)
    end
  end)
end

function M.setup(opts)
  options = vim.tbl_extend("force", options, opts or {})
  vim.filetype.add({ extension = { puml = "plantuml", plantuml = "plantuml", pu = "plantuml" } })
  vim.api.nvim_create_user_command("PlantumlPreview", function(args)
    M.preview(args.args ~= "" and args.args or "ascii")
  end, {
    nargs = "?",
    desc = "Render current buffer locally and preview (ascii/png/svg)",
    complete = function()
      return { "ascii", "png", "svg" }
    end,
  })
  vim.api.nvim_create_user_command("PlantumlExport", function(args)
    M.export(args.fargs[1], #args.fargs > 1 and table.concat(args.fargs, " ", 2) or nil, args.bang)
  end, { nargs = "*", bang = true, complete = "file", desc = "Local export: [format=png] [path]; ! permits overwrite" })
  local group = vim.api.nvim_create_augroup("komi_plantuml", { clear = true })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      local job = jobs[args.buf]
      jobs[args.buf] = nil
      if job and job.process then
        pcall(job.process.kill, job.process, 15)
      end
      local preview = previews[args.buf]
      previews[args.buf] = nil
      if preview and vim.api.nvim_buf_is_valid(preview) then
        vim.api.nvim_buf_delete(preview, { force = true })
      end
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      for bufnr, job in pairs(jobs) do
        jobs[bufnr] = nil
        if job.process then
          pcall(job.process.kill, job.process, 15)
        end
      end
      if tempdir then
        vim.fn.delete(tempdir, "rf")
        tempdir = nil
      end
    end,
  })
end

return M
