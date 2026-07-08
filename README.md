# Godot Top-Down Starter

This is a minimal Godot 2D top-down starter with:
- White background
- One controllable player character
- Camera following the player

## Controls
- Arrow keys
- WASD

## Open and Run
1. Open Godot.
2. Import this folder as a project.
3. Run the main scene (`scenes/main.tscn`).

## Add Your Own Graphics
- In `scenes/main.tscn`, the `Player/Body` node is a temporary `Polygon2D` placeholder.
- Replace it with a `Sprite2D` or `AnimatedSprite2D` and assign your own textures.
- Keep the `CharacterBody2D` node and `scripts/player.gd` script for movement.

## Directional Animation Setup
The player script is already wired for top-down idle/walk states with an `AnimatedSprite2D` node.

Create a `SpriteFrames` resource on `Player/AnimatedSprite2D` and add these animations:
- `idle_down`
- `idle_up`
- `idle_left`
- `idle_right`
- `walk_down`
- `walk_up`
- `walk_left`
- `walk_right`

Once those animations contain frames, they will play automatically. Until then, the placeholder triangle (`Player/Body`) stays visible.

## Included Test Art
Basic temporary sprites are included so you can test movement right away:
- Player directional states in `assets/player/`
- Object sprites in `assets/objects/` (trees, rocks, boxes)

The main scene already places a few objects around the player so it is easy to see movement across the map.
