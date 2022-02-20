# Penc
Penc is yet another window manager app for macOS. Instead of complicated keyboard shortcuts, Penc is designed for trackpad usage.

![Showcase](website/assets/videos-concat.gif?raw=true)

## Usage

- Double press and hold Command Key (⌘) to activate Penc
  - Drag with two fingers to move the window
  - Pinch with two fingers to resize the window
    - Pinch vertically to make the window taller/shorter, or horizontally to make it wider/thinner
  - Fast swipe with two fingers to snap the window into halves/quarters
- Release Command Key (⌘) to take effect

## Installation

There are two recommended options for installation.

**Homebrew**

`$ brew install penc --cask`

**Download Release from Github**

- Download latest dmg file from [Releases page](https://github.com/dgurkaynak/Penc/releases)
- Mount and open that dmg file
- Copy the application into `Applications` folder
- Run the application from `Applications` folder
- Penc will request to access accessibility features on first run
- Go to System Preferences > Security & Privacy > Privacy > Accessibility, allow Penc
- Run the application again

## System Requirements

Penc supports macOS High Sierra (10.13) and above.

## Common Issues

### Pinch to resize is not working

In order to detect pinch gesture, `Zoom in or out` option must be turned on under the `System Preferences` > `Trackpad` > `Scroll & Zoom`

## Build & Running

```bash
# Install dependencies
pod install

# Open workspace
open Penc.xcworkspace
```
