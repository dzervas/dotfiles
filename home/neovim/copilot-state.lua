-- Copilot per-project management
local M = {}

function M.get_config_file()
  local config_dir = vim.fn.stdpath("config")
  return config_dir .. "/copilot-state.json"
end

function M.get_project_root()
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1]
  if vim.v.shell_error == 0 then
    return git_root
  end
  return vim.fn.getcwd()
end

function M.load_copilot_state()
  local config_file = M.get_config_file()
  if vim.fn.filereadable(config_file) == 1 then
    local content = vim.fn.readfile(config_file)
    if #content > 0 then
      local ok, state = pcall(vim.json.decode, table.concat(content, "\n"))
      if ok and state then
        return state
      end
    end
  end
  return { projects = {}, buffers = {} }
end

function M.save_copilot_state(state)
  local config_file = M.get_config_file()
  local json_content = vim.json.encode(state)
  vim.fn.writefile(vim.split(json_content, "\n"), config_file)
end

function M.is_copilot_enabled_for_project(project_root)
  local state = M.load_copilot_state()
  return state.projects[project_root] == true
end

function M.is_copilot_enabled_for_buffer()
  return vim.b.copilot_enabled == true
end

function M.setup_copilot()
  local ok, copilot = pcall(require, "copilot")
  if ok then
    copilot.setup({
      suggestion = { auto_trigger = true }
    })
    return true
  end
  return false
end

function M.enable_copilot_temporarily()
  if M.setup_copilot() then
    vim.notify("Copilot enabled temporarily for this session", vim.log.levels.INFO)
  else
    vim.notify("Copilot not available", vim.log.levels.WARN)
  end
end

function M.enable_copilot_for_buffer()
  vim.b.copilot_enabled = true
  if M.setup_copilot() then
    vim.notify("Copilot enabled for current buffer", vim.log.levels.INFO)
  else
    vim.notify("Copilot not available", vim.log.levels.WARN)
  end
end

function M.enable_copilot_for_project()
  local project_root = M.get_project_root()
  local state = M.load_copilot_state()
  state.projects[project_root] = true
  M.save_copilot_state(state)

  if M.setup_copilot() then
    vim.notify("Copilot enabled and saved for project: " .. project_root, vim.log.levels.INFO)
  else
    vim.notify("Copilot not available", vim.log.levels.WARN)
  end
end

function M.show_copilot_enable_menu()
  vim.ui.select(
    {
      "Temporarily (this session only)",
      "For current buffer only", 
      "For this project (saves to global config)"
    },
    {
      prompt = "Enable Copilot:",
      format_item = function(item)
        return item
      end,
    },
    function(choice, idx)
      if idx == 1 then
        M.enable_copilot_temporarily()
      elseif idx == 2 then
        M.enable_copilot_for_buffer()
      elseif idx == 3 then
        M.enable_copilot_for_project()
      end
    end
  )
end

-- Auto-enable copilot based on saved state
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.defer_fn(function()
      local project_root = M.get_project_root()
      if M.is_copilot_enabled_for_project(project_root) then
        if M.setup_copilot() then
          vim.notify("Copilot auto-enabled for project: " .. vim.fn.fnamemodify(project_root, ":t"), vim.log.levels.INFO)
        end
      end
    end, 100) -- Delay to allow plugins to load
  end,
})

-- Auto-enable copilot for buffers that had it enabled
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    if M.is_copilot_enabled_for_buffer() then
      M.setup_copilot()
    end
  end,
})

-- Make functions globally available
_G.CopilotManager = M
