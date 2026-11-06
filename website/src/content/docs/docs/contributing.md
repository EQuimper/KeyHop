---
title: Contributing
description: Build KeyHop and this site from source.
---

KeyHop is [open source](https://github.com/EQuimper/KeyHop) under the MIT License.

## Build the app

Install the Xcode Command Line Tools (`xcode-select --install`) or Xcode with Swift 5.10 or newer, then run this from the repository root:

```sh
make dev
```

This builds and launches `dist/local/KeyHop.app` with an ad hoc signature. Quit any installed copy before testing global shortcuts, and allow Accessibility for the copy you're testing. macOS may ask again after a rebuild.

| Command | Result |
| --- | --- |
| `make dev` | Build and launch the local contributor copy |
| `make test` | Run the Swift tests |
| `make clean` | Clean build products and remove generated app bundles |

The Swift package is in `Sources/KeyHop`, with tests in `Tests/KeyHopTests`. For a shortcut or overlay change, run the tests and try the gesture in a real app.

## Edit this site

The site is in `website/` and built with Astro and Starlight. It needs Node 22.23.4 or newer.

```sh
cd website
npm install
npm run dev
```

Pages are Markdown files in `website/src/content/docs/docs`. Every push to `main` that changes the site publishes it.
