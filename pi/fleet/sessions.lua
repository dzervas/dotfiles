local M = {}

function M.encode(cwd)
  return "--" .. cwd:gsub("^[/\\]", ""):gsub("[/\\:]", "-") .. "--"
end

function M.label(encoded, home)
  local value = encoded:sub(3, -3)
  local prefix = home:gsub("^/", ""):gsub("/", "-") .. "-"
  if value:sub(1, #prefix) ~= prefix then return "/" .. value:gsub("-", "/") end
  value = value:sub(#prefix + 1)
  if value == "Lab-work" then return "󰢷  (root)" end
  if value:sub(1, 9) == "Lab-work-" then return "󰢷  " .. value:sub(10) end
  if value:sub(1, 4) == "Lab-" then return "󰙨 " .. value:sub(5) end
  return "~/" .. value:gsub("-", "/")
end

local function decode(line)
  local ok, entry = pcall(vim.json.decode, line)
  return ok and type(entry) == "table" and entry or nil
end
local function message_text(message)
  if type(message.content) == "string" then return message.content end
  local texts = {}
  for _, block in ipairs(type(message.content) == "table" and message.content or {}) do
    if type(block) == "table" and block.type == "text" and type(block.text) == "string" then texts[#texts + 1] = block.text end
  end
  return table.concat(texts, "\n")
end

function M.read(file, cache)
  local stat = vim.uv.fs_stat(file)
  if not stat then return end
  local stamp = stat.size .. ":" .. stat.mtime.sec .. ":" .. stat.mtime.nsec
  if cache[file] and cache[file].stamp == stamp then return cache[file] end
  local stream = io.open(file)
  if not stream then return end
  local header = decode(stream:read("*l") or "")
  if not header or header.type ~= "session" or type(header.cwd) ~= "string" then stream:close(); return end
  local name, prompt
  for line in stream:lines() do
    if line:find('"type"%s*:%s*"session_info"') then
      local entry = decode(line)
      if entry then name = entry.name end
    elseif not prompt and line:find('"role"%s*:%s*"user"') then
      local entry = decode(line)
      if entry and entry.message then prompt = message_text(entry.message):gsub("%s+", " "):sub(1, 80) end
    end
  end
  stream:close()
  local session = cache[file] or { file = file }
  session.cwd, session.id, session.timestamp, session.modified = header.cwd, header.id, header.timestamp, stat.mtime.sec
  session.name = type(name) == "string" and name ~= "" and name or prompt or vim.fn.fnamemodify(file, ":t:r")
  session.stamp = stamp
  cache[file] = session
  return session
end

function M.scan(root, home, cache)
  local projects = {}
  local dirs = vim.uv.fs_scandir(root)
  if not dirs then return projects end
  while true do
    local dir, kind = vim.uv.fs_scandir_next(dirs)
    if not dir then break end
    if kind == "directory" and dir:match("^%-%-.*%-%-$") then
      local project = { encoded = dir, label = M.label(dir, home), sessions = {} }
      local files = vim.uv.fs_scandir(root .. "/" .. dir)
      if files then
        while true do
          local file, file_kind = vim.uv.fs_scandir_next(files)
          if not file then break end
          if file_kind == "file" and file:match("%.jsonl$") then
            local session = M.read(root .. "/" .. dir .. "/" .. file, cache)
            if session then session.project = project; project.sessions[#project.sessions + 1] = session end
          end
        end
      end
      table.sort(project.sessions, function(a, b) return a.modified > b.modified end)
      projects[#projects + 1] = project
    end
  end
  table.sort(projects, function(a, b) return a.label < b.label end)
  return projects
end

-- Iterate human-readable message bodies only; tolerate a trailing partial JSONL record.
function M.messages(file, visit)
  local stream = io.open(file)
  if not stream then return end
  for line in stream:lines() do
    if line:find('"type"%s*:%s*"message"') then
      local entry = decode(line)
      local message = entry and entry.message
      if type(message) == "table" and (message.role == "user" or message.role == "assistant") then
        local text = message_text(message)
        if text ~= "" and visit(message.role, text) == false then break end
      end
    end
  end
  stream:close()
end
return M
