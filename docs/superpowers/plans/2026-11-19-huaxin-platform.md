# Huaxin Platform Art Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Replace the crude Preview underground interior with a detailed, photo-referenced Huaxin Line 3 station scene.

**Architecture:** Generate a continuous architectural background and empty entrance interiors with imagegen, then keep train, glass doors, signage and people as separate animated layers. Render the new station within the existing underground cutaway, connecting each entrance to one continuous escalator. Share station route geometry with residents; draw structural rails with straight geometry and add Shenzhen street details.

**Tech Stack:** Godot 4.6, GDScript, PNG artwork, built-in imagegen.

**Spec:** User request: “重新生成地下地铁的场景，最大程度还原”. Architectural references and generation prompt are recorded in `docs/metro-art.md`.

## Global Constraints

- Preview only; do not edit `wallpaper/` or `scripts/desktop-host.ps1`.
- Preserve two entrances, two escalators, unique characters and working transport routines.
- The artwork is a side-view adaptation of photographic references, not a measured reconstruction.
- Commit only related changes; do not push or change version numbers.

### Task 1: Replace station artwork and integrate its animated layers

**Files:**
- Create: `assets/huaxin-platform.png`
- Create: `assets/huaxin-entrances.png`, `assets/metro-escalator.png`, `assets/shenzhen-shelter.png`, `assets/shenzhen-bougainvillea.png`
- Create: `scripts/station.gd`, `scripts/station_routes.gd`, `scripts/street_details.gd`
- Modify: `scripts/city.gd`, `scripts/transit.gd`, `scripts/residents.gd`
- Create: `tests/station_logic.gd`, `tests/capture_station.gd`
- Modify: existing smoke, resident and itinerary regression tests
- Modify: `docs/metro-art.md`

**Interfaces:** `_draw_station_interior(width)` draws architecture; `_draw_platform_glass(width)` draws doors over the train; `Transit.train_doors(animation_time)` remains the door timing authority.

- [x] Inspect the current station and research Huaxin photographic references. Generate a detailed, empty architectural background; no baked-in people or trains.
- [x] Inspect the generated image before copying it into `assets/huaxin-platform.png`. Document its prompt and photo attribution.
- [x] Replace the station's flat wall and dot-pattern columns. Align ceiling, tracks, platform floor and passengers; retain the two escalators and readable live signage.
- [x] Keep screen doors synchronized with the train and ensure neither the door header nor the platform floor covers passengers incorrectly.

### Task 2: Validate actual rendered output and commit

- [x] Import with `.tools/godot/Godot_v4.6-stable_win64_console.exe --headless --path . --editor --import`.
- [x] Run `tests/smoke.gd`, `tests/residents.gd` and `tests/citizen_simulation.gd` using `--headless --path . --script`.
- [x] Render and inspect both original and compact ratios, plus train arrival, stop and departure. Inspect actual image captures, not just successful process exits.
- [x] Check `git diff --check`, `git status` and the complete changed-file list; stage only the station work and create one descriptive commit.

### User corrections incorporated

- [x] Clear the two entrance interiors of baked extra escalator heads and rails.
- [x] Use one continuous escalator from each street entrance directly to the platform, as explicitly selected by the user.
- [x] Share exact geometry and timing between treads, image anchors and passenger travel. Use left descending and right ascending routes.
- [x] Draw handrails, glazing frames and road barriers as straight structural geometry; keep curves only at escalator end returns.
- [x] Add Hongli Road/Huaqiangbei Road signs, green Metro wayfinding and bougainvillea planters.
- [x] Verify closing-door boarding and correct the car pickup passenger to use the adjacent waterfront sidewalk.
- [x] Inspect actual captures and record a complete continuous entrance-to-platform trip.
