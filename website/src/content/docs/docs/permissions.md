---
title: Permissions
description: Why KeyHop asks for Accessibility and Screen Recording access.
---

KeyHop needs one permission to click and a second to select text. Allow the copy of KeyHop you launched, because macOS treats each copy as a separate app.

## Accessibility

Accessibility lets KeyHop receive its global shortcuts, find the controls in the active window, and click or drag there.

macOS asks when you first open KeyHop. To allow it later, choose **Allow Accessibility…** from the crosshair menu, or go to **System Settings → Privacy & Security → Accessibility**.

## Screen Recording

Screen Recording is called **Screen & System Audio Recording** on some macOS versions. macOS asks the first time you press <kbd>⌃⇧J</kbd>. You don't need it for clicking.

KeyHop captures only the target window and finds the words in it with Apple Vision, on your Mac. The image stays in memory and isn't saved.

## Restarting after you allow access

If macOS asks you to restart KeyHop, choose **Quit KeyHop** from the crosshair menu, then run:

```sh
open -a KeyHop
```

## Network access

KeyHop makes no network requests. It has no account, analytics, or update check. Homebrew handles updates.
