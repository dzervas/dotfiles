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
      if idx == 2 then
        vim.b.copilot_enabled = true
      elseif idx == 3 then
        local project_root = M.get_project_root()
        local state = M.load_copilot_state()
        state.projects[project_root] = true
        M.save_copilot_state(state)
      end

      vim.cmd("Copilot enable")
    end
  )
end

-- Auto-enable copilot based on saved state
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.defer_fn(function()
      local project_root = M.get_project_root()
      if M.is_copilot_enabled_for_project(project_root) then
        vim.notify("Copilot enabled for the project")
        vim.cmd("Copilot enable")
      end
    end, 100) -- Delay to allow plugins to load
  end,
})

-- Auto-enable copilot for buffers that had it enabled
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    if M.is_copilot_enabled_for_buffer() then
        vim.notify("Copilot enabled for the buffer")
        vim.cmd("Copilot enable")
    end
  end,
})

-- Make functions globally available
_G.CopilotManager = M
