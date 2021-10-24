
{
  description = "FPM extra tools";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    fstar-flake.url = "github:W95Psp/nix-flake-fstar";
  };
  
  outputs = { self, nixpkgs, flake-utils, fstar-flake }:
    let nixlib = nixpkgs.lib;
        fstar-master-commits =
          map ({timestamp, commit, hash, ...}
               : {inherit timestamp commit hash;})
            (
              nixlib.filter
                (o: o.lexer == "sedlex")
                (builtins.fromJSON (builtins.readFile ./db.json))
            );
        pull-requests = builtins.fromJSON (builtins.readFile ./pull-requests.json);
    in
      {
        inherit pull-requests;
        commits = fstar-master-commits;
      } // 
      flake-utils.lib.eachSystem [ "x86_64-darwin" "x86_64-linux" "aarch64-linux"]
        (system:
          let pkgs = nixpkgs.legacyPackages.${system};
              pkgs-fstar = fstar-flake.packages.${system};
              fstar-master = pkgs-fstar.fstar;
              fstar-lib = fstar-flake.lib.${system}.fstar;
              fstar-commit-sources = f:
                builtins.listToAttrs (
                  map ({timestamp, commit, hash}@o:
                    { name = f o;
                      value = pkgs.fetchgit {
                        url = "https://github.com/FStarLang/fstar";
                        rev = commit;
                        sha256 = hash;
                      };
                    }) fstar-master-commits
                );
              fstar-commit-binaries = f: builtins.mapAttrs
                (name: src:
                  let
                    existing-fstar = fstar-lib.binary-of-ml-snapshot {inherit src; name = "ml-snapshot-${name}"; withlibs = false;};
                    # existing-fstar = fstar-master;
                    ocaml = fstar-lib.ocaml-from-fstar {
                      inherit src existing-fstar;
                      # existing-fstar = fstar-master;
                      patches = [];
                      name = "${name}-extracted-fstar";
                    };
                  in
                    fstar-lib.binary-of-ml-snapshot {src = ocaml; name = "fstar.exe"; withlibs = false;}
                    // {version = name;}
                )
                (fstar-commit-sources f);
          in
            {
              packages = fstar-commit-sources (o: "fstar-source-${o.commit}")
                         // fstar-commit-binaries (o: "fstar-bin-${o.commit}")
                         // nixlib.listToAttrs (
                           map (pr: { name = "pr-${toString pr.number}";
                                        value = pkgs.fetchurl {
                                          url = pr.patch_url;
                                          sha256 = pr.patch_hash;
                                        };
                                      }) pull-requests
                         );
              apps = {
                update = {
                  type = "app";
                  program = "${
                    pkgs.writeScript "update" ''
                       export PATH="${nixlib.makeBinPath [pkgs.nixFlakes pkgs.gnused pkgs.jq pkgs.git pkgs.gnugrep]}:$PATH"
                       # Update pull requests
                       ${pkgs.nodejs}/bin/node ${./get-pull-requests.js}
                       # Update commit (with hashes) list
                       ${pkgs.bash}/bin/bash ${./build-db.sh}
                       # Update `README.md`
                       sed -e '/<!-- LIST -->/q' README.template.md > README.md
                       nix flake show --json | jq -r '.packages."x86_64-linux" | keys | .[] | " - `"+.+"`"' | grep -v "fstar-source" >> README.md
                       sed -ne '/<!-- LIST -->/,$ p' README.template.md >> README.md
                    ''
                  }";
                };
                find-faulty-commit = {
                  type = "app";
                  program = "${
                    pkgs.writeScript "find-faulty-commit" ''
                       export PATH="${nixlib.makeBinPath [pkgs.nixFlakes pkgs.jq]}:$PATH"
                       export CURRENTFLAKE="github:W95Psp/nix-flake-fstar-extra"
                       ${pkgs.bash}/bin/bash ${./find-faulty-commit.sh} "$@"
                    ''
                  }";
                };
              };
            }
        );
}


