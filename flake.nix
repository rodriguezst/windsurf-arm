{
  description = "Flake for building Windsurf on Linux ARM and Windows ARM platforms";

  inputs = {
    # Pinned to align the version of VS Codium with Windsurf's build.
    nixpkgs.url = "github:NixOS/nixpkgs/823f850f6b269dec3e515ee1c070adc9cb0bcb33";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "aarch64-linux" "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };

          # This is the VS Code version that Windsurf was built on.
          vscodeVersion = "1.94.0";

          # Version of Windsurf being built
          windsurfVersion = "1.3.4";

          # Defined in /resources/app/extensions/windsurf/dist/extension.js
          # t.LANGUAGE_SERVER_VERSION="1.30.0"
          languageServerVersion = "1.36.1";

          windsurfSrc = builtins.fetchTarball {
            url = "https://windsurf-stable.codeiumdata.com/linux-x64/stable/ff5014a12e72ceb812f9e7f61876befac66725e5/Windsurf-linux-x64-1.3.4.tar.gz";
            sha256 = "sha256:0j13nyb59cyj4qlpdfdcrbljpaafq5msr8llvdnrk3a3fg6ihbaw";
          };
          vscodeLinuxArm64 = builtins.fetchTarball {
            url = "https://update.code.visualstudio.com/${vscodeVersion}/linux-arm64/stable";
            sha256 = "sha256:0gbl94ai7jdwl31fvsac3mg5lr7f7di6pslbxjwfmsnxs3g2gvcp";
          };
          vscodeWindowsArm64 = pkgs.fetchzip {
            stripRoot = false;
            url = "https://update.code.visualstudio.com/${vscodeVersion}/win32-arm64-archive/stable#file.zip";
            sha256 = "sha256-Ybxfv/pb0p5hF3Xul/V0DjbkRDuTt+q+pzK+H61g1i8=";
          };
          languageServerWin = pkgs.fetchurl {
            url = "https://github.com/Exafunction/codeium/releases/download/language-server-v${languageServerVersion}/language_server_windows_x64.exe";
            sha256 = "sha256-kBSfsRj1gF8N19YwCD1EgnJKMMJd3AI6KnyGQ1FC/Bo=";
          };
          languageServerArm64 = pkgs.fetchurl {
            url = "https://github.com/Exafunction/codeium/releases/download/language-server-v${languageServerVersion}/language_server_linux_arm";
            sha256 = "sha256-CbRFYjIcT0neUUgKMKZ+t7U6ZYCm6EeZvXRrgNDS4qA=";
            executable = true;
          };
          fdArm64 = builtins.fetchTarball {
            url = "https://github.com/sharkdp/fd/releases/download/v10.2.0/fd-v10.2.0-aarch64-unknown-linux-gnu.tar.gz";
            sha256 = "sha256:0f7y8mjvxjf3zn07dx84hnh9zgf2pms3xc1jwjnk7f1mn9fk17xr";
          };
          fdWin = pkgs.fetchzip {
            url = "https://github.com/sharkdp/fd/releases/download/v10.2.0/fd-v10.2.0-x86_64-pc-windows-gnu.zip";
            sha256 = "sha256-b7ZK5J1KdVp5ioB5qJgy/SY0KXNcoWxG3MmxpdyEMdA=";
          };

          # Copies Windsurf-specific resources into the VS Code package.
          copyWindsurfFiles = root: isWindows: ''
            cp -R ${windsurfSrc}/resources/app/out ${root}/resources/app/
            cp -R ${windsurfSrc}/resources/app/*.json ${root}/resources/app/
            cp -R ${windsurfSrc}/resources/app/extensions/windsurf-* ${root}/resources/app/extensions/
            mkdir -p ${root}/resources/app/extensions/windsurf/bin
            cp -R ${windsurfSrc}/resources/app/extensions/windsurf/{*.js,*.json,*.mjs,assets,dist,out} ${root}/resources/app/extensions/windsurf/
            ${if isWindows then ''
              install -Dm 755 ${languageServerWin} ${root}/resources/app/extensions/windsurf/bin/language_server_windows_x64.exe
              install -Dm 755 ${fdWin}/fd.exe ${root}/resources/app/extensions/windsurf/bin/fd.exe
            '' else ''
              install -Dm 755 ${languageServerArm64} ${root}/resources/app/extensions/windsurf/bin/language_server_linux_arm
              install -Dm 755 ${fdArm64}/fd ${root}/resources/app/extensions/windsurf/bin/fd
            ''}
            rm -rf "${root}/resources/app/node_modules.asar"
            cp -R ${windsurfSrc}/resources/app/node_modules.asar ${root}/resources/app/
            rm -rf ${root}/resources/app/resources
            cp -R ${windsurfSrc}/resources/app/resources ${root}/resources/app/
            rm -rf ${root}/bin
            cp -R ${windsurfSrc}/bin ${root}/
          '';

          artifactName = os: arch: ext: "windsurf_${windsurfVersion}_${os}_${arch}.${ext}";

          # Builds Windsurf using a prepackaged set of VS Code files.
          # This is for creating dynamically linked builds.
          buildWindsurfPrepackaged = { vscodeFiles, name, isWindows ? false }:
            pkgs.stdenv.mkDerivation {
              pname = "windsurf-${name}";
              version = windsurfVersion;
              src = vscodeFiles;
              dontPatchShebangs = true;
              buildPhase = ''
                cp -R --preserve=mode,timestamps . $out

                ${copyWindsurfFiles "$out" isWindows}

                mv $out/code $out/windsurf || true
                mv $out/codium $out/windsurf || true
                mv $out/Code.exe $out/Windsurf.exe || true
              '';
            };
        in
        {
          extract-vscode-version = pkgs.runCommand "extract-vscode-version" { } ''
            ${pkgs.jq}/bin/jq -r .vscodeVersion ${windsurfSrc}/resources/app/product.json >> $out
          '';

          windsurf = {
            unpacked = windsurfSrc;

            linux = {
              arm64 = buildWindsurfPrepackaged {
                vscodeFiles = vscodeLinuxArm64;
                name = "linux-arm64";
              };
              arm64-targz = pkgs.runCommand "tarball" { } ''
                mkdir -p $out
                cd ${self.packages.${system}.windsurf.linux.arm64}
                ${pkgs.gnutar}/bin/tar -czvf $out/${artifactName "linux" "arm64" "tar.gz"} .
              '';
            };
            windows = {
              arm64 = buildWindsurfPrepackaged {
                vscodeFiles = vscodeWindowsArm64;
                name = "windows-arm64";
                isWindows = true;
              };
              arm64-zip = pkgs.runCommand "zip" { } ''
                mkdir -p $out
                cd ${self.packages.${system}.windsurf.windows.arm64}
                ${pkgs.zip}/bin/zip -r $out/${artifactName "windows" "arm64" "zip"} .
              '';
            };
          };

          default = self.packages.${system}.windsurf.nix;
        }
      );
    };
}
