# Changelog


## v0.0.0

- docs: add initial project README
Document the permitted commercial and proprietary use of the library. Explain the MPL-2.0 requirements for internal use and distributed Godot projects, including PCK exports and modified source files. Add practical distribution examples, third-party notice and EULA templates, installation instructions, and contribution guidance.
- chore: license project under MPL-2.0
Add the official Mozilla Public License 2.0 text as the project's license file.
- docs: add how to use the library example
Provided an example usage in README.
- docs: fix codeblock typo
Fix a codeblock typo in How to Use section preventing it from displaying it correctly.
- chore: add Godot-specific .gitignore rules
Add Godot-specific .gitignore rules. Ignore generated cache and import data, temporary files, export credentials, OS metadata, and local build outputs.


## v0.0.1

- feat(core): add AGGL API and enemy factory
Add the AGGL core class as the public entry point of the library. Expose the library and API versions, add an API compatibility check, preload the default EnemyBase2D scene, provide a factory method for creating enemy instances, add SPDX copyright and MPL-2.0 license identifiers.


## v0.1.0

- docs: add CHANGELOG.
- docs: add Artwork and Attached MPL-2.0 Code section in README.
- feat(enemies): add animated EnemyBase2D foundation
Add a reusable EnemyBase2D scene with initial sprite assets, configured animations, and basic gameplay logic, add EnemyBase2D as a reusable CharacterBody2D class, configure AnimatedSprite2D and CollisionShape2D references, add animations for idle, walking, turning, attacking, taking damage, and dying Support separate left- and right-facing movement animations, add configurable maximum and current health values Emit health_changed and died signals for gameplay integration, declare attack-related signals for future combat-system integration, add basic physics movement using move_and_slide(), stop movement, disable collisions, and remove the enemy after its death animation, prevent the death sequence from running multiple times.


##v0.1.1

- docs: remove Artworks and Attached MPL-2.0 Code section
Remove Attached MPL-2.0 Code and Artworks sections because they do not fit to the general vision and use of this project.


##v0.2.0

- feat(health): add reusable HealthComponent
Add a reusable health state component for characters and other damageable
game objects: Support damage, healing, death, revival, and direct health changes, clamp current and maximum health to valid ranges, return the actual applied damage and healing values, add configurable invulnerability and healing-based revival, emit signals for health changes and state transitions, support runtime maximum-health changes with optional ratio preservation, forward an optional source with damage, healing, death, and revival events, keep armor, resistances, hit reactions, and animations outside the component.
