# SPDX-FileCopyrightText: 2026 Johannes M. Ewers
# SPDX-License-Identifier: MPL-2.0

class_name AGGL
extends RefCounted


## Semantic version number of the currently installed AGGL version.
const VERSION: String = "0.1.0"

## Compatibility level of the public API.
##
## Higher values must remain backward-compatible with the requirements
## of lower API levels.
const API_VERSION: int = 1


## Returns the semantic version number of the library.
static func get_version() -> String:
	return VERSION


## Checks whether the library supports at least the required API level.
static func supports_api(required_version: int) -> bool:
	return API_VERSION >= required_version


## Preloaded default scene for two-dimensional enemies.
##
## The scene's root node must be an EnemyBase2D.
const ENEMY_BASE_2D_SCENE: PackedScene = preload(
	"res://addons/Advanced GDScript Game Library/gameplay/characters/enemies/enemy_base_2d.tscn"
)


## Creates a new instance of the default EnemyBase2D scene.
static func create_enemy_2d() -> EnemyBase2D:
	return ENEMY_BASE_2D_SCENE.instantiate() as EnemyBase2D
