# Contributing to Waymark

Thanks for your interest in contributing!

## Getting Started

1. Fork the repo
2. Clone your fork
3. Install XcodeGen: `brew install xcodegen`
4. Generate the project: `xcodegen generate`
5. Build: `xcodebuild -scheme Waymark -configuration Debug -derivedDataPath build build`
   The built app is at `build/Build/Products/Debug/Waymark.app`.
   Or open `Waymark.xcodeproj` in Xcode and hit Run.

## Submitting Changes

1. Create a branch for your change
2. Make your changes
3. Test manually — run the app and verify your change works
4. Open a pull request with a clear description of what you changed and why

## Filing Issues

- **Bug reports:** Include macOS version, steps to reproduce, and what you expected vs. what happened
- **Feature requests:** Describe the use case, not just the solution

## Code Style

- Swift 6 strict concurrency
- No third-party dependencies
- Follow existing patterns in the codebase
