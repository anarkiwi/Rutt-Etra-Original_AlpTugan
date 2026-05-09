# Rutt-Etra-Analog Video Synth v2

[![Click to view see it in action](http://img.youtube.com/vi/NrvNLBjKUM0/0.jpg)](https://www.youtube.com/watch?v=NrvNLBjKUM0)

This repository is a newer version of [Rutt-Etra-analog-video-synth-implementation](https://github.com/alptugan/Rutt-Etra-analog-video-synth-implementation) uploaded in 2015. 

RE-Viser is a software implementation of the amazing Rutt-Etra analog video animation synthesizer from 70s. The Rutt-Etra analog video animation synthesizer was co-invented by Steve Rutt & Bill Etra as an analog computer for video raster manipulation. RE-Viser is written on C++ using open-source library openFrameworks. The application has built-in GUI (Graphical User Interface) to create Rutt & Etra Analog Video Synthesizer style visual effects on imported image/video files. This is an ongoing open-source project. The source files and former beta releases of the application can be downloaded from my [github.com/alptugan] account. I’ve been using Re-Viser on my personal audiovisual performances and updating the source codes time to time. Currently RE-Viser is only available for developers, not suitable for end-users. 


The code is still a little bit dirty and undocumented. Basically, the app has three modes; sitll image, moving image & video grabber modes. You can switch between the visual input modes setting the ```mode``` variable in ```testApp::setup()``` method. 

---------
## Features
- Control over Korg Nano MIDI device v1. To enable the remote control uncomment the following line in the header file; 
  
  ```// Uncomment the foloowing line to enbale midi - Input``` 
  
  ```//#define KORG_ENABLED```
- Enable load sound and play
- Load still images like .jpg, .png, etc.
- Load video files .mp4, .mov, etc.
- Enable built-in/external webcam input
- MIDI device input (Currently only Korg Nano Device is supported. However, if you are a developer, you can easly map your physical device via ofxMidi addon.)
- Export the generated visual as .jpg file
- Shader effects with ofxPostGlitch
- Record and load 3D space camera actions
- Convert the imported media to 3D mesh and view the generated image with virtual cam in 3D space.
- Keyboard interaction
- GUI interaction
------------
## Controls

The default window opens with the GUI hidden in the top-right and the
timeline hidden at the bottom — that is why a fresh launch shows only
"numbered rectangles". Press `t` to bring up the timeline and look at the
top-right of the window for the parameter panel.

### Keyboard

| Key            | Action                                                         |
| -------------- | -------------------------------------------------------------- |
| `t`            | Toggle the **timeline** (FX switches, camera-track keyframes). |
| `h`            | Toggle the **mouse cursor**.                                   |
| `d`            | Toggle **debug** (shows cursor + on-screen info).              |
| `f`            | Toggle **fullscreen**.                                         |
| `↓` / `↑`      | Next / previous video or image in the source folder.           |
| `space`        | Play / pause the current video.                                |
| `p`            | Toggle **point** vs lines mesh mode.                           |
| `w`            | Toggle **white** vs source-coloured mesh.                      |
| `r` / `R`      | Increase / decrease **Z-depth** multiplier.                    |
| `y` / `u`      | Increase / decrease the **vertical vertex distance**.          |
| `a`            | Add a camera keyframe (timeline visible only).                 |
| `l`            | Lock / unlock the camera to the camera track (timeline only).  |

### GUI panel (top-right, drag the title bar to move)

`RuttEtra_Options` exposes:

- **POST GLITCH FX** — enables the `ofxPostGlitch` shader chain.
- **Vertical / Horizontal Vertex Distance** — mesh sampling step (smaller = denser, slower).
- **Z-Depth Vertex** — extrusion amount driven by pixel luma.
- **sound Multiplier Fac**, **Sound Reactive Mode**, **Enable Video Sound** — sound-driven Z displacement.
- **Mesh Line Thickness**, **Show Mesh Frame**, **Set Color**, **POINT Mesh Mode**.
- **Sound Player** sub-panel — load an external `.wav`/`.aiff` from `bin/data/sounds/`, play/pause, volume.
- **FX Types** — toggleable post-process effects: *Converge, Glow, Shaker, Cut Slider, Twist, Outline, Noise, Slitscan, Swell, Invert, High Contrast, Blue/Green/Red Raise, Blue/Red/Green Invert*, plus a *Glow Effect Amount* slider.

The GUI can be dragged; the timeline shows along the bottom once toggled with `t`.

### Mouse / camera

The viewport uses an `ofEasyCam`-style controller (left-drag = orbit,
right-drag / scroll = dolly). When the timeline is showing and the camera
is *not* locked (`l`), mouse input drives the camera; when locked, the
camera follows the recorded track.

### Source folder & mode

Media lives in `data/ISP_haydarpasa/` (hard-coded at `src/ofApp.cpp:35-36`).
The Docker image picks the source kind from the `MODE` build-arg
(`VIDEO` default → `.mov`/`.mp4` lowercase; `IMAGE` → `.jpg`/`.png`; `CAM`
→ webcam at 320×240). Bind-mount your media folder onto
`/app/bin/data/ISP_haydarpasa` at run-time.

------------
## Dependecies
- ofxCameraMove
- ofxFFT
- ofxGui
- ofxKorgNanoKontrol
- ofxMidi
- ofxMotionBlurCamera
- ofxOsc
- ofxPostGlitch
- ofxTweener
- ofxXmlSettings

---------

## Todo
  - Execute main alogrithm in the GPU via shaders. Any suggestion or help are highly apprecieted.
  - Improve user interaction. Camera movement can be adapted to ofxTimeline.
  - Finish documentation. 
  - <s>Enable sound reactive mode for loaded sound samples or/and microphone input data</s>
  - Create Enum structure for mode selection.