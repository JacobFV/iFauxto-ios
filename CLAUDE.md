# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

This is an Xcode project. Use these commands from the project root:

```bash
# Build the app
xcodebuild -scheme iFauxto -destination 'platform=iOS Simulator,name=iPhone 17' build

# Run unit tests
xcodebuild -scheme iFauxto -destination 'platform=iOS Simulator,name=iPhone 17' test

# Run UI tests
xcodebuild -scheme iFauxto -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:iFauxtoUITests test

# Run a single test
xcodebuild -scheme iFauxto -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:iFauxtoTests/iFauxtoTests/testName test
```

## Architecture

- **SwiftUI + SwiftData**: iOS app using SwiftUI for UI and SwiftData for persistence with CloudKit sync
- **Target**: iOS 26.1+, iPhone and iPad
- **Concurrency**: Swift 6 strict concurrency with `@MainActor` default isolation

### Directory Structure

```
iFauxto/
├── Models/           # SwiftData models
│   ├── Folder.swift          # Custom folders with sortOrder
│   ├── FolderAsset.swift     # Links folders to photo identifiers
│   ├── AssetTag.swift        # AI-generated tags
│   └── UserPreferences.swift # App settings (home screen, sort mode)
├── Services/
│   ├── PhotoLibraryService.swift  # PhotoKit wrapper, caching
│   ├── ImageProcessor.swift       # Core Image filter pipeline
│   └── Tagging/
│       ├── ImageTaggingService.swift   # Protocol for pluggable backends
│       ├── VisionTaggingService.swift  # On-device Vision implementation
│       └── TaggingQueue.swift          # Background processing
├── Views/
│   ├── RootView.swift         # App router, permission handling
│   ├── Folders/               # Folder management views
│   ├── Photos/                # Photo grid, detail, picker views
│   ├── Editor/                # VSCO-style photo editor
│   ├── Search/                # Search bar and results
│   └── Settings/              # User preferences
└── iFauxtoApp.swift          # Entry point, ModelContainer setup
```

### Key Patterns

**Data Flow**: SwiftData `@Query` for reactive fetching, `@Environment(\.modelContext)` for mutations. `ModelContainer` configured with CloudKit at app launch.

**Photo Access**: `PhotoLibraryService` wraps PHPhotoLibrary. Assets referenced by `localIdentifier` strings stored in SwiftData, actual images fetched on-demand via PhotoKit.

**AI Tagging**: `ImageTaggingService` protocol allows swapping Vision for cloud APIs. `VisionTaggingService` runs face detection, object classification, OCR, and scene classification in parallel.

**Image Editing**: `ImageProcessor` chains CIFilters for non-destructive editing. All adjustments are properties on the processor; call `process(_:)` to apply them to a CIImage.

**Folder Ordering**: `Folder.sortOrder` persists custom order. Drag-to-reorder updates `sortOrder` values immediately. `FolderSortOption` enum defines the four sort modes.

### Tone

The app subtly mocks Apple throughout. Examples:
- Sort options: "My Order (God's Way)" vs "Most Recent (Apple's Favorite)"
- Empty states reference Apple auto-creating unwanted albums
- Presets have snarky names like "Hipster Approved" and "HDR But Actually Good"
- Easter egg: 10 taps on settings icon triggers "Courage Counter"

When adding UI copy, maintain this playful-but-not-mean tone.

## Progress Tracking

See `PROGRESS.md` for completed features and known limitations.
