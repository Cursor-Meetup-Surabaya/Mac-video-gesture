# Swift Body Tracker

A macOS application for real-time body pose tracking using the webcam, built with SwiftUI and Apple's Vision framework.

**Research Project** | Made by [madebyaris.com](https://madebyaris.com) | [See it in action](https://x.com/arisberikut/status/1988222714096873822?s=20)

This is a fun research project exploring real-time hand gesture tracking and interactive gameplay using Apple's Vision framework. The app includes a hand gesture-based catch game where you catch falling boxes using your hands.

## Features

- **Real-time webcam capture** using AVFoundation with optimal settings for Vision tracking
- **Body pose detection** using Vision framework's VNDetectHumanBodyPoseRequest
- **Person segmentation** for background blur/removal using VNGeneratePersonSegmentationRequest
- **Color-coded visualization** with distinct colors for body parts:
  - Head (nose, ears): Bright Blue
  - Eyes: Bright Cyan (largest markers)
  - Left Hand: Bright Green
  - Right Hand: Bright Red
  - Left Arm: Bright Yellow
  - Right Arm: Bright Orange
  - Torso: Bright Purple
  - Left Leg: Bright Indigo
  - Right Leg: Bright Magenta
- **Pose smoothing** with exponential moving average to reduce flickering
- **Enhanced tracking** for critical body parts (head, eyes, hands) with optimized thresholds
- **Gradient skeleton rendering** for smooth color transitions between joints
- **Background effects** to make the person stand out
- **Camera switching** support for multiple cameras
- **Hand gesture game** - Catch falling boxes using your hand gestures
- Optimized frame processing with throttling (~30 FPS)
- Hooks for future video manipulation features

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Built-in or external webcam

## Building and Running

### Option 1: Open as Swift Package in Xcode (Quick Start)

1. Open Xcode
2. Select "File" → "Open"
3. Navigate to the project folder and select `Package.swift`
4. Xcode will open it as a Swift Package
5. Select the "BodyTracker" scheme
6. Build and run (⌘R)

**Note:** You may need to configure it as an app target. If you see errors about missing targets, use Option 2 below.

### Option 2: Create New Xcode Project (Recommended for macOS App)

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
5. Click "Next" and choose a location (or use the current folder)
6. Delete the default `ContentView.swift` and `BodyTrackerApp.swift` files that Xcode creates
7. Copy all files from `Sources/BodyTracker/` to your new project's folder
8. In Xcode, right-click your project → "Add Files to BodyTracker..."
9. Select all the Swift files you copied
10. Make sure "Copy items if needed" is unchecked and "Add to targets: BodyTracker" is checked
11. Add camera permissions: Right-click Info.plist → "Open As" → "Source Code", and add:
    ```xml
    <key>NSCameraUsageDescription</key>
    <string>This app needs camera access to track body poses.</string>
    ```
12. Build and run (⌘R)

### Option 3: Using xcodegen (if installed)

```bash
brew install xcodegen  # if not installed
cd /Volumes/app/self-project/cc-mobile
xcodegen generate
open BodyTracker.xcodeproj
```

### Option 4: Using Swift Package Manager (Command Line)

```bash
swift build
swift run
```

**Note:** This creates a command-line executable, not a GUI app. For a proper macOS app with window, use Option 1 or 2.

## Architecture

- **BodyTrackerApp.swift**: Main app entry point
- **ContentView.swift**: Root view coordinating camera and pose detection
- **CameraManager.swift**: Handles AVFoundation camera capture
- **PoseDetector.swift**: Vision framework integration for pose detection
- **PoseOverlayView.swift**: SwiftUI overlay rendering skeleton visualization
- **HandCatchGameView.swift**: Hand gesture-based catch game overlay
- **FaceHandOverlayView.swift**: Renders hand skeleton visualization
- **ManipulationService.swift**: Service interface for future video manipulation features

## Usage

1. Launch the app
2. Grant camera permissions when prompted
3. Position yourself in front of the webcam
4. The app will detect your hand gestures and display hand skeleton visualization
5. **Play the game**: Catch falling blue boxes by moving your hands - the game tracks your palm position and detects collisions
6. Score increases with each catch, and the game speed gradually increases for added challenge

## Future Enhancements

The `ManipulationService` class provides hooks for implementing:
- Real-time video filters based on pose position
- Background replacement using pose segmentation
- Video transformations based on pose movement
- Custom effects applied to specific body parts

## Performance & Best Practices

- Frame processing is throttled to ~30 FPS for optimal performance
- Uses Metal-accelerated Vision framework for efficient pose detection
- Processing happens on background queues to maintain UI responsiveness
- Camera configured with auto-focus, auto-exposure, and auto white balance for optimal tracking
- BGRA pixel format used for best Vision framework compatibility
- Late frames are discarded to maintain real-time performance
- Pose smoothing with 5-frame history buffer reduces jitter and flickering

## Color Coding System

The app uses a centralized style map (`PoseStyle.swift`) for consistent color coding:

- **Critical parts** (head, eyes, hands) have larger markers (16-18px) and thicker skeleton lines (5px)
- **Standard parts** use smaller markers (12px) and thinner lines (3px)
- **Gradient rendering** creates smooth color transitions between connected joints
- Colors are defined using full RGB values for maximum vibrancy

## Technical Implementation

### Pose Detection
- Uses `VNDetectHumanBodyPoseRequest` for body landmark detection
- Enhanced thresholds: 0.3 for critical parts, 0.1 for standard parts
- Exponential moving average smoothing (alpha = 0.7)
- Pose prediction when detection temporarily fails

### Background Segmentation
- Uses `VNGeneratePersonSegmentationRequest` with balanced quality
- Mask properly oriented and scaled to match view size
- Background blur/desaturation applied using inverted mask

### Camera Configuration
- High-quality session preset for better tracking accuracy
- Continuous auto-focus, exposure, and white balance
- Proper orientation handling for Vision framework
- Front-facing camera mirroring for natural user experience

### Hand Gesture Game
- Uses `VNDetectHumanHandPoseRequest` to track up to 2 hands simultaneously
- Calculates palm center from wrist and MCP joints
- Dynamic catch radius based on hand size (fingertip spread)
- Real-time collision detection between falling boxes and hand circles
- Progressive difficulty with increasing fall speed
- Visual feedback with colored hand circles (green for left, red for right)

---

**Note**: This project is for research and educational purposes. Made by [madebyaris.com](https://madebyaris.com). See the demo video: [Twitter/X Post](https://x.com/arisberikut/status/1988222714096873822?s=20)

