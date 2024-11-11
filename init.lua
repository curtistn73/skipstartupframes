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

function skipstartupframes.startplugin()

  local frames = {}

  -- Find the frames file
  local frames_path = plugin_directory .. "/ssf.txt"
  local frames_file = io.open(frames_path, "r")

  -- Read in and parse the frames file
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

  -- If no ssf.txt file found, don't do anything
  if frames_file == nil then
    print("No ssf.txt file found")
    return
  end

  -- Notifiers
  local startNotifier = nil
  local stopNotifier = nil

  -- function draw_text_overlay(screen, x, y, text)
  --   screen:draw_text(x, y, text, 0xffffffff, 0xff000000)
  -- end

  -- Initialize frame processing function to do nothing
  local process_frame = function() end

  -- Trampoline function to process each frame
  emu.register_frame_done(function()
    -- frame = frame + 1
    -- process_frame(screen, centerX, centerY, "ROM: "..rom.." Frame: "..frame)
    process_frame()
  end)

  -- Check MAME version compatibility of notifier functions
  -- MAME 0.254 and newer compatibility
  if emu.add_machine_reset_notifier ~= nil and emu.add_machine_stop_notifier ~= nil then

    startNotifier = emu.add_machine_reset_notifier(function()

      rom = emu.romname()

      -- If no rom is loaded, don't do anything
      if rom == "___empty" then
        return
      end

      -- Fetch frame count for rom from ssr.txt
      frameTarget = frames[tostring(rom)]

      -- If the rom was not found in SSF.txt, don't do anything
      if frameTarget == nil then
        return
      end

      -- Setup frame placement and counter
      screen = manager.machine.screens[':screen']
      -- centerX = screen.width / 2
      -- centerY = screen.height / 2

      -- Enable throttling
      manager.machine.video.throttled = false

      -- Mute sound
      manager.machine.sound.system_mute = true

      frame = 0

      -- Process each frame
      process_frame = function()
        -- Black out screen
        screen:draw_box(0, 0, screen.width, screen.height, 0x00000000, 0xff000000)

        -- Iterate frame count
        frame = frame + 1

        -- Frame target reached
        if (frame >= frameTarget) then

          -- Re-enable throttling
          manager.machine.video.throttled = true

          -- Unmute sound
          manager.machine.sound.system_mute = false

          -- Reset frame processing function to do nothing when frame target is reached
          process_frame = function() end
        end
      end

      return
    end)

    -- Reset frame processing function to do nothing when emulation ends
    stopNotifier = emu.add_machine_stop_notifier(function()
      process_frame = function() end
    end)

  -- MAME 0.253 and older compatibility
  elseif emu.register_start ~= nil and emu.register_stop ~= nil then

    start_handler = emu.register_start
    stop_handler = emu.register_stop
    frame_handler = emu.register_frame

  else
    -- MAME version not compatible (probably can't even load LUA plugins anyways)
    print("Skip Startup Frames plugin is not compatible with this version of MAME.")
    return
  end

end

return skipstartupframes
