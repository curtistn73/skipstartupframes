-- Current plugin directory
local plugin_directory = manager.plugins['skipstartupframes'].directory

-- Load plugin metadata
local json = require('json')
local skipstartupframes = json.parse(io.open(plugin_directory .. '/plugin.json'):read('*a')).plugin

-- Notifiers
local startNotifier = nil
local stopNotifier = nil
local menuNotifier = nil

local slowMotionRate = 0.3

-- Default options
local defaultoptions = {
  blackout = true,
  mute = true,
  parentFallback = true,
  debug = false,
  debugSlowMotion = false
}

-- Load options from options.cfg
local load_options = function()
  local options = {}

  -- Open options file for reading
  local options_file = io.open(plugin_directory .. "/options.cfg", "r")

  -- If options file doesn't exist, use default options
  if options_file == nil then
    options = defaultoptions
  else
    -- Parse options file
    options = json.parse(options_file:read("*a"))

    for k,v in pairs(defaultoptions) do
      -- Fix incorrect types and add missing options
      if (options[k] == nil or type(options[k]) ~= type(v)) then
        options[k] = v
      end
    end
  end

  options_file:close()

  return options
end

-- Save options to options.cfg
local save_options = function(options)

  -- Open options file for reading
  local options_file = io.open(plugin_directory .. "/options.cfg", "w")

  local data = json.stringify(options, {indent = true})
  options_file:write(data)
  options_file:close()
end

function skipstartupframes.startplugin()
  local options = load_options()

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

  -- Run when MAME begins emulation
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

    -- Variable references
    local screens = manager.machine.screens
    local video = manager.machine.video
    local sound = manager.machine.sound

    -- Enable throttling
    if not options.debug then
      video.throttled = false
    end

    -- Mute sound
    if options.mute and not options.debug then
      sound.system_mute = true
    end

    -- Slow-Motion Debug Mode
    if options.debug and options.debugSlowMotion then
      video.throttle_rate = slowMotionRate
    end

    -- Starting frame
    local frame = 0

    -- Process each frame
    process_frame = function()
      -- Draw debug frame text if in debug mode
      if options.debug and #screens > 0 then
        for _,screen in pairs(screens) do
          screen:draw_text(0, 0, "ROM: "..rom.." Frame: "..frame, 0xffffffff, 0xff000000)
        end
      end

      -- Black out screen only when not in debug mode
      if options.blackout and not options.debug and #screens > 0 then
        for _,screen in pairs(screens) do
          screen:draw_box(0, 0, screen.width, screen.height, 0x00000000, 0xff000000)
        end
      end

      -- Iterate frame count only when not in debug mode and machine is not paused
      if not options.debug or not manager.machine.paused then
        frame = frame + 1
      end

      -- Frame target reached
      if not options.debug and frame >= frameTarget then

        -- Re-enable throttling
        video.throttled = true

        -- Unmute sound
        sound.system_mute = false

        -- Reset throttle rate
        video.throttle_rate = 1

        -- Reset frame processing function to do nothing when frame target is reached
        process_frame = function() end
      end
    end

    return
  end

  -- Run when MAME stops emulation
  local stop = function()
    process_frame = function() end
  end

  -- Option menu variables
  local menuSelection = 3
  local blackoutIndex
  local muteIndex
  local parentFallbackIndex
  local debugIndex
  local debugSlowMotionIndex

  -- Option menu creation/population
  local menu_populate = function()
    local result = {}

    table.insert(result, { 'Skip Startup Frames', '', 'off' })
    table.insert(result, { '---', '', '' })

    table.insert(result, { _p("plugin-skipstartupframes", "Black out screen during startup"), options.blackout and 'Yes' or 'No', 'lr' })
    blackoutIndex = #result

    table.insert(result, { _p("plugin-skipstartupframes", "Mute audio during startup"), options.mute and 'Yes' or 'No', 'lr' })
    muteIndex = #result

    table.insert(result, { _p("plugin-skipstartupframes", "Fallback to parent rom startup frames"), options.parentFallback and 'Yes' or 'No', 'lr' })
    parentFallbackIndex = #result

    table.insert(result, { _p("plugin-skipstartupframes", "Debug Mode"), options.debug and 'Yes' or 'No', 'lr' })
    debugIndex = #result

    table.insert(result, { _p("plugin-skipstartupframes", "Slow Motion during Debug Mode"), options.debugSlowMotion and 'Yes' or 'No', 'lr' })
    debugSlowMotionIndex = #result

    return result, menuSelection
  end

  -- Option menu event callback
  local menu_callback = function(index, event)
    menuSelection = index

    -- Blackout Screen Option
    if index == blackoutIndex then
      if event == 'left' or event == 'right' then
        options.blackout = not options.blackout
        save_options(options)
      end
      return true

    -- Mute Audio Option
    elseif index == muteIndex then
      if event == 'left' or event == 'right' then
        options.mute = not options.mute
        save_options(options)
      end
      return true

    -- Parent ROM Fallback Option
    elseif index == parentFallbackIndex then
      if event == 'left' or event == 'right' then
        options.parentFallback = not options.parentFallback
        save_options(options)
      end
      return true

    -- Debug Mode Option
    elseif index == debugIndex then
      if event == 'left' or event == 'right' then
        options.debug = not options.debug
        save_options(options)
      end
      return true

    -- Debug Slow Motion Option
    elseif index == debugSlowMotionIndex then
      if event == 'left' or event == 'right' then
        options.debugSlowMotion = not options.debugSlowMotion
        save_options(options)
      end
      return true

    end
  end

  -- MAME 0.254 and newer compatibility check
  if emu.add_machine_reset_notifier ~= nil and emu.add_machine_stop_notifier ~= nil then

    startNotifier = emu.add_machine_reset_notifier(start)
    stopNotifier = emu.add_machine_stop_notifier(stop)
    menuNotifier = emu.register_menu(menu_callback, menu_populate, _p("plugin-skipstartupframes", "Skip Startup Frames"))

  else
    -- MAME version not compatible (probably can't even load LUA plugins anyways)
    print("Skip Startup Frames plugin requires at least MAME 0.254")
    return
  end

end

return skipstartupframes
