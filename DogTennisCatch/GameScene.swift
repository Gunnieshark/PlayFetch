import SpriteKit
import GameplayKit
import AVFoundation

class GameScene: SKScene, SKPhysicsContactDelegate {

    var dogNode: SKSpriteNode!
    var scoreLabel: SKLabelNode!
    var levelLabel: SKLabelNode!
    var introNode: SKSpriteNode!
    var tapToStartLabel: SKLabelNode!
    var score = 0
    var level = 1
    var lastSpawnTime: TimeInterval = 0
    var minimumSpawnGap: TimeInterval = 0.8
    var ballSpawnMin: Double = 1.2
    var ballSpawnMax: Double = 2.0
    var catSpawnMin: Double = 2.5
    var catSpawnMax: Double = 4.0
    var gravityStrength: CGFloat = -2.0
    var gameStarted = false
    let introFrameCount = 120

    // Audio
    var soundEngine: AVAudioEngine!
    var soundPlayerNode: AVAudioPlayerNode!

    let dogCategory: UInt32 = 0x1 << 0
    let ballCategory: UInt32 = 0x1 << 1
    let catCategory: UInt32 = 0x1 << 2
    let dangerDogCategory: UInt32 = 0x1 << 3

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1.0) // Sky blue

        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: gravityStrength)

        // Setup audio
        setupAudio()

        // Show intro animation first
        showIntro()
    }

    func setupAudio() {
        soundEngine = AVAudioEngine()
        soundPlayerNode = AVAudioPlayerNode()
        soundEngine.attach(soundPlayerNode)

        let mixer = soundEngine.mainMixerNode
        let format = mixer.outputFormat(forBus: 0)
        soundEngine.connect(soundPlayerNode, to: mixer, format: format)

        do {
            try soundEngine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }

    func playTone(frequency: Double, duration: Double, volume: Float = 0.5) {
        let mixer = soundEngine.mainMixerNode
        let sampleRate = mixer.outputFormat(forBus: 0).sampleRate
        let frameCount = Int(sampleRate * duration)
        let channelCount = mixer.outputFormat(forBus: 0).channelCount

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channelCount),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        let theta = 2.0 * Double.pi * frequency / sampleRate

        for frame in 0..<frameCount {
            let envelope = 1.0 - (Double(frame) / Double(frameCount)) // Fade out
            let sample = Float(sin(theta * Double(frame)) * envelope * Double(volume))
            // Fill all channels with the same sample
            for channel in 0..<Int(channelCount) {
                buffer.floatChannelData?[channel][frame] = sample
            }
        }

        soundPlayerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        soundPlayerNode.play()
    }

    func playBallCatchSound() {
        // Happy ascending ding sound
        playTone(frequency: 880, duration: 0.08, volume: 0.4)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.playTone(frequency: 1100, duration: 0.12, volume: 0.3)
        }
    }

    func playCatCatchSound() {
        // Negative buzz sound
        playTone(frequency: 200, duration: 0.15, volume: 0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.playTone(frequency: 150, duration: 0.15, volume: 0.4)
        }
    }

    func playGameOverSound() {
        // Dramatic descending tones
        playTone(frequency: 440, duration: 0.2, volume: 0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.playTone(frequency: 330, duration: 0.2, volume: 0.5)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.playTone(frequency: 220, duration: 0.3, volume: 0.5)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            self.playTone(frequency: 165, duration: 0.5, volume: 0.6)
        }
    }

    func playLevelUpSound() {
        // Triumphant ascending tones
        playTone(frequency: 523, duration: 0.1, volume: 0.4)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.playTone(frequency: 659, duration: 0.1, volume: 0.4)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.playTone(frequency: 784, duration: 0.15, volume: 0.4)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.playTone(frequency: 1047, duration: 0.25, volume: 0.5)
        }
    }

    func showIntro() {
        // Create intro sprite with still image
        introNode = SKSpriteNode(imageNamed: "intro_image")
        introNode.size = CGSize(width: 350, height: 400)
        introNode.position = CGPoint(x: size.width / 2, y: size.height / 2 + 50)
        introNode.zPosition = 50
        addChild(introNode)

        // Add gentle bounce animation
        let moveUp = SKAction.moveBy(x: 0, y: 15, duration: 0.8)
        moveUp.timingMode = .easeInEaseOut
        let moveDown = SKAction.moveBy(x: 0, y: -15, duration: 0.8)
        moveDown.timingMode = .easeInEaseOut
        let bounce = SKAction.sequence([moveUp, moveDown])
        introNode.run(SKAction.repeatForever(bounce))

        // Add "Tap to Start" label
        tapToStartLabel = SKLabelNode(fontNamed: "Arial-BoldMT")
        tapToStartLabel.fontSize = 36
        tapToStartLabel.fontColor = .white
        tapToStartLabel.position = CGPoint(x: size.width / 2, y: 120)
        tapToStartLabel.zPosition = 100
        tapToStartLabel.text = "Tap to Start!"
        addChild(tapToStartLabel)

        // Pulse animation for tap label
        let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 0.5)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        let pulse = SKAction.sequence([fadeOut, fadeIn])
        tapToStartLabel.run(SKAction.repeatForever(pulse))

        // Start dropping tennis balls in background
        startIntroBalls()
    }

    func startIntroBalls() {
        guard !gameStarted else { return }

        // Spawn a tennis ball
        let ball = SKSpriteNode(imageNamed: "tennis_ball")
        ball.size = CGSize(width: 50, height: 50)
        ball.name = "introBall"

        let randomX = CGFloat.random(in: 30...(size.width - 30))
        ball.position = CGPoint(x: randomX, y: size.height + 30)
        ball.zPosition = 5

        // Random rotation
        let randomRotation = CGFloat.random(in: -3...3)
        ball.zRotation = randomRotation

        addChild(ball)

        // Animate falling with slight curve and spin
        let fallDuration = Double.random(in: 2.5...4.0)
        let curveX = CGFloat.random(in: -50...50)
        let spinAmount = CGFloat.random(in: -6...6)

        let fall = SKAction.moveTo(y: -50, duration: fallDuration)
        let curve = SKAction.moveBy(x: curveX, y: 0, duration: fallDuration)
        let spin = SKAction.rotate(byAngle: spinAmount, duration: fallDuration)
        let group = SKAction.group([fall, curve, spin])
        let remove = SKAction.removeFromParent()

        ball.run(SKAction.sequence([group, remove]))

        // Schedule next ball
        let nextDelay = SKAction.wait(forDuration: Double.random(in: 0.3...0.7))
        run(nextDelay) { [weak self] in
            self?.startIntroBalls()
        }
    }

    func startGame() {
        gameStarted = true

        // Remove intro elements
        introNode.removeAllActions()
        introNode.removeFromParent()
        tapToStartLabel.removeFromParent()

        // Remove any intro balls still on screen
        enumerateChildNodes(withName: "introBall") { node, _ in
            node.removeFromParent()
        }

        // Setup game elements
        setupDog()
        setupScoreLabel()
        setupLevelLabel()

        // Start spawning tennis balls
        startBallSpawning()

        // Start spawning cats after a delay so they don't sync with balls
        let initialCatDelay = SKAction.wait(forDuration: 2.0)
        run(initialCatDelay) { [weak self] in
            self?.startCatSpawning()
        }

        // Start spawning danger dog after a delay
        let dangerDogDelay = SKAction.wait(forDuration: 5.0)
        run(dangerDogDelay) { [weak self] in
            self?.startDangerDogSpawning()
        }
    }

    func startBallSpawning() {
        let currentTime = CACurrentMediaTime()
        let timeSinceLastSpawn = currentTime - lastSpawnTime

        if timeSinceLastSpawn < minimumSpawnGap {
            // Too soon, delay the spawn
            let delay = SKAction.wait(forDuration: minimumSpawnGap - timeSinceLastSpawn + 0.1)
            run(delay) { [weak self] in
                self?.startBallSpawning()
            }
            return
        }

        spawnTennisBall()
        lastSpawnTime = CACurrentMediaTime()

        // Random wait before next ball (uses current level settings)
        let randomWait = SKAction.wait(forDuration: Double.random(in: ballSpawnMin...ballSpawnMax))
        run(randomWait) { [weak self] in
            self?.startBallSpawning()
        }
    }

    func startCatSpawning() {
        let currentTime = CACurrentMediaTime()
        let timeSinceLastSpawn = currentTime - lastSpawnTime

        if timeSinceLastSpawn < minimumSpawnGap {
            // Too soon, delay the spawn
            let delay = SKAction.wait(forDuration: minimumSpawnGap - timeSinceLastSpawn + 0.1)
            run(delay) { [weak self] in
                self?.startCatSpawning()
            }
            return
        }

        spawnCat()
        lastSpawnTime = CACurrentMediaTime()

        // Random wait before next cat (uses current level settings)
        let randomWait = SKAction.wait(forDuration: Double.random(in: catSpawnMin...catSpawnMax))
        run(randomWait) { [weak self] in
            self?.startCatSpawning()
        }
    }

    func setupDog() {
        dogNode = SKSpriteNode(imageNamed: "dog")
        dogNode.size = CGSize(width: 150, height: 150)
        dogNode.position = CGPoint(x: size.width / 2, y: 200)
        dogNode.zPosition = 10

        dogNode.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 100, height: 100))
        dogNode.physicsBody?.isDynamic = false
        dogNode.physicsBody?.categoryBitMask = dogCategory
        dogNode.physicsBody?.contactTestBitMask = ballCategory | catCategory | dangerDogCategory
        dogNode.physicsBody?.collisionBitMask = 0

        addChild(dogNode)
    }

    func setupScoreLabel() {
        scoreLabel = SKLabelNode(fontNamed: "Arial-BoldMT")
        scoreLabel.fontSize = 48
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height - 100)
        scoreLabel.zPosition = 100
        scoreLabel.text = "Score: 0"
        addChild(scoreLabel)
    }

    func setupLevelLabel() {
        levelLabel = SKLabelNode(fontNamed: "Arial-BoldMT")
        levelLabel.fontSize = 32
        levelLabel.fontColor = .yellow
        levelLabel.position = CGPoint(x: size.width / 2, y: size.height - 150)
        levelLabel.zPosition = 100
        levelLabel.text = "Level: 1"
        addChild(levelLabel)
    }

    func checkLevelUp() {
        let newLevel = (score / 10) + 1
        if newLevel > level && newLevel > 0 {
            level = newLevel
            levelLabel.text = "Level: \(level)"

            // Play level up sound
            playLevelUpSound()

            // Change background color for new level
            backgroundColor = colorForLevel(level)

            // Speed up the game
            gravityStrength *= 1.3
            physicsWorld.gravity = CGVector(dx: 0, dy: gravityStrength)

            // Decrease spawn intervals (faster spawning)
            ballSpawnMin = max(0.5, ballSpawnMin * 0.85)
            ballSpawnMax = max(0.8, ballSpawnMax * 0.85)
            catSpawnMin = max(1.2, catSpawnMin * 0.85)
            catSpawnMax = max(2.0, catSpawnMax * 0.85)
            minimumSpawnGap = max(0.4, minimumSpawnGap * 0.9)

            // Level up animation
            let scaleUp = SKAction.scale(to: 1.5, duration: 0.2)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.2)
            levelLabel.run(SKAction.sequence([scaleUp, scaleDown]))

            // Start/continue danger dog spawning at all levels
            startDangerDogSpawning()
        }
    }

    func colorForLevel(_ level: Int) -> SKColor {
        let colors: [SKColor] = [
            SKColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1.0),  // Level 1: Sky blue
            SKColor(red: 0.6, green: 0.85, blue: 0.6, alpha: 1.0),   // Level 2: Light green
            SKColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1.0),   // Level 3: Golden yellow
            SKColor(red: 1.0, green: 0.6, blue: 0.4, alpha: 1.0),    // Level 4: Orange
            SKColor(red: 0.9, green: 0.5, blue: 0.5, alpha: 1.0),    // Level 5: Salmon red
            SKColor(red: 0.7, green: 0.5, blue: 0.85, alpha: 1.0),   // Level 6: Purple
            SKColor(red: 0.5, green: 0.5, blue: 0.7, alpha: 1.0),    // Level 7: Steel blue
            SKColor(red: 0.4, green: 0.6, blue: 0.6, alpha: 1.0),    // Level 8: Teal
            SKColor(red: 0.85, green: 0.6, blue: 0.75, alpha: 1.0),  // Level 9: Pink
            SKColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 1.0)     // Level 10+: Dark gray
        ]
        let index = min(level - 1, colors.count - 1)
        return colors[index]
    }

    func spawnTennisBall() {
        let ball = SKSpriteNode(imageNamed: "tennis_ball")
        ball.size = CGSize(width: 60, height: 60)

        let randomX = CGFloat.random(in: 50...(size.width - 50))
        ball.position = CGPoint(x: randomX, y: size.height + 50)
        ball.zPosition = 5

        ball.physicsBody = SKPhysicsBody(circleOfRadius: 30)
        ball.physicsBody?.categoryBitMask = ballCategory
        ball.physicsBody?.contactTestBitMask = dogCategory
        ball.physicsBody?.collisionBitMask = 0
        ball.physicsBody?.restitution = 0.3

        addChild(ball)

        let waitAction = SKAction.wait(forDuration: 5)
        let removeAction = SKAction.removeFromParent()
        ball.run(SKAction.sequence([waitAction, removeAction]))
    }

    func spawnCat() {
        let cat = SKSpriteNode(imageNamed: "cat")
        cat.size = CGSize(width: 100, height: 100)

        let randomX = CGFloat.random(in: 50...(size.width - 50))
        cat.position = CGPoint(x: randomX, y: size.height + 50)
        cat.zPosition = 5
        cat.name = "cat"

        // Smaller hitbox so cat is harder to catch
        cat.physicsBody = SKPhysicsBody(circleOfRadius: 20)
        cat.physicsBody?.categoryBitMask = catCategory
        cat.physicsBody?.contactTestBitMask = dogCategory
        cat.physicsBody?.collisionBitMask = 0
        cat.physicsBody?.restitution = 0.3

        addChild(cat)

        let waitAction = SKAction.wait(forDuration: 5)
        let removeAction = SKAction.removeFromParent()
        cat.run(SKAction.sequence([waitAction, removeAction]))
    }

    func startDangerDogSpawning() {
        guard gameStarted else { return }

        // Spawn chance increases with level:
        // Level 1: 8%, Level 2: 15%, Level 3: 25%, Level 4: 40%, Level 5: 55%, Level 6+: 70%+
        var spawnChance: Double
        switch level {
        case 1: spawnChance = 0.08
        case 2: spawnChance = 0.15
        case 3: spawnChance = 0.25
        case 4: spawnChance = 0.40
        case 5: spawnChance = 0.55
        default: spawnChance = min(0.85, 0.55 + Double(level - 5) * 0.10)
        }

        if Double.random(in: 0...1) < spawnChance {
            spawnDangerDog()
        }

        // Schedule next check - less frequent early, more frequent later
        // Level 1: 10-12s, Level 2: 8-10s, Level 3: 6-8s, Level 4: 5-7s, Level 5+: 3-5s
        var baseDelay: Double
        switch level {
        case 1: baseDelay = 10.0
        case 2: baseDelay = 8.0
        case 3: baseDelay = 6.0
        case 4: baseDelay = 5.0
        case 5: baseDelay = 4.0
        default: baseDelay = max(2.5, 4.0 - Double(level - 5) * 0.3)
        }

        let nextDelay = SKAction.wait(forDuration: Double.random(in: baseDelay...(baseDelay + 2.0)))
        run(nextDelay) { [weak self] in
            self?.startDangerDogSpawning()
        }
    }

    func spawnDangerDog() {
        let dangerDog = SKSpriteNode(imageNamed: "danger_dog")
        dangerDog.size = CGSize(width: 90, height: 155)

        let randomX = CGFloat.random(in: 50...(size.width - 50))
        dangerDog.position = CGPoint(x: randomX, y: size.height + 70)
        dangerDog.zPosition = 6
        dangerDog.name = "dangerDog"

        dangerDog.physicsBody = SKPhysicsBody(circleOfRadius: 35)
        dangerDog.physicsBody?.categoryBitMask = dangerDogCategory
        dangerDog.physicsBody?.contactTestBitMask = dogCategory
        dangerDog.physicsBody?.collisionBitMask = 0
        dangerDog.physicsBody?.restitution = 0.3

        addChild(dangerDog)

        let waitAction = SKAction.wait(forDuration: 6)
        let removeAction = SKAction.removeFromParent()
        dangerDog.run(SKAction.sequence([waitAction, removeAction]))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        // Check if game over screen is showing (restart label exists)
        if childNode(withName: "restartLabel") != nil {
            restartGame()
            return
        }

        if !gameStarted {
            startGame()
            return
        }

        let location = touch.location(in: self)
        moveDog(to: location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameStarted else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        moveDog(to: location)
    }

    func moveDog(to position: CGPoint) {
        var newX = position.x
        var newY = position.y

        let minX: CGFloat = 75
        let maxX: CGFloat = size.width - 75
        let minY: CGFloat = 75
        let maxY: CGFloat = size.height - 150

        newX = max(minX, min(maxX, newX))
        newY = max(minY, min(maxY, newY))

        dogNode.position = CGPoint(x: newX, y: newY)
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        if collision == dogCategory | ballCategory {
            let ball = contact.bodyA.categoryBitMask == ballCategory ? contact.bodyA.node : contact.bodyB.node
            ball?.removeFromParent()

            score += 1
            scoreLabel.text = "Score: \(score)"
            checkLevelUp()

            // Play happy sound
            playBallCatchSound()

            let scaleUp = SKAction.scale(to: 1.2, duration: 0.1)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
            dogNode.run(SKAction.sequence([scaleUp, scaleDown]))
        }

        if collision == dogCategory | catCategory {
            let cat = contact.bodyA.categoryBitMask == catCategory ? contact.bodyA.node : contact.bodyB.node
            cat?.removeFromParent()

            score -= 1
            scoreLabel.text = "Score: \(score)"

            // Play negative sound
            playCatCatchSound()

            // Shake animation for catching the cat
            let moveLeft = SKAction.moveBy(x: -10, y: 0, duration: 0.05)
            let moveRight = SKAction.moveBy(x: 20, y: 0, duration: 0.1)
            let moveBack = SKAction.moveBy(x: -10, y: 0, duration: 0.05)
            dogNode.run(SKAction.sequence([moveLeft, moveRight, moveBack]))
        }

        if collision == dogCategory | dangerDogCategory {
            let dangerDog = contact.bodyA.categoryBitMask == dangerDogCategory ? contact.bodyA.node : contact.bodyB.node

            // Play game over sound
            playGameOverSound()

            // Game Over with animation!
            gameOverWithAnimation(caughtDog: dangerDog as? SKSpriteNode)
        }
    }

    func gameOverWithAnimation(caughtDog: SKSpriteNode?) {
        gameStarted = false

        // Stop all spawning
        removeAllActions()

        // Remove all falling objects except the caught danger dog
        enumerateChildNodes(withName: "cat") { node, _ in node.removeFromParent() }
        enumerateChildNodes(withName: "dangerDog") { node, _ in
            if node != caughtDog {
                node.removeFromParent()
            }
        }
        children.filter { $0.physicsBody?.categoryBitMask == ballCategory }.forEach { $0.removeFromParent() }

        // Hide game elements
        dogNode.isHidden = true
        scoreLabel.isHidden = true
        levelLabel.isHidden = true

        // Animate the caught danger dog
        if let dog = caughtDog {
            dog.removeAllActions()
            dog.physicsBody = nil
            dog.zPosition = 200
            dog.name = "spinningDog"

            // Move to center and spin for 2 seconds
            let moveToCenter = SKAction.move(to: CGPoint(x: size.width / 2, y: size.height / 2), duration: 0.3)
            let spin = SKAction.rotate(byAngle: CGFloat.pi * 8, duration: 2.0)

            // Then grow to fill screen
            let targetSize = max(size.width, size.height) * 1.2
            let scaleRatio = targetSize / max(dog.size.width, dog.size.height)
            let grow = SKAction.scale(by: scaleRatio, duration: 0.8)
            grow.timingMode = .easeIn

            let sequence = SKAction.sequence([
                moveToCenter,
                spin,
                grow
            ])

            dog.run(sequence) { [weak self] in
                self?.showGameOverText()
            }
        } else {
            showGameOverText()
        }
    }

    func showGameOverText() {
        // Game over text with effect
        let gameOverLabel = SKLabelNode(fontNamed: "Arial-BoldMT")
        gameOverLabel.fontSize = 48
        gameOverLabel.fontColor = .red
        gameOverLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 50)
        gameOverLabel.zPosition = 300
        gameOverLabel.text = "GAME OVER!"
        gameOverLabel.name = "gameOverLabel"
        gameOverLabel.alpha = 0
        gameOverLabel.setScale(0.1)
        addChild(gameOverLabel)

        // Show final score
        let finalScoreLabel = SKLabelNode(fontNamed: "Arial-BoldMT")
        finalScoreLabel.fontSize = 32
        finalScoreLabel.fontColor = .white
        finalScoreLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 20)
        finalScoreLabel.zPosition = 300
        finalScoreLabel.text = "Final Score: \(score)"
        finalScoreLabel.name = "finalScoreLabel"
        finalScoreLabel.alpha = 0
        addChild(finalScoreLabel)

        // Show tap to restart
        let restartLabel = SKLabelNode(fontNamed: "Arial-BoldMT")
        restartLabel.fontSize = 24
        restartLabel.fontColor = .yellow
        restartLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 80)
        restartLabel.zPosition = 300
        restartLabel.text = "Tap to Restart"
        restartLabel.name = "restartLabel"
        restartLabel.alpha = 0
        addChild(restartLabel)

        // Game over drops in with bounce effect
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.3)
        let scaleBounce = SKAction.scale(to: 1.0, duration: 0.15)
        let dropIn = SKAction.group([fadeIn, scaleUp])
        let gameOverEffect = SKAction.sequence([dropIn, scaleBounce])
        gameOverLabel.run(gameOverEffect)

        let delayedFade = SKAction.sequence([SKAction.wait(forDuration: 0.3), fadeIn])
        finalScoreLabel.run(delayedFade)

        let delayedFade2 = SKAction.sequence([SKAction.wait(forDuration: 0.6), fadeIn])
        restartLabel.run(delayedFade2) {
            // Start pulse animation after fade in
            let fadeOut = SKAction.fadeAlpha(to: 0.3, duration: 0.5)
            let fadeBack = SKAction.fadeAlpha(to: 1.0, duration: 0.5)
            restartLabel.run(SKAction.repeatForever(SKAction.sequence([fadeOut, fadeBack])))
        }
    }

    func restartGame() {
        // Remove game over elements
        childNode(withName: "gameOverLabel")?.removeFromParent()
        childNode(withName: "finalScoreLabel")?.removeFromParent()
        childNode(withName: "bigDangerDog")?.removeFromParent()
        childNode(withName: "restartLabel")?.removeFromParent()
        childNode(withName: "spinningDog")?.removeFromParent()

        // Reset game state
        score = 0
        level = 1
        gravityStrength = -2.0
        ballSpawnMin = 1.2
        ballSpawnMax = 2.0
        catSpawnMin = 2.5
        catSpawnMax = 4.0
        minimumSpawnGap = 0.8
        lastSpawnTime = 0

        // Reset physics
        physicsWorld.gravity = CGVector(dx: 0, dy: gravityStrength)

        // Reset background
        backgroundColor = colorForLevel(1)

        // Show and reset dog
        dogNode.isHidden = false
        dogNode.position = CGPoint(x: size.width / 2, y: 200)

        // Show labels
        scoreLabel.isHidden = false
        scoreLabel.text = "Score: 0"
        levelLabel.isHidden = false
        levelLabel.text = "Level: 1"

        // Start the game
        gameStarted = true

        // Start spawning
        startBallSpawning()
        let catDelay = SKAction.wait(forDuration: 2.0)
        run(catDelay) { [weak self] in
            self?.startCatSpawning()
        }
    }
}
