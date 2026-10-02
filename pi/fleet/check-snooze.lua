-- Run under TZ=Europe/Athens to verify calendar and DST cases.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local M = dofile(root .. "/snooze.lua")
local file = root .. "/.snooze-test-state.json"
assert(vim.fn.filereadable(file) == 0, "Test state already exists; inspect it before rerunning")
local function timestamp(year, month, day, hour, min)
  return os.time({ year = year, month = month, day = day, hour = hour, min = min or 0, sec = 0 })
end
local ok, err = pcall(function()
  local now = timestamp(2026, 10, 2, 4) -- Friday.
  for choice, hours in ipairs({ 1, 4, 8 }) do assert(M.deadline(choice, now) == now + hours * 3600) end
  assert(M.deadline(4, now) == timestamp(2026, 10, 2, 14))
  assert(M.deadline(4, timestamp(2026, 10, 2, 14)) == timestamp(2026, 10, 3, 14))
  assert(M.deadline(5, now) == timestamp(2026, 10, 2, 20))
  assert(M.deadline(5, timestamp(2026, 10, 2, 20)) == timestamp(2026, 10, 9, 20))
  assert(M.deadline(6, now) == timestamp(2026, 10, 5, 14))
  assert(M.deadline(6, timestamp(2026, 10, 5, 14)) == timestamp(2026, 10, 12, 14))
  assert(M.deadline(4, timestamp(2026, 10, 24, 16)) == timestamp(2026, 10, 25, 14)) -- DST ends.
  assert(M.deadline(4, timestamp(2026, 3, 28, 16)) == timestamp(2026, 3, 29, 14)) -- DST starts.
  local notifications = 0
  local function notify(entry)
    assert(entry.name == "Session" and entry.project == "Project")
    notifications = notifications + 1
    return true
  end
  local store = M.new(file, notify)
  local due = timestamp(2026, 10, 2, 14)
  store.set("session", due, "Session", "Project")
  store = M.new(file, notify) -- Simulate reopening after the deadline.
  store.check(timestamp(2026, 10, 2, 14, 34))
  assert(notifications == 1 and store.get("session").notified)
  M.new(file, notify).check(timestamp(2026, 10, 3, 14))
  assert(notifications == 1, "reopening repeated a delivered notification")
  store.clear("session")
  assert(M.new(file, notify).get("session") == nil, "unsnooze did not persist")
  store.set("session", due, "Session", "Project")
  local failed = 0
  store = M.new(file, function() failed = failed + 1; return false end)
  store.check(due - 1); assert(failed == 0)
  store.check(due); store.check(due + 1)
  assert(failed == 1 and not store.get("session").notified)
  M.new(file, notify).check(due + 2)
  assert(notifications == 2, "failed delivery was not retried on reopening")
end)
vim.fn.delete(file)
vim.fn.writefile({ ok and "PASS: deadlines, DST, overdue-on-launch, notification deduplication, persisted unsnooze, delivery retry" or tostring(err) }, root .. "/snooze-check.log")
vim.cmd(ok and "qa!" or "cquit")
