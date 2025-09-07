-- Copilot per-project management
local M = {}

print("Running file")
function M.get_config_file()
  local config_dir = vim.fn.stdpath("config")
  print("Running get_config_file")
  return config_dir .. "/copilot-state.json"
end

function M.get_project_root()
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1]
  print("Running get_project_root")
  if vim.v.shell_error == 0 then
    return git_root
  end
  return vim.fn.getcwd()
end

function M.load_copilot_state()
  local config_file = M.get_config_file()
  print("Running load_copilot_state")
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
  print("Running save_copilot_state")
  local config_file = M.get_config_file()
  local json_content = vim.json.encode(state)
  vim.fn.writefile(vim.split(json_content, "\n"), config_file)
end

function M.is_copilot_enabled_for_project(project_root)
  print("Running is_copilot_enabled_for_project")
  local state = M.load_copilot_state()
  return state.projects[project_root]
end

function M.is_copilot_enabled_for_buffer()
  print("Running is_copilot_enabled_for_buffer")
  return vim.b.copilot_enabled == true
end

function M.show_copilot_enable_menu()
  print("Running show_copilot_enable_menu")
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

-- Auto-enable copilot based on saved state
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    print("Running VimEnter callback")
    local project_root = M.get_project_root()
    if M.is_copilot_enabled_for_project(project_root) then
      vim.notify("Copilot enabled for the project")
      vim.cmd("Copilot enable")
    end
  end,
})

-- Make functions globally available
_G.CopilotManager = M
