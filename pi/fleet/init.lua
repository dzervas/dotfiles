local M = {}
-- Explicit opt-in; normal Neovim never sources this module.
function M.start(opts)
  opts = opts or {}
  local Snacks = require("snacks")
  local api = vim.api
  local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
  local main = api.nvim_get_current_win()
  local Sessions = dofile(root .. "/sessions.lua")
  local Snooze = dofile(root .. "/snooze.lua")
  local home = vim.fn.expand("~")
  local sessions_dir = vim.fs.normalize(opts.sessions_dir or home .. "/.pi/agent/sessions")
  local state_dir = opts.state_dir or vim.fn.stdpath("state") .. "/pi-fleet"
  vim.fn.mkdir(state_dir, "p")
  local cache, owned = {}, {}
  local snoozes = Snooze.new(state_dir .. "/snoozes.json", opts.notify or function(entry)
    local result = vim.system({ "notify-send", "--app-name=Pi sessions", "--",
      "Pi session reminder", entry.project .. " · " .. entry.name }, { text = true }):wait(1500)
    if result.code ~= 0 then vim.notify("Desktop reminder failed: " .. (result.stderr or "notify-send"), vim.log.levels.WARN) end
    return result.code == 0
  end)
  local function snooze_key(session) return session.file end
  local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
  local projects = {}
  local function refresh()
    local collapsed, expanded = {}, {}
    for _, project in ipairs(projects) do
      collapsed[project.encoded], expanded[project.encoded] = project.collapsed, project.show_all
    end
    projects = Sessions.scan(sessions_dir, home, cache)
    local present, groups = {}, {}
    for _, project in ipairs(projects) do
      project.collapsed, project.show_all = collapsed[project.encoded], expanded[project.encoded]
      groups[project.encoded] = project
      for _, session in ipairs(project.sessions) do present[session.file] = true end
    end
    for _, session in pairs(owned) do session.duplicate = nil end
    for _, session in pairs(owned) do
      local file = session.file
      if not present[file] or cache[file] ~= session then
        local encoded = vim.fn.fnamemodify(file, ":h:t")
        local project = groups[encoded]
        if not project then
          project = { encoded = encoded, label = Sessions.label(encoded, home), sessions = {}, collapsed = collapsed[encoded], show_all = expanded[encoded] }
          groups[encoded] = project
          projects[#projects + 1] = project
        end
        if present[file] then
          local replaced = false
          for index, existing in ipairs(project.sessions) do
            if existing.file == file then
              if not existing.job then project.sessions[index] = session; replaced = true
              else existing.duplicate, session.duplicate = true, true end
              break
            end
          end
          if not replaced then project.sessions[#project.sessions + 1] = session end
        else project.sessions[#project.sessions + 1] = session end
        session.project = project
      end
    end
  end
  refresh()

  local rows, selected, sidebar
  local frame = 0
  local ns = api.nvim_create_namespace("pi_fleet")
  local hint_style = api.nvim_get_hl(0, { name = "Comment", link = false })
  hint_style.bold = true
  api.nvim_set_hl(0, "PiSidebarHintKey", hint_style)
  local function state(session)
    if not session.buf or not api.nvim_buf_is_valid(session.buf) then return "inactive" end
    if not session.job or vim.fn.jobwait({ session.job }, 0)[1] ~= -1 then return "inactive" end
    local title = vim.b[session.buf].term_title or ""
    if title:find("", 1, true) or title:find("", 1, true) then return "waiting" end
    for _, icon in ipairs(frames) do
      if title:find(icon, 1, true) then return "busy" end
    end
    return "idle"
  end
  local function sort_projects()
    for _, project in ipairs(projects) do
      project.activity_rank, project.latest_activity = 2, 0
      for _, session in ipairs(project.sessions) do
        local rank = ({ waiting = 0, busy = 0, idle = 1, inactive = 2 })[state(session)]
        project.activity_rank = math.min(project.activity_rank, rank)
        project.latest_activity = math.max(project.latest_activity, session.modified or 0)
      end
      if project.collapsed == nil then project.collapsed = project.activity_rank == 2 end
    end
    table.sort(projects, function(a, b)
      if a.activity_rank ~= b.activity_rank then return a.activity_rank < b.activity_rank end
      if a.latest_activity ~= b.latest_activity then return a.latest_activity > b.latest_activity end
      return a.label < b.label
    end)
  end
  vim.o.title = true
  vim.o.titlelen = 0
  local waiting_since
  local function update_title()
    local waiting, running, idle = false, 0, 0
    for _, session in pairs(owned) do
      local current = state(session)
      if current == "busy" or current == "waiting" then running = running + 1
      elseif current == "idle" then idle = idle + 1 end
      if current == "waiting" then waiting = true end
    end
    local icon = ""
    if waiting then
      waiting_since = waiting_since or vim.uv.now()
      if math.floor((vim.uv.now() - waiting_since) / 1000) % 2 == 1 then icon = "" end
    else waiting_since = nil end
    local directory = selected and selected.project.label or Sessions.label(Sessions.encode(vim.fn.getcwd()), home)
    -- titlestring treats percent signs as statusline expressions.
    local spinner = running > 0 and frames[frame % #frames + 1] .. " " or ""
    local title = (spinner .. icon .. "  " .. directory .. " [" .. running .. "/" .. idle .. "]")
      :gsub("%c", " "):gsub("%%", "%%%%")
    if vim.o.titlestring ~= title then vim.o.titlestring = title end
  end
  local function marker(session)
    if session.duplicate then return "⚠", "DiagnosticWarn" end
    local current = state(session)
    if current == "busy" then return frames[frame % #frames + 1], "DiagnosticInfo" end
    if current == "waiting" then return ({ "", "" })[math.floor(frame / 10) % 2 + 1], "DiagnosticWarn" end
    if current == "idle" then return "●", "DiagnosticOk" end
    return "○", "Comment"
  end
  local function render()
    update_title()
    sort_projects()
    if not sidebar or not sidebar:valid() then return end
    local cursor = api.nvim_win_get_cursor(sidebar.win)
    local current_row = rows and rows[cursor[1]]
    local lines, highlights = { "  π SESSIONS", "" }, {}
    rows = {}
    for _, project in ipairs(projects) do
      lines[#lines + 1] = (project.collapsed and "  ▸ " or "  ▾ ") .. project.label
      rows[#lines] = project
      highlights[#highlights + 1] = { #lines - 1, "Title" }
      if not project.collapsed then
        local visible, inactive = {}, {}
        for _, session in ipairs(project.sessions) do
          local target = state(session) == "inactive" and inactive or visible
          target[#target + 1] = session
        end
        table.sort(inactive, function(a, b)
          if (a.modified or 0) ~= (b.modified or 0) then return (a.modified or 0) > (b.modified or 0) end
          return a.file < b.file
        end)
        local limit = project.show_all and #inactive or math.min(3, #inactive)
        for index = 1, limit do visible[#visible + 1] = inactive[index] end
        local has_more = #inactive > 3
        for index, session in ipairs(visible) do
          local icon, hl = marker(session)
          local indent = index == #visible and not has_more and "    └─ " or "    ├─ "
          lines[#lines + 1] = indent .. icon .. " " .. session.name .. (session == selected and "  ‹" or "")
          local reminder = snoozes.get(snooze_key(session))
          rows[#lines] = session
          highlights[#highlights + 1] = { #lines - 1, reminder and "Comment" or hl }
          if reminder then
            local due = reminder.due <= os.time()
            lines[#lines + 1] = "       " .. (due and " Due " or "󰒲 Snoozed ") .. os.date("%a %d %b %H:%M", reminder.due)
            rows[#lines] = session
            highlights[#highlights + 1] = { #lines - 1, due and "DiagnosticWarn" or "Comment" }
          end
        end
        if has_more then
          lines[#lines + 1] = "    └─ " .. (project.show_all and "[show less...]" or "[show more...] (" .. (#inactive - 3) .. ")")
          project.more_row = project.more_row or { more = project }
          rows[#lines] = project.more_row
          highlights[#highlights + 1] = { #lines - 1, "Comment" }
        end
      end
      lines[#lines + 1] = ""
    end
    local hints = {
      { { "n", " new" }, { "N", " directory" }, { "s", " snooze/clear" } },
      { { "Enter", " open" }, { "Alt-f", " names" } },
      { { "Ctrl-f", " history" }, { "Alt-o", " fullscreen" } },
    }
    while #lines < api.nvim_win_get_height(sidebar.win) - #hints do lines[#lines + 1] = "" end
    local hint_keys = {}
    for _, hint in ipairs(hints) do
      local text = "  "
      for _, part in ipairs(hint) do
        hint_keys[#hint_keys + 1] = { #lines, #text, #text + #part[1] }
        text = text .. part[1] .. part[2] .. "   "
      end
      lines[#lines + 1] = text
      highlights[#highlights + 1] = { #lines - 1, "Comment" }
    end
    vim.bo[sidebar.buf].modifiable = true
    api.nvim_buf_set_lines(sidebar.buf, 0, -1, false, lines)
    vim.bo[sidebar.buf].modifiable = false
    api.nvim_buf_clear_namespace(sidebar.buf, ns, 0, -1)
    for _, entry in ipairs(highlights) do
      api.nvim_buf_set_extmark(sidebar.buf, ns, entry[1], 0, { end_col = #lines[entry[1] + 1], hl_group = entry[2] })
    end
    for _, key in ipairs(hint_keys) do
      api.nvim_buf_set_extmark(sidebar.buf, ns, key[1], key[2], { end_col = key[3], hl_group = "PiSidebarHintKey", priority = 110 })
    end
    for line, row in pairs(rows) do if row == current_row then cursor[1] = line; break end end
    api.nvim_win_set_cursor(sidebar.win, { math.min(cursor[1], #lines), 0 })
  end
  local function ensure_main()
    if api.nvim_win_is_valid(main) then return end
    for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
      if not sidebar or win ~= sidebar.win then main = win; return end
    end
    vim.cmd.vsplit()
    main = api.nvim_get_current_win()
  end
  local function spawn(session)
    ensure_main()
    if vim.fn.isdirectory(session.cwd) ~= 1 then
      vim.notify("Session directory no longer exists: " .. session.cwd, vim.log.levels.WARN)
      return false
    end
    session.launch_cwd = session.cwd
    session.buf = api.nvim_create_buf(false, true)
    vim.bo[session.buf].bufhidden = "hide"
    vim.keymap.set("t", "<A-Down>", function()
      vim.cmd.stopinsert()
      vim.cmd.wincmd("W")
    end, { buffer = session.buf, desc = "Leave agent input and go to previous window" })
    -- Pi owns new/resume/fork; this hook observes its current file, without a control socket.
    api.nvim_create_autocmd("TermRequest", { buffer = session.buf, callback = function(event)
      local title, body = event.data.sequence:match("^\27%]777;notify;([^;]*);(.*)$")
      if title then
        -- Neovim consumes the child OSC and BEL; deliver them to the outer terminal.
        title, body = title:gsub("%c", " "), body:gsub("%c", " ")
        vim.schedule(function()
          io.stdout:write("\7\27]777;notify;" .. title .. ";" .. body .. "\7")
          io.stdout:flush()
        end)
        return
      end
      local payload = event.data.sequence:match("^\27%]777;pi%-session;([%w+/=]+)")
      if not payload then return end
      local ok, data = pcall(function() return vim.json.decode(vim.base64.decode(payload)) end)
      if not ok or type(data) ~= "table" or type(data.file) ~= "string" then return end
      local file = vim.fs.normalize(data.file)
      if file:sub(1, #sessions_dir + 1) ~= sessions_dir .. "/" then return end
      vim.schedule(function()
        local previous = session
        local next_session = file == session.file and session or cache[file] or { file = file }
        if next_session ~= session and next_session.job then
          next_session = { file = file, cwd = next_session.cwd, name = next_session.name }
          vim.notify("Two managed agents now share this session file", vim.log.levels.WARN)
        end
        next_session.cwd = next_session.cwd or session.cwd
        next_session.launch_cwd = session.launch_cwd
        next_session.name = data.name or next_session.name or "New session"
        next_session.buf, next_session.job = session.buf, session.job
        if next_session ~= previous then previous.buf, previous.job = nil, nil end
        session, cache[file], owned[next_session.buf] = next_session, next_session, next_session
        if selected == previous then selected = session end
        refresh(); render()
      end)
    end })
    local command = opts.command or { "fish", root .. "/run-agent.fish" }
    command = vim.list_extend(vim.deepcopy(command), { "--session", session.file })
    api.nvim_win_call(main, function()
      api.nvim_win_set_buf(main, session.buf)
      vim.cmd.lcd(vim.fn.fnameescape(session.cwd))
      session.job = vim.fn.jobstart(command, { term = true, cwd = session.cwd, on_exit = function()
        vim.schedule(function() session.job = nil; owned[session.buf] = nil; refresh(); render() end)
      end })
    end)
    if session.job <= 0 then session.job = nil; vim.notify("Unable to start Pi", vim.log.levels.ERROR); return false end
    owned[session.file] = nil
    owned[session.buf] = session
    return true
  end
  local function open(session, focus)
    if not session then return end
    if not session.job or vim.fn.jobwait({ session.job }, 0)[1] ~= -1 then
      if not spawn(session) then return end
    end
    ensure_main()
    selected = session
    api.nvim_win_set_buf(main, session.buf)
    api.nvim_win_call(main, function() vim.cmd.lcd(vim.fn.fnameescape(session.launch_cwd or session.cwd)) end)
    render()
    if focus then api.nvim_set_current_win(main); vim.cmd.startinsert() end
  end
  local function start_directory(dir)
    if not dir or dir == "" then return end
    dir = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(dir), ":p"))
    if vim.fn.isdirectory(dir) ~= 1 then vim.notify("Choose an existing directory", vim.log.levels.WARN); return end
    local encoded = Sessions.encode(dir)
    local project = { encoded = encoded, label = Sessions.label(encoded, home), sessions = {} }
    local folder = sessions_dir .. "/" .. encoded
    vim.fn.mkdir(folder, "p")
    local file = folder .. "/" .. os.date("%Y-%m-%dT%H-%M-%S") .. "_" .. vim.fn.getpid() .. "_" .. vim.uv.hrtime() .. ".jsonl"
    local session = { name = "New session", file = file, cwd = dir, project = project }
    cache[file] = session
    owned[file] = session
    refresh()
    open(session, true)
  end
  local function highlighted_directory()
    local row = rows[api.nvim_win_get_cursor(sidebar.win)[1]]
    if not row then return end
    row = row.more or row
    local candidates = row.sessions or { row }
    for _, session in ipairs(candidates) do
      local dir = session.job and session.launch_cwd or session.cwd
      if dir and vim.fn.isdirectory(dir) == 1 then return dir end
    end
  end
  local function new_directory(ask)
    local dir = highlighted_directory()
    if dir and not ask then start_directory(dir); return end
    Snacks.input({ prompt = "New agent directory", default = dir or home, completion = "dir" }, start_directory)
  end
  local function preview(session, target)
    local messages, index = {}, 0
    Sessions.messages(session.file, function(role, text)
      index = index + 1
      if target then
        if index > target + 2 then return false end
        if index < target - 2 then return end
      elseif #messages == 3 then table.remove(messages, 1) end
      messages[#messages + 1] = { role = role, text = text:sub(1, 12000) }
    end)
    local lines = { "# " .. session.name, "", "Project: " .. session.project.label, "" }
    for _, message in ipairs(messages) do vim.list_extend(lines, { "## " .. message.role, "", message.text, "" }) end
    return { text = table.concat(lines, "\n"), ft = "markdown", loc = false }
  end
  local function search(history)
    vim.cmd.stopinsert()
    refresh()
    local candidates = {}
    for _, project in ipairs(projects) do
      for _, session in ipairs(project.sessions) do
        candidates[#candidates + 1] = { session = session, project = project,
          rank = ({ busy = 0, waiting = 0, idle = 1, inactive = 2 })[state(session)] }
      end
    end
    return Snacks.picker({ title = history and "Pi message history" or "Pi session names",
      finder = function()
        return function(add)
          for _, candidate in ipairs(candidates) do
              local session, project, rank = candidate.session, candidate.project, candidate.rank
              if history then
                local index = 0
                Sessions.messages(session.file, function(_, text)
                  index = index + 1
                  local target = index
                  add({ text = text, session = session, rank = rank,
                    resolve = function(item) item.preview = preview(session, target) end })
                end)
              else
                add({ text = project.label .. "  " .. session.name, session = session, rank = rank,
                  resolve = function(item) item.preview = preview(session) end })
              end
          end
        end
      end,
      format = history and function(item)
        return { { item.session.project.label .. " / " .. item.session.name .. "  ", "Comment" }, { item.text:gsub("\n", " ") } }
      end or "text", preview = "preview",
      sort = { fields = { "rank", "score:desc", "idx" } }, matcher = { sort_empty = true, fuzzy = not history },
      layout = { preset = "default" },
      confirm = function(picker, item) picker:close(); if item then open(item.session, true) end end,
    })
  end
  local function snooze_session()
    local session = rows[api.nvim_win_get_cursor(sidebar.win)[1]]
    if not session or session.sessions or session.more then return end
    local key = snooze_key(session)
    if snoozes.get(key) then snoozes.clear(key); render(); return end
    vim.ui.select(Snooze.options, { prompt = "Snooze: " .. session.name }, function(_, choice)
      if choice then
        snoozes.set(key, Snooze.deadline(choice), session.name, session.project.label)
        render()
      end
    end)
  end
  local function show_sidebar()
    sidebar = Snacks.win({ position = "left", width = 40, enter = true, fixbuf = true,
      wo = { number = false, relativenumber = false, cursorline = true, wrap = false, winfixwidth = true },
      keys = {
        ["<CR>"] = function()
          local row = rows[api.nvim_win_get_cursor(sidebar.win)[1]]
          if row and row.more then row.more.show_all = not row.more.show_all; render()
          elseif row and row.sessions then row.collapsed = not row.collapsed; render()
          else open(row, true) end
        end,
        -- Only switches to live agents; dead sessions still need Enter to start.
        ["<2-LeftMouse>"] = function()
          local mouse = vim.fn.getmousepos()
          local row = mouse.winid == sidebar.win and rows[mouse.line]
          if row and not row.sessions and not row.more and state(row) ~= "inactive" then open(row, true) end
        end,
        n = function() new_directory(false) end,
        N = function() new_directory(true) end,
        s = snooze_session,
        ["<A-f>"] = function() search(false) end,
        ["<C-f>"] = function() search(true) end,
        q = function() sidebar:hide(); api.nvim_set_current_win(main) end,
      },
    })
    render()
    api.nvim_win_set_cursor(sidebar.win, { 4, 0 })
  end
  local function toggle()
    vim.cmd.stopinsert()
    if sidebar and sidebar:valid() then sidebar:hide(); api.nvim_set_current_win(main)
    elseif sidebar then sidebar:show(); sidebar:focus(); render()
    else show_sidebar() end
  end
  vim.keymap.set({ "n", "t" }, "<A-o>", toggle, { desc = "Pi session fullscreen" })
  vim.keymap.set({ "n", "t" }, "<A-f>", function() search(false) end, { desc = "Search Pi session names" })
  vim.keymap.set({ "n", "t" }, "<C-f>", function() search(true) end, { desc = "Search Pi message history" })
  local welcome = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(welcome, 0, -1, false, { "Pi sessions", "", "Select a session on the left. Press n to start there, or N to choose another directory.",
    "Alt-o fullscreen · Alt-f session names · Ctrl-f history · Alt-down leave agent input", "", "Only selected agents are started. Pi manages its own session dialogs." })
  vim.bo[welcome].modifiable = false
  api.nvim_win_set_buf(main, welcome)
  show_sidebar()
  snoozes.check() -- Includes reminders whose deadline passed while Neovim was closed.
  local checked_at = os.time()
  local timer = vim.uv.new_timer()
  timer:start(100, 100, vim.schedule_wrap(function()
    frame = frame + 1
    local now = os.time()
    if now ~= checked_at then checked_at = now; snoozes.check(now); if now % 5 == 0 then refresh() end end
    render()
  end))
  api.nvim_create_autocmd("VimLeavePre", { once = true, callback = function()
    timer:stop(); timer:close()
    for _, project in ipairs(projects) do
      for _, session in ipairs(project.sessions) do
        if session.job then vim.fn.jobstop(session.job) end
      end
    end
  end })
  return { projects = function() return projects end, state = state, open = open, search = search, toggle = toggle,
    sidebar = function() return sidebar end, main = function() return main end, snooze = snooze_session, refresh = refresh }
end
return M
