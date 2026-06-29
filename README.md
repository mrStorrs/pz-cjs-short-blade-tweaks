# CJS Short Blade Tweaks

Build 42 Project Zomboid mod that adjusts short-blade combat:

- Short-blade ground stab animation defaults to 50% faster.
- Holding the manual floor-attack key forces the short-blade floor-stab path, including the close-range knife case where vanilla can otherwise pick a standing close-kill.
- Jaw-stab critical animation blends default to 50% faster.
- Jaw-stab kills clean up the `JawStab` zombie attachment and restore the attacking short blade to the player hand when the game detaches it.
- Sandbox options can adjust ground-stab speed, jaw-stab speed, and the anti-stuck cleanup toggle.

The animation overrides cover both `player` and `player-vehicle` B42 animation sets. Normal short-blade attacks stay on vanilla `CombatSpeed`; only floor stabs and jaw-stab execution nodes use the custom speed variables. The Lua hook is intentionally scoped to weapons whose script categories include `SmallBlade`.
