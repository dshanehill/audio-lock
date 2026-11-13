# Audio Lock

A tiny Mac app that keeps your sound where you put it.

When you connect a TV or another display (for example with AirPlay / Screen Mirroring), macOS often switches your sound to that TV on its own. Audio Lock switches it straight back to the speakers or headphones you were using, usually before you notice.

- No menus, no windows, no settings. It runs quietly in the background.
- Changes you make yourself in **System Settings → Sound** are kept. Only switches caused by a display or device connecting are undone.
- Starts automatically when you log in.
- Open Audio Lock again at any time to hear which device it is holding, or to quit it.

## Install

Open **Terminal** and paste this line, then press Return:

```
curl -fsSL https://raw.githubusercontent.com/dshanehill/audio-lock/main/install.sh | bash
```

This builds Audio Lock on your Mac from this source code, puts it in Applications and starts it. If your Mac asks to install Apple's command line tools, accept, wait for that to finish and paste the line again.

Or download **AudioLock.zip** from the [latest release](https://github.com/dshanehill/audio-lock/releases/latest), unzip it and move **Audio Lock** to Applications. The first time, Control-click it and choose **Open**, because the app is not notarized by Apple.

## Requirements

macOS 13 Ventura or later, Apple silicon or Intel.

## Build it yourself

```
bash build.sh
```

The app appears in `build/Audio Lock.app`.

## How it works

Audio Lock listens for changes to the Mac's default output device and alert-sound device, and for displays or audio devices being added or removed. If the sound device changes within a few seconds of a display or device change, Audio Lock sets it back to the locked device. A change with no display event around it is treated as your own choice and becomes the new lock.

## License

MIT
