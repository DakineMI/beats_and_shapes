# TECHNICAL_DESIGN.md - BEATS & SHAPES

## Core Architecture

### Engine: SpriteKit + Metal
- **Native Performance:** Direct usage of Swift 6 and SpriteKit for the 120Hz iPad M2.
- **Metal Post-Processing:** Custom shaders for the neon glow, screen shake, and rhythmic pulses.

### Audio: AVAudioEngine
- **Rhythmic Timing:** Using `AVAudioEngine` for high-precision timekeeping.
- **FFT Analysis:** Real-time frequency analysis to drive visual pulses in the background.

### Pattern System (The AI Generation)
- **JSON Pattern Mapping:** Beat patterns stored as lightweight JSON sequences.
- **AI Integration (Iteration 2):** Using OpenAI/Claude to generate these JSON sequences based on track BPM and structural analysis.

## Implementation Roadmap (Build Order)

### Iteration 1: Core Experience
1. **The Shape:** Implement 1:1 touch movement and swipe-dash.
2. **The Beats:** Implement the 5 EDM tracks with pre-mapped rhythmic patterns.
3. **Collision:** High-precision pink-shape collision detection.
4. **Braxton Mode:** Simple UI to launch the 5 levels with "Invincible" toggle.

### Iteration 2: Content Expansion
1. **The Campaign:** World-based level progression.
2. **Boss System:** Large-scale SpriteKit nodes with complex movement logic.
3. **The Editor:** Simple UI for placing obstacles on a timeline.

### Iteration 3: Ecosystem
1. **Platform Hooks:** YouTube API and MusicKit track loading.
2. **Sync:** CloudKit for high scores and custom level sharing.
