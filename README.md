# CJS Short Blade Tweaks

Build 42 Project Zomboid mod that adjusts short-blade combat:

- Short-blade ground stab animation defaults to 50% faster.
- Short-blade floor-stab animation follows the vanilla `AimFloorAnim` attack state without writing combat state from Lua.
- Jaw-stab critical animation blends default to 50% faster.
- Jaw-stab kills clean up the `JawStab` zombie attachment and restore the attacking short blade to the player hand when the game detaches it.
- Sandbox options can adjust ground-stab speed, jaw-stab speed, and the anti-stuck cleanup toggle.

The animation overrides cover both `player` and `player-vehicle` B42 animation sets. Normal short-blade attacks stay on vanilla `CombatSpeed`; only floor stabs and jaw-stab execution nodes use the custom speed variables. Jaw-stab cleanup is scoped to weapons whose script categories include `SmallBlade`.
