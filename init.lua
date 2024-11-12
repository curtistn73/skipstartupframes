-- Current plugin directory
local plugin_directory = manager.plugins['skipstartupframes'].directory

-- Load plugin metadata
local json = require('json')
local skipstartupframes = json.parse(io.open(plugin_directory .. '/plugin.json'):read('*a')).plugin

-- Notifiers
local startNotifier = nil
local stopNotifier = nil

function skipstartupframes.startplugin()
  local options = {}

  -- Default options
  local defaultoptions = {
    blackout = true,
    mute = true,
    parentFallback = true,
    debug = false,
    debugSpeed = 0.25
  }

  -- Open options file
  local options_path = plugin_directory .. "/options.cfg"
  local options_file = io.open(options_path, "r")

  -- If options file doesn't exist, use default options
  if options_file == nil then
    options = defaultoptions
  else
    -- Parse options file
    options = json.parse(options_file:read("*a"))

    -- Add any missing options from defaults and fix any wrong types
    for k,v in pairs(defaultoptions) do
      if (options[k] == nil or type(options[k]) ~= type(v)) then
        options[k] = v
      end
    end
  end

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
    if frameTarget == nil and not options.debug then

      -- If parent rom fallback is disabled, don't do anything
      if not options.parentFallback then
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

    -- Enable throttling
    if not options.debug then
      manager.machine.video.throttled = false
    end

    -- Mute sound
    if options.mute and not options.debug then
      manager.machine.sound.system_mute = true
    end

    -- Slow-Motion Debug Mode
    if options.debug and options.debugSpeed ~= 1 then
      manager.machine.video.throttle_rate = options.debugSpeed
    end

    -- Starting frame
    local frame = 0

    -- Process each frame
    process_frame = function()
      -- Draw debug frame text if in debug mode
      if options.debug then
        screen:draw_text(0, 0, "ROM: "..rom.." Frame: "..frame, 0xffffffff, 0xff000000)
      end

      -- Black out screen only when not in debug mode
      if options.blackout and not options.debug then
        screen:draw_box(0, 0, screen.width, screen.height, 0x00000000, 0xff000000)
      end

      -- Iterate frame count only when not in debug mode and machine is not paused
      if not options.debug or not manager.machine.paused then
        frame = frame + 1
      end

      -- Frame target reached
      if not options.debug and frame >= frameTarget then

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
