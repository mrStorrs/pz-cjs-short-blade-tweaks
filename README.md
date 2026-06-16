# CJS Short Blade Tweaks

Build 42 Project Zomboid mod that adjusts short-blade combat:

- Short-blade ground stab animation runs about 30% faster.
- Jaw-stab critical animation blends run about 30% faster.
- Jaw-stab kills clean up the `JawStab` zombie attachment and restore the attacking short blade to the player hand when the game detaches it.

The animation overrides cover both `player` and `player-vehicle` B42 animation sets. The Lua hook is intentionally scoped to weapons whose script categories include `SmallBlade`.
