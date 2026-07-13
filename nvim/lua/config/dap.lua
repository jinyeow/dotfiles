-- PowerShell debugging via nvim-dap + PowerShell Editor Services (PSES).
--
-- PSES is the same bundle used for the powershell_es LSP (config/lsp.lua); it
-- doubles as a Debug Adapter Protocol server — exactly what the VS Code
-- PowerShell extension drives on F5. This wires a self-contained `ps1` adapter
-- that starts its OWN PSES instance in -DebugServiceOnly mode inside a terminal
-- (the "PowerShell Extension Terminal", where the debuggee actually runs and
-- Read-Host/Write-Host and the debugger REPL live), then connects nvim-dap to
-- the debug named pipe reported in PSES's session-details file.
--
-- Deliberately independent of the LSP: debugging and language features run as
-- separate PSES processes, so the hand-tuned powershell_es block is untouched.
-- This reproduces the DAP handshake from TheLeoP/powershell.nvim without taking
-- the plugin as a dependency — keep the two in sync if that upstream changes.

if _G.user_config.profile == 'minimal' then
  return
end

local bundle = _G.user_config.pwsh_bundle_path
if bundle == '' then
  return -- same gate as the LSP: no PSES bundle found, nothing to wire
end

local ok, dap = pcall(require, 'dap')
if not ok then
  return
end

local api = vim.api
local cache = vim.fn.stdpath('cache')
-- Distinct from the LSP session file so a running LSP never clobbers it.
local session_file = vim.fs.normalize(('%s/powershell_es.dap_session.json'):format(cache))
local log_file = vim.fs.normalize(('%s/powershell_es.dap.log'):format(cache))

-- -DebugServiceOnly: create only the debug pipe (LSP is a separate process).
-- -EnableConsoleRepl: give the integrated console the debuggee interacts with.
local function make_cmd()
  local script = vim.fs.normalize(('%s/PowerShellEditorServices/Start-EditorServices.ps1'):format(bundle))
  return {
    'pwsh',
    '-NoLogo',
    '-NoProfile',
    '-NonInteractive',
    '-File',
    script,
    '-HostName',
    'nvim',
    '-HostProfileId',
    'Neovim',
    '-HostVersion',
    '1.0.0',
    '-LogPath',
    log_file,
    '-LogLevel',
    'Warning',
    '-BundledModulesPath',
    bundle,
    '-DebugServiceOnly',
    '-EnableConsoleRepl',
    '-SessionDetailsPath',
    session_file,
  }
end

-- Poll for PSES's session-details file (written once the debug pipe is up),
-- decode it, delete it, hand the details back. Mirrors powershell.nvim's
-- util.wait_for_session_file (60 tries x 500ms). Only succeeds once the file
-- both decodes and carries a debugServicePipeName.
local function wait_for_session_file(cb)
  local tries, max_tries = 0, 60
  local timer = assert(vim.uv.new_timer())
  local function finish(details, err)
    timer:stop()
    if not timer:is_closing() then
      timer:close()
    end
    vim.schedule(function()
      cb(details, err)
    end)
  end
  timer:start(500, 500, function()
    tries = tries + 1
    local fd = io.open(session_file, 'r')
    if fd then
      local contents = fd:read('*a')
      fd:close()
      os.remove(session_file)
      local decoded_ok, decoded = pcall(vim.json.decode, contents)
      if decoded_ok and type(decoded) == 'table' and decoded.debugServicePipeName then
        return finish(decoded)
      end
    end
    if tries >= max_tries then
      finish(nil, 'powershell dap: timed out waiting for PSES session file')
    end
  end)
end

local dap_term_buf ---@type integer?
local dap_term_chan ---@type integer?

dap.adapters.ps1 = function(on_config)
  local cmd = make_cmd()
  dap_term_buf = api.nvim_create_buf(false, false)
  api.nvim_buf_call(dap_term_buf, function()
    dap_term_chan = vim.fn.jobstart(cmd, { term = true })
  end)
  wait_for_session_file(function(details, err)
    if err or not details then
      return vim.notify(err or 'powershell dap: no session details', vim.log.levels.ERROR)
    end
    on_config({
      type = 'pipe',
      pipe = details.debugServicePipeName,
      name = 'PowerShell Editor Services',
    })
  end)
end

-- nvim-dap resolves ${file}, ${fileDirname}, ${workspaceFolder} natively.
dap.configurations.ps1 = {
  {
    name = 'PowerShell: Launch Current File',
    type = 'ps1',
    request = 'launch',
    script = '${file}',
    cwd = '${fileDirname}',
  },
  {
    name = 'PowerShell: Launch Script / Command',
    type = 'ps1',
    request = 'launch',
    -- Prompt for a path or command (e.g. Invoke-Pester) at debug time.
    script = function()
      return coroutine.create(function(co)
        vim.ui.input({
          prompt = 'Path or command (e.g. ${workspaceFolder}/src/foo.ps1 or Invoke-Pester): ',
          completion = 'file',
        }, function(selected)
          coroutine.resume(co, selected)
        end)
      end)
    end,
    cwd = '${workspaceFolder}',
  },
  {
    name = 'PowerShell: Attach to Host Process',
    type = 'ps1',
    request = 'attach',
    processId = function()
      return require('dap.utils').pick_process()
    end,
  },
}

-- Match breakpoint/stopped signs to the diagnostic icons used in config/lsp.lua.
vim.fn.sign_define('DapBreakpoint', { text = '', texthl = 'DiagnosticError', numhl = '' })
vim.fn.sign_define('DapBreakpointCondition', { text = '', texthl = 'DiagnosticWarn', numhl = '' })
vim.fn.sign_define('DapBreakpointRejected', { text = '', texthl = 'DiagnosticInfo', numhl = '' })
vim.fn.sign_define('DapStopped', { text = '', texthl = 'DiagnosticHint', linehl = 'Visual', numhl = '' })

local key = 'pwsh-dap'
-- Tear down the debug terminal buffer when the session ends.
dap.listeners.after.initialize[key] = function(session)
  session.on_close[key] = function()
    if dap_term_buf and api.nvim_buf_is_valid(dap_term_buf) then
      api.nvim_buf_delete(dap_term_buf, { force = true })
    end
    dap_term_buf, dap_term_chan = nil, nil
  end
end

-- PSES asks the client to press a key to advance its console REPL after the
-- debuggee finishes; forward a keypress to the terminal (VS Code sends 'p').
dap.listeners.after['event_powerShell/sendKeyPress'][key] = function()
  if dap_term_chan then
    api.nvim_chan_send(dap_term_chan, 'p')
  end
end
