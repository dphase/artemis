# Artemis II Tracker - iOS App Plan

## Overview

A realtime 3D visualization of Earth, the Moon, and the Artemis II spacecraft on its free-return lunar flyby trajectory. Built with SceneKit for the 3D scene and SwiftUI for the surrounding UI.

---

## Architecture

```
Artemis/
  App/
    ArtemisApp.swift              # App entry point, dark color scheme
    ContentView.swift             # Root view: SceneKit viewport + HUD overlay + timer loop
    HUDView.swift                 # Mission telemetry: MET, phase, distances, velocity
    TimeControlsView.swift        # Play/pause, timeline scrubber, reset-to-now
    PrivacyPolicyView.swift       # Static privacy policy sheet
  Scene/
    OrbitSceneController.swift    # Owns the SCNScene; creates and updates all nodes
    StarfieldGenerator.swift      # Procedural starfield texture (80K stars, seeded RNG)
  Bodies/
    EarthNode.swift               # Earth sphere + diffuse texture + atmosphere glow + axial tilt + rotation
    MoonNode.swift                # Moon sphere + diffuse texture (Blinn shading)
    SpacecraftNode.swift          # Purple core dot + 4 concentric teal pulsing rings
    TrajectoryNode.swift          # Full mission path: past (magenta fade-in) / future (tan) line split
  Data/
    MissionTimeline.swift         # Mission dates, phases, 40+ trajectory waypoints
    TrajectoryInterpolator.swift  # Catmull-Rom spline interpolation along the path
    EphemerisProvider.swift       # Analytical lunar ephemeris (Keplerian + perturbations)
```

Build system: **XcodeGen** (`project.yml`) for the iOS app, **SwiftPM** (`Package.swift`) for data-layer-only unit tests on macOS.

Target: **iOS 26+**, Swift 6.0, SwiftUI + SceneKit. iPhone-only, portrait. No external dependencies.

Bundle ID: `com.project93.Artemis` — Product name: **ArtemisTrack**

---

## Implementation Status

### Phase 1: Scene Foundation — COMPLETE

| Item | Status | Notes |
|---|---|---|
| 1.1 SceneKit viewport in SwiftUI | ✅ Done | `SceneViewContainer` (UIViewRepresentable), 4X MSAA, built-in allowsCameraControl |
| 1.2 Earth | ✅ Done | Radius 1.0, diffuse texture + blue tint multiply, self-illumination 0.85, atmosphere glow shell (radius 1.015) |
| 1.3 Moon | ✅ Done | Radius 0.273, fixed position (0, -58.5, 3), diffuse texture, Blinn shading |
| 1.4 Lighting | ✅ Done | Directional sun (intensity 2500, from 30,20,80) + ambient (intensity 1000) |
| 1.5 Camera | ✅ Done | Position (0, 0, 75), lookAt (0, -33, 0), built-in orbit/zoom via allowsCameraControl, reset-camera button |
| 1.6 Starfield | ✅ Done | Procedurally generated (StarfieldGenerator, 2048x2048, 80K stars), applied to large sphere, slow rotation |

**Differences from original plan:**
- No separate `CameraController.swift` — uses SceneKit's built-in `allowsCameraControl` instead of custom gesture handling
- Starfield is a procedural texture on a sphere, not a skybox cubemap
- Earth uses self-illumination + blue tint rather than specular/normal/night-lights maps
- Moon is at a fixed position, not dynamically computed

### Phase 2: Trajectory Path — COMPLETE

| Item | Status | Notes |
|---|---|---|
| 2.1 Mission data | ✅ Done | 40+ waypoints across 7 phases, 10.5-day mission, Catmull-Rom spline with 1200 interpolated points |
| 2.2 Trajectory rendering | ✅ Done | SCNGeometrySource + SCNGeometryElement with `.line` primitives, offset duplicates for thickness |
| 2.3 Past/future trail split | ✅ Done | Past: magenta with quadratic fade-in alpha. Future: tan/beige, semi-transparent. Split updated each frame |

**Mission dates:** Launch April 1, 2026 22:36 UTC — Splashdown ~April 12, 2026

### Phase 3: Spacecraft Indicator — COMPLETE

| Item | Status | Notes |
|---|---|---|
| 3.1 Position interpolation | ✅ Done | `TrajectoryInterpolator` with Catmull-Rom splines, velocity via finite differences, parameter 0→1 |
| 3.2 Spacecraft node | ✅ Done | Purple/magenta core sphere (radius 0.12) + 4 concentric teal rings with staggered pulse animations (5.5s cycle, additive blending) |
| 3.3 Position updates | ✅ Done | Timer at 30 FPS in ContentView, calls `sceneController.update(for: missionTime)` |

**Differences from original plan:**
- Spacecraft is purple/magenta with teal pulse rings, not white/gold with simple glow
- Update rate is 30 FPS (not 1 Hz as originally planned)

