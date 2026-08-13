# Agent Skills

## Why This File Exists

This repository depends on agent judgment for product taste, SwiftUI quality,
and iOS platform correctness. These are the highest-signal skills currently
relevant to the project.

## Already Available In This Environment

- `swiftui-expert-skill`
- `swiftui-pro`
- `update-swiftui-apis`

## Added For This Project

These were selected on August 12, 2026 based on current skills index search
results and install success:

- `taste`
  - Chosen as the closest high-signal match to the requested
    "human-taste/human-touch" direction.
  - Search result seen: `affaan-m/ecc@taste` with about `1.9K installs`.
- `ios-hig-design`
  - Adds Apple-style design guidance for iOS product decisions.
  - Search result seen: `wondelai/skills@ios-hig-design` with about `5K installs`.
- `ios-accessibility`
  - Keeps accessibility from becoming an afterthought as the app grows.
  - Search result seen: `dpearson2699/swift-ios-skills@ios-accessibility`
    with about `3.6K installs`.

## Strong Built-In Skills To Reach For

- `swiftui-patterns` for state and architecture
- `swiftui-performance-audit` for performance reviews
- `swiftui-animation` for motion systems
- `ios-developer` and `ios-swift-development` for broader app work
- `apple-hig` for platform guidance
- `swift-testing` for test design
- `swiftdata` if persistence arrives
- `xcode-project-setup` when adding packages

## Current Project Application

- Use SwiftUI skills for any work in `Screens`, `UI`, and launch flow.
- Use design/taste skills when changing onboarding/auth visuals, fonts, colors,
  or illustration placement.
- Preserve the current `UI/System/DesignTokens.swift` token approach when
  changing fonts, colors, asset names, or environment flags.
- Keep current UI work light-mode only until the user asks for dark mode.
- Use SwiftData skill when changing `LocalAuthIdentity`, `LocalProfile`, or
  the `transiumSchema` model container.
- Use iOS accessibility skills before shipping onboarding or auth copy/buttons
  beyond this prototype stage.

## Selection Notes

- I favored skills with stronger install counts over niche results.
- I avoided low-install "human taste" variants because the stronger signal was a
  mix of `taste` plus iOS-specific design guidance.
- One candidate, `wshobson/agents@mobile-ios-design`, did not install cleanly in
  this environment, so it was not adopted here.
