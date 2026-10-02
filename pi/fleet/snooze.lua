-- Local reminders checked only while the orchestrator is open.
local M = {}
M.options = { "1 hour", "4 hours", "8 hours", "Next day · 14:00", "Friday night · 20:00", "Monday · 14:00" }

function M.deadline(choice, now)
  now = now or os.time()
  if choice <= 3 then return now + ({ 1, 4, 8 })[choice] * 3600 end
  local date = os.date("*t", now)
  date.hour, date.min, date.sec, date.isdst = choice == 5 and 20 or 14, 0, 0, nil
  if choice == 5 or choice == 6 then
    local weekday = choice == 5 and 6 or 2 -- Lua: Sunday=1.
    date.day = date.day + (weekday - date.wday) % 7
  end
  local deadline = os.time(date)
  if deadline <= now then
    date.day = date.day + (choice == 4 and 1 or 7)
    date.isdst = nil
    deadline = os.time(date)
  end
  return deadline
end

function M.new(file, notify)
  local entries, attempted = {}, {}
  if vim.fn.filereadable(file) == 1 then
    local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(file), "\n"))
    assert(ok and type(data) == "table", "Invalid snooze file: " .. file)
    for key, entry in pairs(data) do
      assert(type(key) == "string" and type(entry) == "table" and type(entry.due) == "number"
        and type(entry.name) == "string" and type(entry.project) == "string", "Invalid snooze entry: " .. key)
    end
    entries = data
  end
  local function save()
    local temporary = file .. "." .. vim.fn.getpid() .. ".tmp"
    assert(vim.fn.writefile({ vim.json.encode(entries) }, temporary) == 0, "Cannot save snoozes")
    assert(vim.uv.fs_rename(temporary, file))
  end
  local store = {}
  function store.get(key) return entries[key] end
  function store.set(key, due, name, project)
    attempted[key] = nil
    entries[key] = { due = due, name = name, project = project, notified = false }
    save()
  end
  function store.clear(key)
    entries[key], attempted[key] = nil, nil
    save()
  end
  function store.check(now)
    now = now or os.time()
    for key, entry in pairs(entries) do
      if entry.due <= now and not entry.notified and not attempted[key] then
        attempted[key] = true
        -- Keep failed notifications pending for a retry on the next launch.
        entry.notified = true
        save()
        local ok, sent = pcall(notify, entry)
        if not ok or not sent then
          entry.notified = false
          save()
          if not ok then vim.notify(tostring(sent), vim.log.levels.WARN) end
        end
      end
    end
  end
  return store
end
return M
