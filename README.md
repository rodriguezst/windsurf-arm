<h1>
    <img src="./logo.png" width="64px" align="center">
    Windsurf for ARM
</h1>

[Windsurf](https://windsurf.codeium.com) built for Linux and Windows ARM.

> [!NOTE]
> These are unofficial builds.

## Install

Download the [latest release](https://github.com/rodriguezst/windsurf-arm/releases/latest) and execute it.

For Nix users: `nix run github:rodriguezst/windsurf-arm` (this should work for all architectures, not just arm).

## FAQ

### How is this possible?

Windsurf is a fork of VS Code based on Electron that distributes using `.tar.gz` archives. The contents are virtually the same as the built and distributed archives of VS Code.

Overwriting the JavaScript for VS Code with Windsurf's archive creates a Windsurf build.

```bash
cp -R $windsurfSrc/resources/app/out $vscodeSrc/resources/app/
```

See the [build process](./flake.nix#L48) to see exactly how this works.

### Shouldn't Windsurf do this?

Yes. Hopefully they will!

### Is this stable?

Seemingly. The [build process](./flake.nix#L48) is quite simple. Try it for yourself!

### How do updates work?

The Nix flake will be updated as Windsurf updates and a new GitHub release will be published.

Automatic updates do not work.
