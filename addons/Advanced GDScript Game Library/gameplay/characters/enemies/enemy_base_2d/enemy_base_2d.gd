# SPDX-FileCopyrightText: 2026 Johannes M. Ewers
# SPDX-License-Identifier: MPL-2.0

class_name EnemyBase2D
extends CharacterBody2D


## Reference to the enemy's animated sprite, resolved when the node is ready.
@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D

## Reference to the enemy's collision shape, resolved when the node is ready.
@onready var collision_shape: CollisionShape2D = %CollisionShape2D


## Indicates whether this enemy is currently performing its death sequence.
## This prevents the sequence from being started more than once.
var is_dying: bool = false


## Emitted when this enemy's health changes.
## Provides the current and maximum health values.
signal health_changed(current_health: int, maximum_health: int)

## Emitted when this enemy performs an attack.
## [param enemy] is the enemy performing the attack.
signal attacked(enemy: EnemyBase2D)

## Emitted when this enemy is attacked.
## [param enemy] is the enemy that was attacked.
signal was_attacked(enemy: EnemyBase2D)

## Emitted when this enemy dies.
## [param enemy] is the enemy that died.
signal died(enemy: EnemyBase2D)


@export_category("Health")
@export_range(1, 100_000, 1)
var maximum_health: int = 100
var current_health: int


# Executed once when the node and its children are ready.
func _ready() -> void:
	current_health = maximum_health
	animated_sprite.play(&"idle")

# Executed in every rendered frame.
func _process(delta: float) -> void:
	pass

# Executed at a fixed rate for physics-related updates.
func _physics_process(delta: float) -> void:
	move_and_slide()

func walk_left() -> void:
	animated_sprite.play(&"walk_left")
	await animated_sprite.animation_finished

func turn_left() -> void:
	animated_sprite.play(&"turn_left")
	await animated_sprite.animation_finished

	# Can be replaced later with a custom idle_left animation.
	animated_sprite.pause()

func walk_right() -> void:
	animated_sprite.play(&"walk_right")
	await animated_sprite.animation_finished

func turn_right() -> void:
	animated_sprite.play(&"turn_right")
	await animated_sprite.animation_finished

	# Can be replaced later with a custom idle_left animation.
	animated_sprite.pause()

func attack() -> void:
	velocity = Vector2.ZERO

	animated_sprite.play(&"attack")

	# Transition from the charging frame to the hit frame.
	await animated_sprite.frame_changed
	# deal_damage() / damage_to_player()

	await animated_sprite.animation_finished
	animated_sprite.play(&"idle")

func take_damage(amount: int) -> void:
	if amount <= 0 or current_health <= 0:
		return
	animated_sprite.play(&"hit")
	await animated_sprite.animation_finished
	animated_sprite.play(&"idle")

	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, maximum_health)

	if current_health == 0:
		die()
	###
	if current_health <= 0:
		return

	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, maximum_health)

	if current_health == 0:
		die()


## Starts the enemy's death sequence.
##
## This method deliberately does not check the enemy's health. Death may be
## caused by lethal damage, an instant-death spell, or a scripted event.
func die() -> void:
	# Ignore additional death requests while the sequence is already running.
	if is_dying:
		return

	is_dying = true

	# Stop movement and prevent further physics updates.
	velocity = Vector2.ZERO
	set_physics_process(false)

	# Prevent further physical interactions during the death animation.
	collision_shape.set_deferred(&"disabled", true)

	# Notify other systems that this enemy is now considered dead.
	died.emit(self)

	# Play the non-looping death animation before removing the enemy.
	animated_sprite.play(&"death")
	await animated_sprite.animation_finished

	queue_free()
