---
title: Troubleshooting
description: What KeyHop's messages mean and how to fix common problems.
---

## Messages

KeyHop reports problems in the pill at the bottom of the window.

| Message | What to do |
| --- | --- |
| No controls found | The app exposes nothing KeyHop can label. Press <kbd>Space</kbd> for the [grid](/docs/grid/). |
| Finding controls timed out | The app took more than 2 seconds to respond. Press <kbd>Space</kbd> for the grid, or try again. |
| Couldn’t read this window | Press <kbd>Space</kbd> for the grid, or try another window. |
| Control moved | The control changed position after the labels appeared. Press <kbd>⌃J</kbd> again. |
| Target is covered | Another window is over the target. Bring the window forward and try again. |
| Allow Screen Recording for KeyHop, then try again. | Allow [Screen Recording](/docs/permissions/#screen-recording), then restart KeyHop if macOS asks. |
| No visible words found | KeyHop found no readable text in the window. |
| Window reading timed out | Reading the window took more than 5 seconds. Try again. |

## The shortcut does nothing

- **Check Accessibility.** If the crosshair menu shows **Allow Accessibility…**, KeyHop doesn't have access yet. See [Permissions](/docs/permissions/).
- **Check the app isn't paused.** If the crosshair menu shows **Enable in** and the app's name, [turn it back on](/docs/settings/#pause-in-an-app).
- **Check the window.** KeyHop doesn't run on its own Settings window, and it beeps if the app has no window it can use.

## Access is on, but KeyHop still doesn't respond

macOS grants access per copy of the app. If you have more than one copy, or you just rebuilt or updated KeyHop, remove it from the Accessibility list, add the copy you're running, and restart it.

## Labels don't appear on page content

Browsers can take a moment to expose page content. Press <kbd>Esc</kbd>, wait for the page to finish loading, and press <kbd>⌃J</kbd> again.

## The copied text isn't what the preview showed

The app decides what a drag selects. See [what affects the result](/docs/select-text/#what-affects-the-result).

## Report a problem

[Open an issue](https://github.com/EQuimper/KeyHop/issues/new) with your macOS version, the target app, the shortcut you pressed, and what appeared on screen.
