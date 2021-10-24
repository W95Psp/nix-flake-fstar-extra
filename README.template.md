# Nix Flake F* Extra

Building on https://github.com/W95Psp/nix-flake-fstar, this repository is a flake which provides:
 - a list of F* master commits with their sha256 hashes (`nix eval --json 'github:W95Psp/nix-flake-fstar-extra#commits'`);
 - corresponding F* binaries (e.g. `nix run 'github:W95Psp/nix-flake-fstar-extra#fstar-bin-02ecab9dd1aa930bee842d77fa3564f24328e3d7' somemodule.fst`);
 - a list of F* pull-request patches with their sha256 hashes (`nix eval --json 'github:W95Psp/nix-flake-fstar-extra#commits'`);
 - corresponding patches (e.g. `nix build 'github:W95Psp/nix-flake-fstar-extra#pr-1909' -o 1909.patch` fetches the patch `1909.patch`);
 - a tool to find regressions (see below).

## Finding regressions
**Scenario:** *a function used to typecheck at some point (with some F* version). You want to identify the commit in F* history which broke your function*.

The following command will try to typecheck the F* module `MODULE` for every F* binary corresponding to the every single commit between `TIMESTAMP_MIN` and `TIMESTAMP_MAX` (two unix timestamp). *Those timestamp can be omitted, in which case every commit from `nix eval --json 'github:W95Psp/nix-flake-fstar-extra#commits'` will be used.*

`nix run 'github:W95Psp/nix-flake-fstar-extra#find-faulty-commit' MODULE [TIMESTAMP_MIN] [TIMESTAMP_MAX]`

## Details
<details>
  <summary>Full list of attributes availables</summary>

<!-- LIST -->

</details>

## Update
Commits and pull-requests are stored in `db.json` and `pull-requests.json`, to update them, clone this repo, and run `nix run .#update`. This will update the present README as well.

