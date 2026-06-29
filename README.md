# CharacterCast3

**CharacterCast3** is a SwiftUI-based iOS application designed for casting characters. It allows users to select a "Lead" character and a "Target" character from an imported library of images, then "cast" them together. The app features a modern, dark-mode-first interface with gesture support, drag-and-drop, and photo library integration.

## Features

- **Lead & Target Selection**: Choose a primary character (Lead) and a secondary character (Target) from your library.
- **Image Library Management**: Import images via the Photos app, file system, or drag-and-drop.
- **Smart Search**: Filter your character library by name.
- **Visual Feedback**: Real-time previews of selected pairs and cast counts.
- **Performance Optimized**: Lazy-loaded, cached, and downsampled thumbnails for smooth scrolling.
- **Dark Mode Default**: Optimized for dark environments with a custom tint color.

## Architecture

The project is structured as a Swift Package with a single main target.

### Key Files

- `CharacterCast3App.swift`: The app entry point. Configures the global tint color (`#F23F8C`) and enforces dark mode.
- `ContentView.swift`: The core UI logic. Handles state management for selections, imports, and the casting workflow.
- `Package.swift`: Defines the project dependencies, including `ProjectService`.

### Dependencies

- **ProjectService**: A custom service (fetched from `femimarket/swift-project-service`) that handles file persistence and URL resolution for the character images.

## Installation & Setup

### Prerequisites

- **Xcode 16+** (Swift 6.2 toolchain)
- **iOS 26+** (Note: The `Package.swift` specifies `.iOS(.v26)`. Ensure your development environment supports this target version).

### Clone and Open

1. Clone the repository.
2. Open the project in Xcode. Xcode will automatically resolve the Swift Package dependencies.
3. Build and run on a simulator or device.

## Usage Guide

### 1. Onboarding

When you first launch the app, you will see the onboarding screen. You can set up your first character by:
- Tapping **"Pick Lead from Photos"** to select an image from your device's photo library.
- Tapping **"Pick Lead from Files"** to browse your file system.
- **Dragging and dropping** an image file anywhere onto the screen.

### 2. Managing Characters

Once you have at least one image, the app transitions to the **Working Layout**:

- **Lead Slot**: Displays the currently selected lead character. Tap the menu to replace it or remove it.
- **Target Slot**: Initially empty. Tap a character from the grid below to select them as the target.
- **Character Grid**: Shows all imported images sorted by modification date (newest first).
  - **Select Target**: Tap a character to set them as the target. A checkmark appears.
  - **Set as Lead**: Long-press (context menu) on a character and select **"Use as Lead"**.
  - **Delete**: Long-press (context menu) and select **"Delete"** to remove a character from the library.

### 3. Casting

When both a Lead and a Target are selected:
1. A preview bar appears at the bottom of the screen showing the two characters.
2. Tap the **"Cast"** button.
3. The app triggers the `ProjectService.setCharacterCast` action.
4. A success feedback animation plays, and the cast count increments.

### 4. Resetting

To clear your current selection without deleting characters:
- Tap the **"Reset"** button in the top-right toolbar.
- Confirm the action in the dialog. This clears the Lead and Target but keeps the images in your library.

## Technical Details

### Image Handling

- **Supported Formats**: PNG, JPG, JPEG, HEIC, HEIF, WEBP, GIF, TIFF.
- **Thumbnails**: The app uses a custom `Thumbnail` view with an `ThumbnailLoader` actor. It caches up to 600 images and downsamples them to a maximum pixel size to ensure smooth performance with large libraries.
- **Storage**: Images are saved to the app's Document Directory using `ProjectService`.

### State Management

- `ContentView` uses `@State` properties to manage UI state (`mainFilename`, `targetFilename`, `targets`, etc.).
- Asynchronous operations (like loading photos or refreshing the target list) are handled via `Task` and `@MainActor` to ensure thread safety.

### Accessibility

- The app includes accessibility labels for slots, characters, and actions.
- Sensory feedback (haptic and sound) is triggered on selection and casting events.

## Troubleshooting

- **Images not appearing**: Ensure the images are in a supported format. Check the console for any import errors.
- **Performance issues**: If you have a very large library, the app will load thumbnails lazily. Ensure you are running on a device that supports the specified iOS version.
- **Reset not working**: If the reset dialog does not appear, check that you have at least one selection (Lead or Target) active.