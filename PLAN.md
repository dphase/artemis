# Artemis II Tracker - iOS App Plan

## Overview

A realtime 3D visualization of Earth, the Moon, and the Artemis II spacecraft on its free-return lunar flyby trajectory. Built with SceneKit for the 3D scene and SwiftUI for the surrounding UI.

---

## Architecture

```
Artemis/
  App/
    ArtemisApp.swift              # App entry point, dark color scheme
    ContentView.swift             # Root view: SceneKit viewport + HUD overlay + timer loop + splash screen
    GlassModifier.swift           # Cross-SDK Liquid Glass wrapper (iOS 26 glass / older ultraThinMaterial)
    HUDView.swift                 # Mission telemetry: MET, phase, distances, velocity
    TimeControlsView.swift        # Play/pause, timeline scrubber, reset-to-now (resets camera)
    PrivacyPolicyView.swift       # Static privacy policy sheet
  Scene/
    OrbitSceneController.swift    # @MainActor; owns the SCNScene; creates and updates all nodes
    StarfieldGenerator.swift      # Procedural starfield texture (80K stars, seeded RNG)
  Bodies/
    EarthNode.swift               # Earth sphere + diffuse + night lights emission + atmosphere glow + sidereal rotation
    MoonNode.swift                # Moon sphere + diffuse texture (Blinn shading)
    SpacecraftNode.swift          # Purple core dot + 4 concentric teal pulsing rings
    TrajectoryNode.swift          # Full mission path: past (magenta fade-in) / future (tan) line split
  Data/
    MissionTimeline.swift         # Mission dates, phases, 40+ trajectory waypoints incl. 28.5° inclined parking orbit
    TrajectoryInterpolator.swift  # Catmull-Rom spline interpolation along the path
    EphemerisProvider.swift       # Analytical lunar ephemeris (Keplerian + perturbations)
  Resources/
    Assets.xcassets/              # AppIcon, SplashImage (@1x/@2x/@3x), earth textures, moon texture
```

Build system: **XcodeGen** (`project.yml`) for the iOS app, **SwiftPM** (`Package.swift`) for data-layer-only unit tests on macOS.

Target: **iOS 17.0+** (Liquid Glass on iOS 26+ via compile-time `#if canImport(FoundationModels)` gate), Swift 6.0, SwiftUI + SceneKit. iPhone-only, portrait. No external dependencies.

Bundle ID: `com.project93.artemis` — Product name: **ArtemisTrack**

Version: **1.1.0** (build 4)

---

## CI/CD

- **TestFlight** (`.github/workflows/testflight.yml`): Triggers on push to `main` + manual dispatch. Uses XcodeGen, automatic cloud signing with App Store Connect API key (Admin role), auto-incrementing build numbers via `github.run_number`. Archive → export with `destination: upload` → TestFlight.
- **GitHub Secrets**: `TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`
- **Key requirement**: The API key must have **Admin** role for cloud-managed distribution signing to work.

---

## Implementation Status

### Phase 1: Scene Foundation — COMPLETE

| Item | Status | Notes |
|---|---|---|
| 1.1 SceneKit viewport in SwiftUI | ✅ Done | `SceneViewContainer` (UIViewRepresentable), 4X MSAA, built-in allowsCameraControl |
| 1.2 Earth | ✅ Done | Radius 1.0, diffuse texture, night lights emission map, atmosphere glow shell, sidereal rotation synced to mission time |
| 1.3 Moon | ✅ Done | Radius 0.273, fixed position (0, -58.5, 3), diffuse texture, Blinn shading |
| 1.4 Lighting | ✅ Done | Directional sun (intensity 2500, from 30,20,80) + ambient (intensity 200) |
| 1.5 Camera | ✅ Done | Position (-0.7, -71.0, 24.1), euler (0.83, -0.03, 0.0), FOV 60, allowsCameraControl with animated reset |
| 1.6 Starfield | ✅ Done | Procedurally generated (StarfieldGenerator, 2048x2048, 80K stars), applied to large sphere, slow rotation |
| 1.7 Splash screen | ✅ Done | Full-bleed image overlay on launch, auto-dismiss after 2.5s or tap, SwiftUI overlay (not storyboard) |

**Differences from original plan:**
- No separate `CameraController.swift` — uses SceneKit's built-in `allowsCameraControl` instead of custom gesture handling
- Starfield is a procedural texture on a sphere, not a skybox cubemap
- Moon is at a fixed position, not dynamically computed
- Camera reset animates `scnView.pointOfView` (not cameraNode) since `allowsCameraControl` uses its own internal copy
- Earth rotation uses sidereal day (86,164.1s) + GMST at J2000 epoch for accurate time sync
- Night lights via emission map on Earth surface, self-illumination reduced to 0.05

### Phase 2: Trajectory Path — COMPLETE

