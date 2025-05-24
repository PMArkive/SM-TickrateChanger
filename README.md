# Runtime Tickrate Changer

Allows changing the tickrate of the server at runtime.
Thanks to [ficool2](https://github.com/ficool2) for discovering this method.

As of now, this only supports **Team Fortress 2** on **Linux**.

## Requirements

* [SourceMod 1.12+](https://www.sourcemod.net)

## Instructions

This plugin only has one convar: `sm_tickrate`.

You need to set it **before** level change for it to have any effect.
It is safe to do so at any time, as the new tickrate will only be applied after map end.

Setting the tickrate to `0` will return the default tickrate.

If you need the tickrate to be applied on server start, use the `-tickrate` launch parameter.