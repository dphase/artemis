# Artemis II Tracker - iOS App Plan

## Overview

A realtime 3D visualization of Earth, the Moon, and the Artemis II spacecraft on its free-return lunar flyby trajectory. Built with SceneKit for the 3D scene and SwiftUI for the surrounding UI.

---

## Architecture

```
Artemis/
  App/
    ArtemisApp.swift              # App entry point
    ContentView.swift             # Root view: SceneKit viewport + HUD overlay
  Scene/
    OrbitSceneController.swift    # Owns the SCNScene; creates and updates all nodes
    CameraController.swift        # Handles pinch-to-zoom, pan, and orbit gestures
  Bodies/
    EarthNode.swift               # Earth sphere + texture + axial tilt + rotation
    MoonNode.swift                # Moon sphere + texture + rotation
    SpacecraftNode.swift          # Bright indicator dot/glow for Orion's current position
    TrajectoryNode.swift          # The full mission path rendered as a tube/line geometry
  Data/
    MissionTimeline.swift         # Hardcoded trajectory waypoints (position + timestamp)
    TrajectoryInterpolator.swift  # Interpolates spacecraft position along the path for any given time
    EphemerisProvider.swift       # Computes Earth & Moon positions (simplified model or JPL Horizons fetch)
  Resources/
    earth_diffuse.jpg             # 8K NASA Blue Marble texture
    earth_normal.jpg              # Normal map for terrain relief
    earth_specular.jpg            # Specular map (oceans reflective, land matte)
    earth_night.jpg               # City lights emission map
    moon_diffuse.jpg              # Lunar surface texture
    starfield.jpg                 # Skybox / background cube map
```

Target: **iOS 17+**, Swift, SwiftUI + SceneKit. No external dependencies.

---

## Phase 1: Scene Foundation

**Goal:** Render Earth and the Moon in a 3D scene with correct relative positioning, textures, and lighting.

### 1.1 - SceneKit Viewport in SwiftUI
- `SCNView` wrapped in a `UIViewRepresentable`
- Dark background, antialiasing enabled
- Starfield skybox on `scene.background`

### 1.2 - Earth
- `SCNSphere` with radius normalized to 1.0 (Earth radius = 1 unit in scene space)
- Materials: diffuse (Blue Marble), specular (oceans), normal (terrain), emission (night lights)
- Axial tilt: rotate node 23.44 deg off the orbital plane
- Continuous rotation: `SCNAction.repeatForever` rotating ~360 deg/24h (scaled to a visible speed)

### 1.3 - Moon
- `SCNSphere` with radius 0.273 (Moon/Earth radius ratio)
- Position: ~60 units from Earth (scaled; real ratio is ~60 Earth radii)
- Tidally locked rotation (same face toward Earth)
- Diffuse texture only (moon_diffuse.jpg)

### 1.4 - Lighting
- One directional light simulating the Sun (white, from a fixed direction)
- Subtle ambient light so the dark sides aren't pure black
- Earth casts shadows on itself; Moon receives Earth-light if close enough

### 1.5 - Camera
- Initial position: pulled back far enough to see Earth and the Moon's orbit in frame
- Orbit controls: user can rotate around the scene center (Earth)
- Pinch-to-zoom with min/max distance clamps
- Optional: double-tap to snap to preset views (Earth close-up, Moon close-up, full trajectory)

---

## Phase 2: Trajectory Path

**Goal:** Render the Artemis II free-return trajectory as a visible line in 3D space.

### 2.1 - Mission Trajectory Data
The Artemis II trajectory is a **free-return lunar flyby** lasting ~10 days:

| Phase | Time (approx.) | Description |
|---|---|---|
| Launch + parking orbit | T+0 to T+2h | LEO at ~185 km, 1-2 orbits |
| Trans-Lunar Injection | T+2h | ICPS burn, depart Earth |
| Outbound coast | Day 1-4 | Coast to Moon |
| Lunar flyby | Day 4-5 | Closest approach ~8,900 km above far side |
| Return coast | Day 5-9 | Return to Earth |
| Entry + splashdown | Day ~10 | Skip-entry, Pacific splashdown |

We model this as an array of **waypoints** (position vectors in Earth-centered coordinates + timestamps). The path is interpolated with a Catmull-Rom spline for smooth curvature.

### 2.2 - Trajectory Rendering
- Generate an `SCNGeometry` from the spline points (either a thin `SCNTube`-like custom geometry or a series of small connected cylinders)
- Alternatively: use `SCNGeometrySource` + `SCNGeometryElement` with `.line` primitive type for simplicity, then overlay a glow via a shader modifier
- **Color:** Muted gray/white with low opacity (~0.3-0.4 alpha) for the overall path
- **Already-traveled segment:** slightly brighter than the future segment, or a different hue (soft blue for past, soft gray for future)

### 2.3 - Trail Effect (Past vs Future)
- Split the trajectory into two geometries at the spacecraft's current position index
- Past path: muted purple/blue, slightly more opaque
- Future path: muted gray, more transparent
- Update the split point each frame as time progresses

---

## Phase 3: Spacecraft Indicator

**Goal:** Show Orion's current position as a bright, glowing dot on the trajectory.

### 3.1 - Position Interpolation
- `TrajectoryInterpolator` takes the current `Date` and the mission start `Date`
- Maps elapsed time to a parameter `t` along the spline (0.0 = launch, 1.0 = splashdown)
- Returns the 3D position and a tangent vector (for optional orientation)
- If the current time is before launch or after splashdown, clamp to the endpoints

### 3.2 - Spacecraft Node
- Small `SCNSphere` (radius ~0.05) with bright emissive white/gold material
- Outer glow: a slightly larger, semi-transparent sphere or a billboard `SCNPlane` with a radial gradient texture
- Optional pulsing animation (`SCNAction` scaling between 0.9x and 1.1x)

