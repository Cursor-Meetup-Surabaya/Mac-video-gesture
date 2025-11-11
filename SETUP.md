# Setup Instructions

**Research Project** | Made by [madebyaris.com](https://madebyaris.com) | [See it in action](https://x.com/arisberikut/status/1988222714096873822?s=20)

This is a fun research project exploring real-time hand gesture tracking and interactive gameplay using Apple's Vision framework.

## Option 1: Using Xcode (Recommended)

1. Open Xcode
2. Select "File" → "New" → "Project"
3. Choose "macOS" → "App"
4. Fill in:
   - Product Name: `BodyTracker`
   - Team: (your team)
   - Organization Identifier: `com.bodytracker`
   - Language: Swift
   - Interface: SwiftUI
   - Storage: None
5. Click "Next" and choose a location
6. Delete the default `ContentView.swift` and `BodyTrackerApp.swift` files
7. Copy all files from `Sources/BodyTracker/` to your new project
8. Make sure all files are added to the target
9. Build and run (⌘R)

## Option 2: Using xcodegen (if installed)

If you have `xcodegen` installed:

```bash
brew install xcodegen  # if not installed
cd /Volumes/app/self-project/cc-mobile
xcodegen generate
open BodyTracker.xcodeproj
```

## Option 3: Open Package.swift directly in Xcode

1. Open Xcode
2. Select "File" → "Open"
3. Navigate to the project folder and select `Package.swift`
4. Xcode will open it as a Swift Package
5. Note: This works but you may need to configure it as an app target manually

## Option 4: Manual Xcode Project Creation

1. Open Xcode
2. Create a new macOS App project
3. Replace the generated files with the files from `Sources/BodyTracker/`
4. Add camera permissions to Info.plist (already included in the provided Info.plist)

## Required Permissions

The app requires camera access. Make sure `NSCameraUsageDescription` is set in Info.plist (already included).

## What You'll Get

After building and running, you'll have:
- Real-time hand gesture tracking with visual skeleton overlay
- Interactive catch game where you catch falling boxes using your hands
- Score tracking and progressive difficulty
- Support for both left and right hands simultaneously

**Note**: This project is for research and educational purposes. Made by [madebyaris.com](https://madebyaris.com).

