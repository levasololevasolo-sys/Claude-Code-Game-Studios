## Global signal bus (architecture.md §4). Declarations only: no logic, no state.
## Signals are past tense. Typed loosely (Node2D, RefCounted) because the core
## layer must not know the combat or enemy classes. Autoload name: Events.
extends Node

## An enemy's hp reached 0. `enemy` is an Enemy, `hit` the Hit that killed it.
@warning_ignore("unused_signal")
signal enemy_killed(enemy: Node2D, hit: RefCounted)
## The hero lost `amount` hp to `hit` (shield-absorbed damage is not counted).
@warning_ignore("unused_signal")
signal player_hurt(amount: float, hit: RefCounted)
## The hero released a Flare: amulet shape id, power P (amulet-and-flare §3.3).
@warning_ignore("unused_signal")
signal flare_fired(shape: String, power: float)
