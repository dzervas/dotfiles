-- Fixture-only checks: never start Pi, read real sessions, or send desktop notifications.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local test_dir = root .. "/.test-work"
assert(vim.fn.isdirectory(test_dir) == 0, "Fixture directory already exists; inspect it before rerunning")
vim.fn.mkdir(test_dir .. "/sessions/--home-dzervas-Lab-work-job-ops--", "p")
local files = test_dir .. "/sessions/--home-dzervas-Lab-work-job-ops--"
local function write(name, session_name)
  local entries = {
    { type = "session", id = name, cwd = test_dir, timestamp = "2026-10-02T10:00:00Z", version = 3 },
    { type = "message", message = { role = "user", content = { { type = "text", text = "Find Parasolid face IDs" } } } },
    { type = "message", message = { role = "assistant", content = {
      { type = "thinking", thinking = "hidden reasoning" }, { type = "text", text = "Preserve the face mapping" } } } },
    { type = "session_info", name = session_name },
  }
  local lines = {}
  for _, entry in ipairs(entries) do lines[#lines + 1] = vim.json.encode(entry) end
  lines[#lines + 1] = '{"type":"message"' -- Partial last write.
  vim.fn.writefile(lines, files .. "/" .. name .. ".jsonl")
end
write("a", "Importer")
write("b", "Geometry")
local ok, err = pcall(function()
  local Sessions = dofile(root .. "/sessions.lua")
  local cache = {}
  local projects = Sessions.scan(test_dir .. "/sessions", "/home/dzervas", cache)
  assert(#projects == 1 and #projects[1].sessions == 2)
  assert(projects[1].label == "󰢷  job-ops")
  assert(cache[files .. "/a.jsonl"].name == "Importer")
  local messages = {}
  Sessions.messages(files .. "/a.jsonl", function(role, text) messages[#messages + 1] = role .. ":" .. text end)
  assert(#messages == 2 and not table.concat(messages):find("hidden reasoning", 1, true))
  assert(Sessions.encode("/home/a/job-ops") == "--home-a-job-ops--")
  local fake = [[import sys,time,json,base64
file=sys.argv[sys.argv.index('--session')+1]
def report(path):
 print('\033]777;pi-session;'+base64.b64encode(json.dumps({'file':path,'name':'Live importer'}).encode()).decode()+'\007',end='',flush=True)
report(file)
print('\033]0;⠋ π - working\007',end='',flush=True)
for line in sys.stdin:
 if line.strip() == 'switch': report(file.replace('/a.jsonl','/b.jsonl'))
 if line.strip() == 'wait': print('\033]0; π - input needed\007',end='',flush=True)
 if line.strip() == 'idle': print('\033]0;π - idle\007',end='',flush=True)
]]
  -- Inactive folders sort by latest session activity, not their names.
  local cadara = test_dir .. "/sessions/--home-dzervas-Lab-cadara--"
  vim.fn.mkdir(cadara, "p")
  vim.fn.writefile(vim.fn.readfile(files .. "/a.jsonl"), cadara .. "/recent.jsonl")
  vim.uv.fs_utime(files .. "/a.jsonl", 1000, 1000)
  vim.uv.fs_utime(files .. "/b.jsonl", 1000, 1000)
  vim.uv.fs_utime(cadara .. "/recent.jsonl", 2000, 2000)
  for index = 1, 4 do
    local file = cadara .. "/old-" .. index .. ".jsonl"
    vim.fn.writefile({ vim.fn.readfile(files .. "/a.jsonl")[1], vim.json.encode({ type = "session_info", name = "Old cadara " .. index }) }, file)
    vim.uv.fs_utime(file, index, index)
  end
  local before = { laststatus = vim.o.laststatus, tabline = vim.o.showtabline }
  local fleet = dofile(root .. "/init.lua").start({ sessions_dir = test_dir .. "/sessions", state_dir = test_dir .. "/state",
    command = { "python3", "-u", "-c", fake }, notify = function() return true end })
  assert(vim.o.laststatus == before.laststatus and vim.o.showtabline == before.tabline)
  local function find(name)
    for _, project in ipairs(fleet.projects()) do
      for _, session in ipairs(project.sessions) do if session.file == files .. "/" .. name .. ".jsonl" then return session end end
    end
  end
  assert(fleet.projects()[1].encoded == "--home-dzervas-Lab-cadara--", "latest inactive folder was not first")
  local api = vim.api
  local function sidebar_lines() return api.nvim_buf_get_lines(fleet.sidebar().buf, 0, -1, false) end
  local function old_count()
    local count = 0
    for _, line in ipairs(sidebar_lines()) do if line:find("Old cadara", 1, true) then count = count + 1 end end
    return count
  end
  assert(old_count() == 0, "inactive folder was not collapsed by default")
  for _, project in ipairs(fleet.projects()) do
    assert(project.collapsed, "inactive project was expanded by default")
  end
  fleet.refresh(); fleet.toggle(); fleet.toggle()
  assert(old_count() == 0, "refresh lost the collapsed state")
  api.nvim_set_current_win(fleet.sidebar().win)
  local enter = vim.fn.maparg("<CR>", "n", false, true).callback
  api.nvim_win_set_cursor(fleet.sidebar().win, { 3, 0 }); enter()
  assert(old_count() == 2, "folder did not limit itself to the three newest inactive sessions")
  local content = table.concat(sidebar_lines(), "\n")
  assert(content:find("Old cadara 4", 1, true) and content:find("Old cadara 3", 1, true))
  assert(not content:find("Old cadara 1", 1, true))
  local function more_row()
    for line, text in ipairs(sidebar_lines()) do if text:find("[show ", 1, true) then return line end end
  end
  api.nvim_set_current_win(fleet.sidebar().win)
  api.nvim_win_set_cursor(fleet.sidebar().win, { more_row(), 0 }); enter()
  assert(old_count() == 4, "show more did not reveal older inactive sessions")
  fleet.refresh(); fleet.toggle(); fleet.toggle()
  assert(old_count() == 4, "refresh lost the expanded history state")
  api.nvim_win_set_cursor(fleet.sidebar().win, { more_row(), 0 }); enter()
  assert(old_count() == 2, "show less did not restore the inactive limit")
  -- Live rows are additional to the three inactive rows, even if their files are old.
  local live_old = {}
  for _, project in ipairs(fleet.projects()) do
    if project.encoded == "--home-dzervas-Lab-cadara--" then
      for _, session in ipairs(project.sessions) do
        if session.file:match("/old%-[12]%.jsonl$") then
          fleet.open(session, false)
          live_old[#live_old + 1] = session
        end
      end
    end
  end
  assert(#live_old == 2 and old_count() == 4, "live sessions consumed the inactive quota")
  for _, session in ipairs(live_old) do vim.fn.jobstop(session.job) end
  assert(vim.wait(2000, function()
    for _, session in ipairs(live_old) do if session.job then return false end end
    return true
  end))
  -- n starts in context; N prompts in context; either falls back to HOME without one.
  api.nvim_set_current_win(fleet.sidebar().win)
  local start_here = vim.fn.maparg("n", "n", false, true).callback
  local choose_directory = vim.fn.maparg("N", "n", false, true).callback
  local original_input, prompts = Snacks.input, {}
  Snacks.input = function(options) prompts[#prompts + 1] = options.default end
  local function cadara_row()
    for line, text in ipairs(sidebar_lines()) do if text:find("󰙨 cadara", 1, true) then return line end end
  end
  api.nvim_win_set_cursor(fleet.sidebar().win, { cadara_row() + 1, 0 })
  choose_directory()
  assert(prompts[#prompts] == test_dir, "N did not prefill highlighted session cwd")
  local function check_new(row)
    api.nvim_set_current_win(fleet.sidebar().win)
    api.nvim_win_set_cursor(fleet.sidebar().win, { row, 0 })
    local count = #prompts
    start_here()
    assert(#prompts == count, "n unnecessarily prompted for a known directory")
    local created
    for _, project in ipairs(fleet.projects()) do
      for _, session in ipairs(project.sessions) do
        if session.job and session.file:find(Sessions.encode(test_dir), 1, true) then created = session end
      end
    end
    assert(created and created.launch_cwd == test_dir, "n launched in the wrong directory")
    vim.fn.jobstop(created.job)
    assert(vim.wait(2000, function() return created.job == nil end))
  end
  check_new(cadara_row() + 1) -- Session row.
  check_new(cadara_row()) -- Project row.
  api.nvim_set_current_win(fleet.sidebar().win)
  api.nvim_win_set_cursor(fleet.sidebar().win, { 1, 0 })
  start_here(); choose_directory()
  assert(prompts[#prompts] == vim.fn.expand("~") and prompts[#prompts - 1] == vim.fn.expand("~"), "missing context did not fall back to HOME")
  Snacks.input = original_input
  local a = find("a")
  fleet.open(a, false)
  assert(vim.wait(2000, function() return fleet.state(a) == "busy" and a.name == "Live importer" end), "terminal title or session report failed")
  assert(vim.fn.jobwait({ a.job }, 0)[1] == -1)
  assert(fleet.projects()[1].encoded == "--home-dzervas-Lab-work-job-ops--", "working folder was not promoted")
  local job, buffer = a.job, a.buf
  assert(vim.o.titlestring == "  " .. a.project.label)
  -- A hidden waiting agent must animate the orchestrator, including fullscreen.
  local b = find("b")
  fleet.open(b, false)
  assert(vim.wait(2000, function() return fleet.state(b) == "busy" end))
  local background_job = b.job
  fleet.open(a, false)
  vim.fn.chansend(background_job, "wait\n")
  assert(vim.wait(2000, function() return fleet.state(b) == "waiting" end))
  fleet.toggle()
  assert(vim.wait(2000, function() return vim.o.titlestring == "  " .. a.project.label end), "hidden waiting agent did not animate title")
  assert(vim.wait(1500, function() return vim.o.titlestring == "  " .. a.project.label end), "title did not alternate after one second")
  vim.fn.chansend(background_job, "idle\n")
  assert(vim.wait(2000, function() return fleet.state(b) == "idle" end))
  assert(vim.wait(500, function() return vim.o.titlestring == "  " .. a.project.label end))
  vim.wait(1100)
  assert(vim.o.titlestring == "  " .. a.project.label, "idle agent kept title flashing")
  vim.fn.jobstop(background_job)
  assert(vim.wait(2000, function() return b.job == nil end))
  fleet.toggle()
  vim.fn.chansend(job, "switch\n")
  assert(vim.wait(2000, function() return find("b").buf == buffer end), "Pi session transition did not move terminal ownership")
  assert(a.buf == nil and find("b").job == job)
  fleet.open(find("b"), false)
  assert(find("b").job == job, "selection launched a duplicate child")
  vim.fn.chansend(job, "idle\n")
  assert(vim.wait(2000, function() return fleet.state(find("b")) == "idle" end))
  api.nvim_set_current_win(fleet.main())
  vim.fn.maparg("<A-Down>", "t", false, true).callback()
  assert(api.nvim_get_current_win() == fleet.sidebar().win)
  local picker = fleet.search(true)
  assert(vim.wait(2000, function() return #picker:items() == 6 end), "history count=" .. #picker:items())
  assert(vim.wait(2000, function() return picker.input.win:valid() end))
  picker.input:set("Parasolid"); picker:find()
  assert(vim.wait(2000, function() return #picker:items() == 3 end))
  assert(vim.wait(2000, function() return picker.preview.win:valid() end))
  local preview = table.concat(api.nvim_buf_get_lines(picker.preview.win.buf, 0, -1, false), "\n")
  assert(preview:find("Parasolid", 1, true), "history side preview was empty")
  picker:close()
  -- Re-reading metadata must not change a live process's launch cwd.
  vim.fn.mkdir(test_dir .. "/different", "p")
  local lines = vim.fn.readfile(files .. "/b.jsonl")
  local header = vim.json.decode(lines[1]); header.cwd = test_dir .. "/different"
  lines[1] = vim.json.encode(header); vim.fn.writefile(lines, files .. "/b.jsonl")
  fleet.refresh(); fleet.open(find("b"), false)
  assert(api.nvim_win_call(fleet.main(), vim.fn.getcwd) == test_dir)
  -- Pi may resume a file another managed agent already owns; retain both jobs.
  fleet.open(a, false)
  assert(vim.wait(2000, function() return a.job ~= nil and fleet.state(a) == "busy" end))
  local second_job = a.job
  vim.fn.chansend(second_job, "switch\n")
  local function running_b()
    local result = {}
    for _, project in ipairs(fleet.projects()) do
      for _, session in ipairs(project.sessions) do
        if session.file == files .. "/b.jsonl" and session.job then result[#result + 1] = session end
      end
    end
    return result
  end
  assert(vim.wait(2000, function() return #running_b() == 2 end), "lost a job on managed session collision")
  for _, session in ipairs(running_b()) do assert(session.duplicate and vim.fn.jobwait({ session.job }, 0)[1] == -1) end
  vim.fn.jobstop(job); vim.fn.jobstop(second_job)
  assert(vim.wait(2000, function() return #running_b() == 0 end))
end)
vim.fn.writefile({ ok and "PASS: discovery, JSONL parsing, title state, session transitions, child reuse, fixed cwd, managed collisions, waiting-only terminal title animation, project activity ordering, inactive folding, contextual new-session keys, navigation, history search/preview, exit" or tostring(err) }, root .. "/check.log")
vim.api.nvim_create_autocmd("VimLeavePre", { once = true, callback = function()
  vim.fn.delete(test_dir, "rf")
end })
vim.cmd(ok and "qa!" or "cquit")