| Item | Status | Notes |
|---|---|---|
| 2.1 Mission data | ✅ Done | 40+ waypoints across 7 phases, 10.5-day mission, Catmull-Rom spline with 1200 interpolated points |
| 2.2 Trajectory rendering | ✅ Done | SCNGeometrySource + SCNGeometryElement with `.line` primitives, offset duplicates for thickness |
| 2.3 Past/future trail split | ✅ Done | Past: magenta with quadratic fade-in alpha. Future: tan/beige, semi-transparent. Split updated each frame |
| 2.4 Inclined parking orbit | ✅ Done | 25 waypoints at 28.5° inclination (KSC latitude), visible loops before TLI |

**Mission dates:** Launch April 1, 2026 22:36 UTC — Splashdown ~April 12, 2026

### Phase 3: Spacecraft Indicator — COMPLETE

| Item | Status | Notes |
|---|---|---|
| 3.1 Position interpolation | ✅ Done | `TrajectoryInterpolator` with Catmull-Rom splines, velocity via finite differences, parameter 0→1 |
| 3.2 Spacecraft node | ✅ Done | Purple/magenta core sphere (radius 0.12) + 4 concentric teal rings with staggered pulse animations (5.5s cycle, additive blending) |
| 3.3 Position updates | ✅ Done | Timer at 30 FPS in ContentView, calls `sceneController.update(for: missionTime)` |

### Phase 4: Ephemeris & Time Controls — PARTIAL

| Item | Status | Notes |
|---|---|---|
| 4.1 Analytical Moon ephemeris | ✅ Done | `EphemerisProvider` with Keplerian elements, eccentricity correction, node precession. **Not wired into scene** — Moon stays at fixed position |
| 4.2 JPL Horizons API | ❌ Not started | Stretch goal |
| 4.3 Time controls | ✅ Done | Play/pause toggle, timeline slider (launch to splashdown), reset-to-now button with camera reset animation. No speed multiplier yet |

**Remaining work:**
- Wire `EphemerisProvider.moonPosition(at:)` into `OrbitSceneController.update(for:)` for dynamic Moon positioning
- Add speed multiplier (1x, 10x, 100x, 1000x)

### Phase 5: HUD & Polish — PARTIAL

| Item | Status | Notes |
|---|---|---|
| 5.1 HUD overlay | ✅ Done | MET (T+/T- format), phase label, Earth/Moon distances (miles), velocity (mph), Liquid Glass styling |
| 5.2 Liquid Glass | ✅ Done | `GlassModifier` — uses `.glassEffect` on iOS 26+, `.ultraThinMaterial` fallback on older. Compile-time gated via `canImport(FoundationModels)` |
| 5.3 Labels in 3D | ❌ Not started | No Earth/Moon text labels in the scene |
| 5.4 Visual polish | ⚡ Partial | Earth atmosphere glow ✅, night lights ✅, spacecraft pulse animation ✅, camera reset animation ✅. No bloom/HDR post-processing, no camera transition presets |
| 5.5 Debug tools | ✅ Done | Axis indicator + camera coordinate overlay in codebase, commented out, enable for debugging |

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
| 6 | Trajectory line rendered in scene (incl. inclined parking orbit) | ✅ |
| 7 | Spacecraft indicator dot on the path | ✅ |
| 8 | Past/future trail split coloring | ✅ |
| 9 | Time controls (scrubber, play/pause, reset-to-now with camera reset) | ✅ |
| 10 | HUD overlay with mission stats | ✅ |
| 11 | Splash screen | ✅ |
| 12 | Earth night lights + sidereal rotation sync | ✅ |
| 13 | Liquid Glass (iOS 26) with cross-SDK fallback | ✅ |
| 14 | TestFlight CI via GitHub Actions | ✅ |
| 15 | Wire EphemerisProvider for dynamic Moon positioning | ⬜ |
| 16 | Time speed multiplier (1x–1000x) | ⬜ |
| 17 | 3D labels (Earth, Moon) | ⬜ |
| 18 | Bloom/HDR post-processing | ⬜ |
| 19 | Camera preset transitions (Earth, Moon, full trajectory) | ⬜ |
| 20 | JPL Horizons API integration (optional) | ⬜ |
| 21 | Live AROW tracking (stretch, mission-dependent) | ⬜ |

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

6. **Cross-SDK Liquid Glass**: `GlassModifier` uses `#if canImport(FoundationModels)` as a compile-time gate for the iOS 26 SDK, ensuring the app builds on both Xcode 16 (CI) and Xcode 26 (local dev) with the appropriate visual treatment.

7. **Automatic cloud signing for CI**: GitHub Actions uses App Store Connect API key authentication with `CODE_SIGN_STYLE=Automatic` and `-allowProvisioningUpdates` for zero-config distribution signing. Requires Admin role API key.

---

## Asset Requirements

| Asset | Status | Notes |
|---|---|---|
| Earth diffuse texture | ✅ In use | `earth_diffuse.jpg` |
| Earth night lights | ✅ In use | `earth_night.jpg` emission map |
| Moon diffuse texture | ✅ In use | `moon_diffuse.jpg` |
| Splash screen | ✅ In use | `SplashImage` in asset catalog (@1x/@2x/@3x) |
| Starfield | ✅ Procedural | Generated at runtime by `StarfieldGenerator` |
| Earth normal map | ⬜ Not used | Could enhance terrain relief |
| Earth specular map | ⬜ Not used | Could add ocean reflectivity |
