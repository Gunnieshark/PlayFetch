# Dog Tennis Ball Catch Game

A fun iOS game where you move your dog with your finger to catch falling tennis balls!

## Setup Instructions

### 1. Create a New Xcode Project

1. Open Xcode
2. Click "Create a new Xcode project"
3. Select **iOS** → **App** → Next
4. Enter the following:
   - Product Name: `DogTennisCatch`
   - Interface: **SwiftUI**
   - Language: **Swift**
5. Click **Next** and choose where to save the project

### 2. Add the Game Files

1. In Xcode's Project Navigator (left sidebar), find the following default files and **replace** them with the files from this folder:
   - Replace `DogTennisCatchApp.swift` (main app file)
   - Replace `ContentView.swift`
   - Delete the default `Assets.xcassets` preview content provider if asked

2. Add the new `GameScene.swift` file:
   - Right-click on the project folder in Xcode
   - Select **Add Files to "DogTennisCatch"...**
   - Select `GameScene.swift`
   - Make sure "Copy items if needed" is checked
   - Click **Add**

### 3. Add Your Dog Image

1. Prepare your dog image:
   - Use a photo of your dog
   - For best results, use an image with a transparent background (PNG)
   - Or crop your dog from the photo

2. In Xcode, click on **Assets.xcassets** in the Project Navigator

3. Click the **+** button at the bottom and select **New Image Set**

4. Name it **dog**

5. Drag your dog image into the **2x** or **3x** slot (Xcode will handle the sizing)

### 4. Generate Tennis Ball Image

Run the helper script to create a tennis ball image:

```bash
cd /Users/matthewgrandy/Desktop/notes
swift generate_icon.swift
```

This will create `tennis_ball.png` in the current directory.

### 5. Add Tennis Ball Image to Xcode

1. In Xcode, click on **Assets.xcassets**
2. Click the **+** button and select **New Image Set**
3. Name it **tennis_ball**
4. Drag the `tennis_ball.png` file into the **2x** or **3x** slot

### 6. Optional: Add Sound Effect

To add a catch sound effect (optional):

1. Find or create a short "catch" sound effect (MP3 format)
2. Name it `catch.mp3`
3. Drag it into your Xcode project
4. Make sure "Copy items if needed" is checked

If you skip this step, just remove or comment out this line in `GameScene.swift:130`:
```swift
run(SKAction.playSoundFileNamed("catch.mp3", waitForCompletion: false))
```

### 7. Build and Run

1. Select a simulator or your iOS device from the scheme selector at the top
2. Click the **Play** button (▶) or press **Cmd+R**
3. The game should launch!

## How to Play

- **Drag your finger** anywhere on the screen to move your dog
- **Catch the falling tennis balls** with your dog's body
- Each caught ball increases your score
- Don't let the balls fall off the screen!

## Customization Ideas

- Adjust the ball spawn rate in `GameScene.swift:23` (change `1.5` to a different value)
- Change gravity in `GameScene.swift:17` (change `-2` to make balls fall faster/slower)
- Modify dog and ball sizes in the setup functions
- Add different ball types with different point values
- Add a high score system
- Add lives or a game over condition

## Troubleshooting

**Issue: "Cannot find 'dog' in scope" or similar errors**
- Make sure you've added the dog image to Assets.xcassets and named it exactly "dog"

**Issue: "Cannot find 'tennis_ball' in scope"**
- Run the `generate_icon.swift` script and add the tennis ball image to Assets

**Issue: Sound doesn't play**
- Either add a `catch.mp3` file or comment out the sound line in GameScene.swift

**Issue: Game doesn't respond to touch**
- Make sure you're running on a device or simulator that supports touch input
- The code uses touch events which work on iOS devices and simulators

Enjoy playing with your dog!
