---
title: Install
description: Install, update, and remove KeyHop.
---

KeyHop runs on Apple silicon and Intel Macs with macOS 14 or later. Releases are signed and notarized.

## Homebrew

```sh
brew install --cask equimper/tap/keyhop
open -a KeyHop
```

This installs from the [EQuimper/homebrew-tap](https://github.com/EQuimper/homebrew-tap) tap.

## Direct download

1. Download the latest `.zip` from [GitHub Releases](https://github.com/EQuimper/KeyHop/releases/latest).
2. Unzip it and move `KeyHop.app` to your Applications folder.
3. Open KeyHop.

## Update

```sh
brew update && brew upgrade --cask equimper/tap/keyhop
```

Your installed version is at the bottom of KeyHop Settings. [Release notes](https://github.com/EQuimper/KeyHop/releases) are on GitHub.

## Remove

Choose **Quit KeyHop** from the crosshair menu, then:

```sh
brew uninstall --cask equimper/tap/keyhop
```

KeyHop stays listed under **Privacy & Security** until you remove it there.
