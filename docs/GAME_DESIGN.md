# GAME DESIGN DOCUMENT - BEATS & SHAPES

## Core Gameplay Mechanics (Cloning Just Shapes & Beats)

### The Player (The Shape)
- **Small Shape:** A simple geometric shape (Square, Triangle, Pentagon, Circle).
- **Movement:** 1:1 touch tracking. The shape follows the finger with 0.1mm precision.
- **The Dash:** A quick swipe gesture that provides a burst of speed and temporary invulnerability.
- **Health System:**
    - **Normal Tracks:** 3 hits until "Break".
    - **Boss Tracks:** 6 hits until "Break".
    - **Visual Damage:** Shape "shatters" or loses pieces when hit.
    - **Mercy Period:** Brief invincibility window after taking damage.

### The Obstacles (The Beats)
- **Pink Everything:** All harmful objects are bright pink.
- **Beat-Sync:** Obstacles pulse, spawn, and move strictly to the music's rhythm.
- **Core Patterns:**
    - **Beams:** Linear warning lines that fill up and blast.
    - **Waves:** Expanding circular or horizontal pulses.
    - **Projectiles:** Bouncing circles or aimed shapes.
    - **Walls:** Large shifting areas that force player movement.

### Controls (iPad Optimized)
- **Primary:** Drag anywhere to move the shape.
- **Dash:** Fast swipe in any direction.
- **UI:** Large 44x44pt buttons for song selection and settings.

## Level Design (The "Beats")

### Iteration 1: Core Experience (The 5 EDM Tracks)
- **5 Hand-crafted Beats:** 5 high-energy EDM tracks with AI-generated patterns designed for a 6-year-old.
- **Difficulty:** Accessible but visually exciting.
- **No Death Mode (Optional):** A "Braxton Mode" where the shape doesn't break, perfect for learning.

### Visual Aesthetic
- **High Contrast:** Neon colors on a deep black background.
- **Dynamic Camera:** Screen shake, zoom pulses, and color shifts triggered by the music.
- **Progress Bar:** A simple bar at the top showing level completion.

## Game Modes

### Story Mode (Iteration 2+)
- A simple journey through different musical "worlds".
- Introduction of Boss Battles: Large, complex patterns synchronized with musical drops.

### Free Play (Iteration 1)
- Select from the 5 initial beats and jump straight in.

### Party Mode
- Automatic playback of levels for visual/audio background, with "drop-in" play support.

## Sound Design
- **Key Sync:** Sound effects for dashing and taking damage are pitched to match the current track's musical key.
- **Audio Priority:** Music volume is the primary focus, with game SFX layered on top without muddying the mix.
