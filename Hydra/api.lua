function api.userfile(name)
  return os.getenv("HOME") .. "/.hydra/" .. name .. ".lua"
end

function api.douserfile(name)
  local userfile = api.userfile(name)
  local exists, isdir = api.fileexists(userfile)
  if exists and not isdir then
    dofile(userfile)
  else
    api.alert("Can't find file: " .. name)
  end
end

local function load_default_config()
  local defaultinit = dofile(api.resourcesdir .. "/defaultinit.lua")
  defaultinit.run()
end

local function clear_old_state()
  -- hotkeys
  for _, hotkey in pairs(api.hotkey.keys) do
    hotkey:disable()
  end
  api.hotkey.keys = {}

  -- menu
  api.menu.hide()

  -- pathwatchers
  for i = # api.pathwatcher.pathwatchers, 1, -1 do
    local pw = api.pathwatcher.pathwatchers[i]
    pw:stop()
  end

  -- timers
  for i = # api.timer.timers, 1, -1 do
    local t = api.timer.timers[i]
    t:stop()
  end

  -- textgrids
  for i = # api.textgrid.textgrids, 1, -1 do
    local tg = api.textgrid.textgrids[i]
    tg:close()
  end
end

function api.reload()
  clear_old_state()

  local userfile = os.getenv("HOME") .. "/.hydra/init.lua"
  local exists, isdir = api.fileexists(userfile)

  if exists and not isdir then
    local ok, err = pcall(function() dofile(userfile) end)
    if not ok then
      api.alert("Error loading your config:\n" .. err .. "\nFalling back to sample config.", 10)
      load_default_config()
    end
  else
    -- don't say (via alert) anything more than what the default config already says
    load_default_config()
  end
end

function api.errorhandler(err)
  print("Error: " .. err)
  api.alert("Error: " .. err, 5)
end

function api.tryhandlingerror(firsterr)
  local ok, seconderr = pcall(function()
      api.errorhandler(firsterr)
  end)

  if not ok then
    api.alert("Error while handling error: " .. seconderr, 10)
    api.alert("Original error: " .. firsterr, 10)
  end
end

function api.call(fn, ...)
  local results = table.pack(pcall(fn, ...))
  if not results[1] then
    -- print(debug.traceback())
    api.tryhandlingerror(results[2])
  end
  return table.unpack(results)
end

function api.uuid()
  return io.popen("uuidgen"):read()
end