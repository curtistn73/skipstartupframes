-- Current plugin directory
local plugin_directory = manager.plugins['skipstartupframes'].directory

-- Load plugin metadata
local json = require('json')
local skipstartupframes = json.parse(io.open(plugin_directory .. '/plugin.json'):read('*a')).plugin

local settings = {}

-- Default settings
-- local settings_defaults = {
--   comments = true,
--   output = "cfg_generated",
--   run_at_start = false,
--   run_at_end = true,
--   overwrite = true
-- }

-- local settings_path = plugin_directory .. "/settings.json"

-- -- Open settings file
-- local settings_file = io.open(settings_path, "r")

-- -- If settings file doesn't exist, use default settings
-- if settings_file == nil then
--   settings = settings_defaults
-- else
--   -- Parse settings file
--   settings = json.parse(settings_file:read("*a"))

--   -- Add any missing settings from defaults and fix any wrong types
--   for k,v in pairs(settings_defaults) do
--     if (settings[k] == nil or type(settings[k]) ~= type(v)) then
--       settings[k] = v
--     end
--   end
-- end

-- Notifiers
local startNotifier = nil
local stopNotifier = nil

function skipstartupframes.startplugin()
  -- Settings
  local debug = false
  local blackout = true
  local parentFallback = true

  -- Find the frames file
  local frames_path = plugin_directory .. "/ssf.txt"
  local frames_file = io.open(frames_path, "r")

  -- Read in and parse the frames file
  local frames = {}
  if frames_file ~= nil then
    frames_file = frames_file:read("*a")

    -- Split lines
    for line in frames_file:gmatch("[^\r\n]+") do
      -- Split on comma
      local key, value = line:match("([^,]+),([^,]+)")

      -- Add rom and frame count to frames table
      if (key ~= nil and value ~= nil) then
        frames[key] = tonumber(value)
      end

    end
  end

  -- Initialize frame processing function to do nothing
  local process_frame = function() end

  -- Trampoline function to process each frame
  emu.register_frame_done(function()
    process_frame()
  end)

  local start = function()
    local rom = emu.romname()

    -- If no rom is loaded, don't do anything
    if rom == "___empty" then
      return
    end

    -- Fetch frame count for rom from ssf.txt
    local frameTarget = frames[rom]

    -- If the rom was not found in SSF.txt...
    if frameTarget == nil and not debug then

      -- If parent rom fallback is disabled, don't do anything
      if not parentFallback then
        return
      end

      -- Look for parent ROM
      local parent = emu.driver_find(rom).parent

      -- No parent found, don't do anything
      if parent == "0" then
        return
      end

      -- Fetch frame count for parent rom from ssf.txt
      frameTarget = frames[parent]

      -- No frame count found for parent rom, don't do anything
      if frameTarget == nil then
        return
      end
    end

    -- Screen info
    local screen = manager.machine.screens[':screen']

    -- Enable throttling and mute audio
    if not debug then
      manager.machine.video.throttled = false
      manager.machine.sound.system_mute = true
    end

    -- Starting frame
    local frame = 0

    -- Process each frame
    process_frame = function()
      -- Draw debug frame text if in debug mode
      if debug then
        screen:draw_text(0, 0, "ROM: "..rom.." Frame: "..frame, 0xffffffff, 0xff000000)
      end

      -- Black out screen only when not in debug mode
      if blackout and not debug then
        screen:draw_box(0, 0, screen.width, screen.height, 0x00000000, 0xff000000)
      end

      -- Iterate frame count only when not in debug mode and machine is not paused
      if not debug or not manager.machine.paused then
        frame = frame + 1
      end

      -- Frame target reached
      if not debug and frame >= frameTarget then

        -- Re-enable throttling
        manager.machine.video.throttled = true

        -- Unmute sound
        manager.machine.sound.system_mute = false

        -- Reset frame processing function to do nothing when frame target is reached
        process_frame = function() end
      end
    end

    return
  end

  local stop = function()
    process_frame = function() end
  end




  -- Setup Plugin Options Menu
  -- emu.register_menu(menu_callback, menu_populate, _p("plugin-skipstartupframes", "Skip Startup Frames"))

  -- local menu_populate = function()

  --   local mute
  --   local blackout
  --   local debug

  --   local result = {}
  --   table.insert(result, { 'Skip Startup Frames', '', 'off' })
  --   table.insert(result, { '---', '', '' })
  --   -- table.insert(result, { _p("plugin-skipstartupframes", "Mute Sound"), mute, "off" })
  --   -- table.insert(result, { _p("plugin-skipstartupframes", "Black Out Screen"), blackout, "off" })
  --   -- table.insert(result, { _p("plugin-skipstartupframes", "Debug"), debug, "off" })

  --   return result
  -- end

  -- local menu_callback = function(index, entry)
  --   print(index, entry)
  -- end

  -- MAME 0.254 and newer compatibility check
  if emu.add_machine_reset_notifier ~= nil and emu.add_machine_stop_notifier ~= nil then

    startNotifier = emu.add_machine_reset_notifier(start)
    stopNotifier = emu.add_machine_stop_notifier(stop)

  else
    -- MAME version not compatible (probably can't even load LUA plugins anyways)
    print("Skip Startup Frames plugin requires at least MAME 0.254")
    return
  end

end

return skipstartupframes
