# Flappy Bird for iOS 27

A from-scratch Flappy Bird remake built with SwiftUI and SpriteKit.
Every sprite is drawn in code, so there are no image assets to manage.

## Requirements

- Xcode 27 (or any Xcode that ships the iOS 27 SDK)
- An iPhone or simulator running iOS 27

## Running

1. Open `FlappyBird.xcodeproj` in Xcode.
2. Select the **FlappyBird** scheme and an iOS 27 simulator or device.
3. Press **Run**.

For a physical device, set your own team under *Signing & Capabilities*
and change the bundle identifier if `com.example.FlappyBird` is taken.

## How to play

- Tap anywhere to start, then tap to flap.
- Pass between the pipes to score. The game speeds up slightly as you go.
- Hitting a pipe or the ground ends the round. Tap **Play Again** or anywhere on the screen to retry.
- Your best score is saved between launches, and medals unlock at 10, 20, 30 and 40 points.

## Project layout

| File | Purpose |
| --- | --- |
| `FlappyBird/FlappyBirdApp.swift` | App entry point |
| `FlappyBird/ContentView.swift` | SwiftUI shell: hosts the SpriteKit scene and draws the score, tap hint and game-over card |
| `FlappyBird/GameScene.swift` | SpriteKit scene: bird, pipes, ground, physics, scoring and haptics |
| `FlappyBird/GameState.swift` | Observable model shared between the scene and the SwiftUI overlay |
