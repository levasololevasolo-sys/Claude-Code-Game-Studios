## Aiming the secondary weapon (GDD weapons-and-loot §3.4, «Прицел»): while the
## `aim` action is held, shots of the aimable kinds fly toward the mouse cursor
## (any of 360°) or the right stick; without it they fly straight by facing.
## Pure static functions, so the rules are unit-tested without a tree.
class_name AimRules
extends RefCounted

## subweapons.json `type` values that follow the aim (shots, the thrown pot,
## the returning axes). Placed kinds (trap, spikes, totem) and the area kinds
## (chain, gust, ring) only take the facing.
const AIMED_TYPES: Array[String] = ["shot", "bomb", "axes"]

## True when a secondary weapon of row `row` follows the aim.
static func aimable(row: Dictionary) -> bool:
	return String(row.get("type", "")) in AIMED_TYPES

## Unit direction of a shot.
## `aiming`: the aim action is held. `pad`: the last input came from a gamepad
## (then `stick` is the right stick, else `cursor` is the mouse in world space).
## `from`: the hand in world space. Falls back to (face, 0) without aim, with a
## stick inside `deadzone`, or with the cursor on the hand.
static func direction(aiming: bool, pad: bool, from: Vector2, cursor: Vector2, stick: Vector2, face: int, deadzone: float) -> Vector2:
	var fallback := Vector2(1.0 if face >= 0 else -1.0, 0.0)
	if not aiming:
		return fallback
	var d := stick if pad else cursor - from
	if pad and d.length() < deadzone:
		return fallback
	if d.length() < 0.001:
		return fallback
	return d.normalized()

## Facing that matches `dir`: its horizontal side, `face` when it points straight up / down.
static func face_of(dir: Vector2, face: int) -> int:
	if absf(dir.x) < 0.001:
		return face
	return 1 if dir.x > 0.0 else -1

## Launch velocity of the thrown pot (type "bomb") along `dir`: the same launch
## speed as the unaimed arc (|(speed, up)|), so the range stays its own.
static func bomb_velocity(dir: Vector2, speed: float, up: float) -> Vector2:
	return dir * Vector2(speed, up).length()

## Velocity of axe `i` of `n` along `dir`: `speed` forward plus `spread` px/s
## across, the same fan as the unaimed pair (which is the dir = (face, 0) case).
static func axe_velocity(dir: Vector2, speed: float, i: int, n: int, spread: float) -> Vector2:
	var dy := (i - (n - 1) / 2.0) * spread
	var across := Vector2(-dir.y, dir.x) * (1.0 if dir.x >= 0.0 else -1.0)
	return dir * speed + across * dy

## How far the aim line reaches for `row`: a shot's flight (speed × life), or
## `fallback` px for kinds without both numbers.
static func line_length(row: Dictionary, fallback: float) -> float:
	if row.has("speed") and row.has("life"):
		return float(row.speed) * float(row.life)
	return fallback
