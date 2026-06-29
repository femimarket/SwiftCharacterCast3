# CharacterCast3

## Overview
CharacterCast3 is a SwiftUI-based iOS application for managing and "casting" character images. It provides a streamlined workflow for importing images, organizing them into a searchable library, and assigning lead/target roles for downstream processing. The app emphasizes performance, modern UI conventions, and declarative state management.

## Features
- **Multi-Source Import**: Pick images from the Photos app, Files app, or drag-and-drop directly onto the screen.
- **Role Assignment**: Designate a `Lead` image and a `Target` image (`CAST AS`).
- **Library Management**: Searchable grid view, inline deletion, and reset functionality.
- **Performance-Optimized Thumbnails**: Async, cached, and downsampled image loading via `CGImageSource`.
- **Modern SwiftUI UX**: Enforced dark mode, custom accent tint, glass UI styles, spring animations, and haptic/auditory sensory feedback.
- **Security-Scoped File Access**: Properly handles sandboxed file URLs and Photos picker data.

## Requirements
- iOS 26.0+
- Swift 6.0+
- Xcode 16+ (or compatible Swift 6.2 toolchain)

## Installation & Build
CharacterCast3 is distributed as a Swift Package. To build:

1. Clone or download the repository.
2. Open the project in Xcode or build via command line:
   ```bash
   swift build
   ```
3. The `Package.swift` manifest defines a library target (`CharacterCast3`) and explicitly excludes app-specific files (`CharacterCast3App.swift`, `Assets.xcassets`) from the library bundle, allowing the package to be used as both a standalone app and a reusable library.

## Usage
1. **Onboarding**: Launch the app to see the setup screen. Tap `Pick Lead from Photos`, `Pick Lead from Files`, or drop an image anywhere on the screen.
2. **Select Target**: Once a lead is set, browse the character grid below. Tap any image to assign it as the `Target`. Tap again to deselect.
3. **Cast**: When both Lead and Target are selected, the bottom bar appears. Tap `Cast` to trigger the casting pipeline. The app provides haptic success feedback and increments the cast counter.
4. **Manage Library**: 
   - Use the search bar to filter characters by filename.
   - Long-press any character to access the context menu (Use as Lead, Clear Selection, Delete).
   - Tap `Reset` in the toolbar to clear Lead/Target assignments without deleting library items.

## Architecture & Key Files

| File | Purpose |
|------|---------|
| `CharacterCast3/CharacterCast3App.swift` | App entry point. Configures `WindowGroup`, applies `.tint()` and `.preferredColorScheme(.dark)`, and initializes `ContentView`. |
| `CharacterCast3/ContentView.swift` | Core UI and business logic. Manages import flows, state (`@State`), thumbnail rendering, search filtering, and casting triggers. Contains the `ThumbnailLoader` actor and `Thumbnail` view. |
| `Package.swift` | Swift Package Manager manifest. Defines iOS 26 platform, Swift 6 language mode, and target configuration. |
| `ProjectService` | (External/Required Module) Handles file persistence (`saveFile`, `getUrl`), casting logic (`setCharacterCast`), and likely image processing pipelines. |

## Technical Details & Conventions

### State & Async Management
- UI state is centralized in `ContentView` using `@State` properties (`mainFilename`, `targetFilename`, `targets`, `castCount`, etc.).
- Async operations (photo loading, directory scanning, thumbnail generation) are wrapped in `Task` and `.task` modifiers to maintain main-thread safety.
- `refreshTargets()` runs on a `.utility` priority detached task, filters by supported extensions, and sorts by modification date.

### Thumbnail System
- `ThumbnailLoader` is a `private actor` that prevents concurrent cache corruption.
- Uses `NSCache<NSString, UIImage>` with a `countLimit` of 600.
- Leverages `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceCreateThumbnailFromImageAlways` and `kCGImageSourceThumbnailMaxPixelSize` to avoid memory bloat from high-resolution assets.

### File Handling & Naming
- Imported images are saved to the user's Documents directory via `ProjectService.saveFile`.
- Auto-generated filenames follow the pattern: `<suggestedStem>-<UUID6>.jpg` (e.g., `drop-a1b2c3.jpg`).
- The `displayName(_:)` helper strips UUID suffixes for cleaner UI labels using regex.
- Security-scoped resources are properly accessed and released using `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`.

### UI Conventions
- **Layout**: Adaptive `LazyVGrid` with `minimum: 100` spacing. Scroll bounce behavior enabled.
- **Feedback**: `.sensoryFeedback(.selection)`, `.sensoryFeedback(.impact)`, and `.sensoryFeedback(.success)` are bound to state changes.
- **Animations**: Spring animations (`response: 0.35, dampingFraction: 0.8`) are used consistently for slot transitions and selection states.
- **Accessibility**: All interactive elements include `.accessibilityLabel()` and `.accessibilityAddTraits()` for screen reader compatibility.
- **Theme**: Hardcoded dark mode and custom pink tint (`Color(red: 0.95, green: 0.25, blue: 0.55)`) are applied at the scene level.

## Dependencies
- `SwiftUI`, `ImageIO`, `UniformTypeIdentifiers`, `PhotosUI` (standard iOS frameworks)
- `ProjectService` (required module for persistence and casting logic)