### 3.3 - Position Updates
- A `Timer` or `CADisplayLink` fires at ~1 Hz (position doesn't change fast enough to need 60 fps updates)
- Each tick: compute new position from `TrajectoryInterpolator`, update `spacecraftNode.position`
- Update the past/future trail split

---

## Phase 4: Ephemeris & Realism

**Goal:** Make Earth and Moon positions astronomically accurate for the current date.

### 4.1 - Moon Position
- For V1: use a simplified analytical lunar ephemeris (mean orbital elements + a few perturbation terms)
- The Moon's position relative to Earth can be computed with ~1 deg accuracy using basic Keplerian elements + the principal perturbation terms (evection, variation, annual equation)
- This avoids needing a network call for basic accuracy

### 4.2 - Optional: JPL Horizons API
- For higher accuracy, fetch state vectors from `https://ssd.jpl.nasa.gov/api/horizons.api`
- Query Moon position (COMMAND='301') relative to Earth (CENTER='500@399') in vectors format
- Cache results locally; refresh daily
- Gracefully fall back to the analytical model if offline

### 4.3 - Time Controls
- Allow the user to scrub through the mission timeline (a slider from T-0 to T+10 days)
- Play/pause button for realtime progression
- Speed multiplier (1x, 10x, 100x, 1000x) for watching the full trajectory unfold
- Display current mission elapsed time (MET) in the HUD

---

## Phase 5: HUD & Polish

**Goal:** Overlay mission info and polish the visual experience.

### 5.1 - HUD Overlay (SwiftUI)
- Mission Elapsed Time (MET) or countdown to launch
- Current phase label (e.g., "Outbound Coast", "Lunar Flyby")
- Distance from Earth (km)
- Distance from Moon (km)
- Spacecraft velocity (km/s)
- Minimal, semi-transparent design that doesn't obscure the 3D view

### 5.2 - Labels in 3D
- "Earth" and "Moon" labels as `SCNText` or billboard `SCNNode`s that always face the camera
- Distance scale indicator

### 5.3 - Visual Polish
- Bloom/glow post-processing on the spacecraft indicator (SCNTechnique or SCNCamera HDR)
- Earth atmosphere: a slightly larger, semi-transparent blue sphere around Earth for atmospheric glow
- Smooth camera transitions when switching presets
- Launch animation: camera starts close to Earth, pulls back as the spacecraft departs

---

## Phase 6: Data Source & Live Tracking (Stretch)

**Goal:** If/when Artemis II is in flight, use real telemetry data.

### 6.1 - NASA AROW Integration
- During Artemis I, NASA's AROW (Artemis Real-time Orbit Website) served JSON state vectors
- Monitor for Artemis II equivalent endpoint
- If available, poll every 30-60 seconds for live position/velocity
- Blend live data with the predicted trajectory

### 6.2 - SPICE Kernel Support
- NASA distributes .bsp trajectory kernels for Artemis missions
- Could bundle the predicted trajectory kernel and read it with a minimal SPICE reader
- This would give the most accurate pre-mission trajectory

---

## Build Order & Milestones

| Step | Deliverable | Depends On |
|---|---|---|
| 1 | Xcode project, SceneKit viewport in SwiftUI, starfield background | - |
| 2 | Earth with textures, rotation, lighting | Step 1 |
| 3 | Moon with texture, correct relative position and size | Step 2 |
| 4 | Camera orbit/zoom controls | Step 1 |
| 5 | Hardcoded trajectory waypoints + spline interpolation | - |
| 6 | Trajectory line rendered in scene (muted path) | Steps 3, 5 |
| 7 | Spacecraft indicator dot on the path | Step 6 |
| 8 | Past/future trail split coloring | Step 7 |
| 9 | Time controls (scrubber, play/pause, speed) | Step 7 |
| 10 | HUD overlay with mission stats | Step 7 |
| 11 | Analytical Moon ephemeris for accurate positioning | Step 3 |
| 12 | Visual polish (bloom, atmosphere, animations) | Steps 8, 10 |
| 13 | JPL Horizons API integration (optional) | Step 11 |
| 14 | Live AROW tracking (stretch, mission-dependent) | Step 7 |

---

## Key Design Decisions

1. **SceneKit over RealityKit**: SceneKit gives us finer control over custom geometries (trajectory lines), shader modifiers (glow effects), and camera behavior. RealityKit is optimized for AR, which we don't need.

2. **Normalized scale**: Earth radius = 1.0 scene unit. Everything else is proportional. Real distances (Earth-Moon = 60 Earth radii) are preserved but can be optionally compressed for a tighter view.

3. **Hardcoded trajectory first**: Rather than computing orbital mechanics in real-time, we pre-define the trajectory as waypoints and interpolate. This is simpler, more predictable, and sufficient for visualization. The waypoints are derived from NASA's published mission profile.

4. **No external dependencies**: Pure Apple frameworks (SceneKit, SwiftUI, Foundation). Networking only for optional API calls. The app works fully offline with the analytical ephemeris and hardcoded trajectory.

---

## Asset Requirements

| Asset | Source | Notes |
|---|---|---|
| Earth diffuse texture | NASA Visible Earth (Blue Marble) | Public domain, 8K recommended |
| Earth normal map | NASA/community-generated | Derived from SRTM elevation data |
| Earth specular map | Community-generated | Binary: ocean=white, land=black |
| Earth night lights | NASA Black Marble | Public domain |
| Moon diffuse texture | NASA CGI Moon Kit / LRO | Public domain |
| Starfield | NASA/ESA deep field or generated | Cubemap for skybox |
