# Runtime Tickrate Changer

Allows changing the tickrate of the server at runtime.
Thanks to [ficool2](https://github.com/ficool2) for discovering this method.

As of now, this only supports **Team Fortress 2** on **Linux**.

## Requirements

* [SourceMod 1.12+](https://www.sourcemod.net)

## Instructions

The plugin defines a console command `sm_tickrate` and a console variable `sm_interval_per_tick`.

You need to call or set either of these **before** level change for it to have any effect.
It is safe to do so at any time, as the new tickrate will only be applied after map end.

Calling `sm_tickrate` with a value of `0` will return the server to the default tickrate.

If you need the tickrate to be applied on server start, use the `-tickrate` launch parameter. This will also make the tickrate persist throughout the server's lifetime.