### Phase 4: Ephemeris & Time Controls — PARTIAL

| Item | Status | Notes |
|---|---|---|
| 4.1 Analytical Moon ephemeris | ✅ Done | `EphemerisProvider` with Keplerian elements, eccentricity correction, node precession. **However: not wired into the scene** — Moon stays at fixed position |
| 4.2 JPL Horizons API | ❌ Not started | Stretch goal |
| 4.3 Time controls | ✅ Done | Play/pause toggle, timeline slider (launch to splashdown), reset-to-now button. No speed multiplier yet |

**Remaining work:**
- Wire `EphemerisProvider.moonPosition(at:)` into `OrbitSceneController.update(for:)` for dynamic Moon positioning
- Add speed multiplier (1x, 10x, 100x, 1000x)

### Phase 5: HUD & Polish — PARTIAL

| Item | Status | Notes |
|---|---|---|
| 5.1 HUD overlay | ✅ Done | MET (T+/T- format), phase label, Earth/Moon distances (miles), velocity (mph), glassmorphism style |
| 5.2 Labels in 3D | ❌ Not started | No Earth/Moon text labels in the scene |
| 5.3 Visual polish | ⚡ Partial | Earth atmosphere glow ✅, spacecraft pulse animation ✅. No bloom/HDR post-processing, no camera transition presets, no launch animation |

### Phase 6: Live Tracking — NOT STARTED

| Item | Status | Notes |
|---|---|---|
| 6.1 NASA AROW integration | ❌ Not started | Stretch goal, mission-dependent |
| 6.2 SPICE kernel support | ❌ Not started | Stretch goal |

---

## Build Order & Milestones

| Step | Deliverable | Status |
|---|---|---|
| 1 | Xcode project, SceneKit viewport in SwiftUI, starfield background | ✅ |
| 2 | Earth with textures, rotation, lighting | ✅ |
| 3 | Moon with texture, correct relative position and size | ✅ |
| 4 | Camera orbit/zoom controls | ✅ |
| 5 | Hardcoded trajectory waypoints + spline interpolation | ✅ |
| 6 | Trajectory line rendered in scene | ✅ |
| 7 | Spacecraft indicator dot on the path | ✅ |
| 8 | Past/future trail split coloring | ✅ |
| 9 | Time controls (scrubber, play/pause) | ✅ |
| 10 | HUD overlay with mission stats | ✅ |
| 11 | Wire EphemerisProvider for dynamic Moon positioning | ⬜ |
| 12 | Time speed multiplier (1x–1000x) | ⬜ |
| 13 | 3D labels (Earth, Moon) | ⬜ |
| 14 | Bloom/HDR post-processing | ⬜ |
| 15 | Camera preset transitions (Earth, Moon, full trajectory) | ⬜ |
| 16 | JPL Horizons API integration (optional) | ⬜ |
| 17 | Live AROW tracking (stretch, mission-dependent) | ⬜ |

---

## Test Coverage

Two test suites:

- **ArtemisLogicTests** (SwiftPM, macOS) — 21 tests covering MissionTimeline, TrajectoryInterpolator, EphemerisProvider, MissionPhase
- **ArtemisTests** (Xcode, iOS) — 23 tests, same data-layer coverage + TrajectoryPathNode rendering tests

Both use Swift Testing (`@Suite`, `@Test`, `#expect`).

---

## Key Design Decisions

1. **SceneKit over RealityKit**: SceneKit gives us finer control over custom geometries (trajectory lines), shader modifiers (glow effects), and camera behavior. RealityKit is optimized for AR, which we don't need.

2. **Normalized scale**: Earth radius = 1.0 scene unit. Everything else is proportional. Real distances (Earth-Moon ≈ 60 Earth radii) are preserved.

3. **Hardcoded trajectory**: Pre-defined waypoints interpolated with Catmull-Rom splines rather than real-time orbital mechanics. Simpler, more predictable, sufficient for visualization.

4. **No external dependencies**: Pure Apple frameworks (SceneKit, SwiftUI, Foundation). The app works fully offline.

5. **XcodeGen + SwiftPM dual build**: `project.yml` for the full iOS app, `Package.swift` for data-layer tests runnable without a simulator.

---

## Asset Requirements

| Asset | Status | Notes |
|---|---|---|
| Earth diffuse texture | ✅ In use | `earth_diffuse.jpg` |
| Moon diffuse texture | ✅ In use | `moon_diffuse.jpg` |
| Starfield | ✅ Procedural | Generated at runtime by `StarfieldGenerator` |
| Earth normal map | ⬜ Not used | Could enhance terrain relief |
| Earth specular map | ⬜ Not used | Could add ocean reflectivity |
| Earth night lights | ⬜ Not used | Could add city lights emission |
