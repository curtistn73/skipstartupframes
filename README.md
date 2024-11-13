# MAME Skip Startup Frames Plugin

This is a LUA Plugin for [MAME](https://www.mamedev.org/) that automatically skips the startup frames for roms when you start them.

## What does it do?

The plugin temporarily unthrottles the framerate of a game at startup until a certain number of frames has been reached and then returns the framerate back to normal. The plugin also temporarily mutes the audio and blacks out the screen. The faster the computer, the faster the unthrottled startup time will be.

## `galaga` startup example

| Before: ~12 sec startup time               | After: ~1 sec startup time              |
| ------------------------------------------ | --------------------------------------- |
| ![normal galaga startup](media/before.gif) | ![fast galaga startup](media/after.gif) |

## Installation instructions

1. Download `skipstartupframes.zip` from the [latest release](https://github.com/Jakobud/skipstartupframes/releases)
2. Unzip the file into the MAME `plugins` directory
   - Example: `c:\mame\plugins\skipstartupframes\`
3. Enable the plugin in one of the following ways:

   - Enable `Skip Startup Frames` in MAME's Plugin Menu (Restarting MAME may be required)
   - Add `skipstartupframes` to the `plugin` option in `mame.ini`
   - Run MAME with the command-line option `-plugin skipstartupframes`

   ![MAME plugin toggle menu](media/plugin-menu.jpg)

## 2004 BYOAC Legacy

Skip Startup Frames is not a new concept and not my idea. It was actually originally a MAME C++ patch that originated back in [early 2004](https://www.retroblast.com/archives/a-200403.html) by Alan Kamrowski II. It made it's way into some long-forgotten forks of MAME like NoNameMAME and BuddaMAME but has now been reborn as an easy-to-install MAME Plugin!

## How does it work?

Every rom has a different startup procedure and different number of startup frames that need to be skipped. The solution to this problem is an included file called `ssf.txt` which is a simple text file containing rom names and frames to be skipped. This plugin reads in the file and determines how many frames to skip for the loaded rom.

```
...
radm,14
radr,79
radrad,439
raflesia,15
ragnagrd,243
raiden,42
raiden2,30
raiders,550
raiders5,1443
raimais,529
rainbow,376
rallybik,517
rallyx,760
...
```

## `ssf.txt` Contributions

`ssf.txt` is an old file that was [created back in 2004](https://forum.arcadecontrols.com/index.php/topic,48674.msg) and was the culmination of work by many members of the [BYOAC forum](https://forum.arcadecontrols.com/) who examined 1000's of games and recorded the correct number of frames to be skipped.

The majority of startup frames are most likely still accurate from 2004 but a lot can change in 20+ years. Some rom's might have been changed or redumped, new roms were added to MAME, etc. If you find any startup frames in `ssf.txt` to be inaccurate or missing, you can easily contribute changes to the project:
[CLICK HERE TO EDIT `ssf.txt`](https://github.com/Jakobud/skipstartupframes/edit/main/ssf.txt). Make your edits, commit your changes and then create a pull request into the `develop` branch. I will examine the change and either approve or reject it.

## Debug Mode

In order to facilitate determining accurate startup frames to use in `ssf.txt` the plugin includes an optional "debug mode" that prints out the frame numbers on the screen. See the **Options section** for more details.

![Skip Startup Frames Debug Mode](media/debug.gif)

## Options

| In-Game Menu                              |                                                               |
| ----------------------------------------- | ------------------------------------------------------------- |
| ![Mame In-Game Menu](media/game-menu.png) | ![Skip Startup Frames Options](media/plugin-options-menu.png) |

- `blackout` - _Yes/No_

  - Whether or not to black out the screen while skipping startup frames.
  - The plugin still renders the startup frames. This option just makes the screen black during the startup. Turn this option off if you want to see the unthrottled startup frames.
  - Default: `Yes`

- `mute` - _Yes/No_

  - Whether or not to mute the audio while skipping startup frames.
  - Default: `Yes`

- `parentFallback` - _Yes/No_

  - If a rom is a clone and is not found in `ssf.txt`, fallback to using the parent rom's startup frames from `ssf.txt`.
  - Default: `Yes`

- `debug` - _Yes/No_

  - Enable debug mode to show frame numbers in game in order to help determine accurate startup frame values to use for roms.
  - Default: `No`

- `debugSlowMotion` - _Yes/No_
  - Used to slowdown game speed/playback while in debug mode.
  - Default: `No`
