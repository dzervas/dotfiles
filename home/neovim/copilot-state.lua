-- Copilot per-project management
if _G.CopilotManager then
  return _G.CopilotManager
end

local M = {}

-- Internal caches to avoid expensive work on each statusline render
M._config_file = nil
M._state_cache = nil
M._state_cache_mtime = 0
M._cwd_root_cache = {}

function M.get_config_file()
  if M._config_file then
    return M._config_file
  end
  local config_dir = vim.fn.stdpath("config")
  M._config_file = config_dir .. "/copilot-state.json"
  return M._config_file
end

function M.get_project_root()
  -- Cache per-cwd to avoid shelling out to git repeatedly
  local cwd = vim.fn.getcwd()
  local cached = M._cwd_root_cache[cwd]
  if cached ~= nil then
    return cached
  end

  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1]
  local root
  if vim.v.shell_error == 0 and git_root and git_root ~= "" then
    root = git_root
  else
    root = cwd
  end

  M._cwd_root_cache[cwd] = root
  return root
end

function M.load_copilot_state()
  local config_file = M.get_config_file()

  -- If file exists, only re-read when mtime changes
  if vim.fn.filereadable(config_file) == 1 then
    local stat = vim.uv and vim.uv.fs_stat(config_file) or vim.loop.fs_stat(config_file)
    local mtime = stat and stat.mtime and (stat.mtime.sec or stat.mtime) or 0

    if M._state_cache and mtime ~= 0 and mtime == M._state_cache_mtime then
      return M._state_cache
    end

    local content = vim.fn.readfile(config_file)
    if #content > 0 then
      local ok, state = pcall(vim.json.decode, table.concat(content, "\n"))
      if ok and type(state) == "table" then
        M._state_cache = state
        M._state_cache_mtime = mtime
        return state
      end
    end
  end

  -- Fallback default (also cached)
  if not M._state_cache then
    M._state_cache = { projects = {}, buffers = {} }
    M._state_cache_mtime = 0
  end
  return M._state_cache
end

function M.save_copilot_state(state)
  local config_file = M.get_config_file()
  local json_content = vim.json.encode(state)
  vim.fn.writefile(vim.split(json_content, "\n"), config_file)
  -- Update cache immediately to reflect saved content
  M._state_cache = state
  local stat = vim.uv and vim.uv.fs_stat(config_file) or vim.loop.fs_stat(config_file)
  M._state_cache_mtime = stat and stat.mtime and (stat.mtime.sec or stat.mtime) or 0
end

function M.is_copilot_enabled_for_project(project_root)
  local state = M.load_copilot_state()
  return state.projects[project_root] == true
end

function M.is_copilot_enabled_for_buffer()
  return vim.b.copilot_enabled == true
end

function M.show_copilot_enable_menu()
  vim.ui.select(
    {
      "Temporarily (this session only)",
      "For this project (saves to global config)"
    },
    {
      prompt = "Enable Copilot:",
      format_item = function(item)
        return item
      end,
    },
    function(_choice, idx)
      if idx == 1 then
        vim.cmd("Copilot enable")
      elseif idx == 2 then
        local project_root = M.get_project_root()
        local state = M.load_copilot_state()
        state.projects[project_root] = true
        M.save_copilot_state(state)
        vim.cmd("Copilot enable")
      end
    end
  )
end

function M.copilot_try_load()
  -- Ensure we only try once per project root in a session
  M._tried_projects = M._tried_projects or {}
  local project_root = M.get_project_root()
  if M._tried_projects[project_root] then
    return true
  end

  M._tried_projects[project_root] = true

  if M.is_copilot_enabled_for_project(project_root) then
    -- Avoid noisy notifications in tight loops/autocmds
    pcall(vim.cmd, "Copilot enable")
  end

  return true
end

-- Make functions globally available
_G.CopilotManager = M
