# WKU Mac Health Check

This fork builds Western Kentucky University's version of
[Dan Snelson's Mac Health Check](https://github.com/dan-snelson/Mac-Health-Check). WKU's branding,
settings and a few behavior changes live here as an **overlay**: a small set of files applied on
top of each upstream release. There is no long-lived copy of the 11,000-line script to rebase.

| Branch | What it is |
|---|---|
| `wku` (default) | The WKU overlay, build tooling and workflow. **All WKU changes go here.** |
| `main`, `development` | Exact mirrors of upstream. Never commit to these. |
| `bugfix/*`, `MDM-agnostic` | Topic branches for upstream pull requests |

## How a new upstream version reaches the fleet

1. **Detect:** once a day, [the workflow](.github/workflows/wku-build.yml) mirrors upstream's
   `main` and `development` and checks for upstream versions without a WKU build: the latest stable
   release, the newest beta or release candidate, and the head of `development`.
2. **Build:** `tools/build.py` applies the overlay to each one, syntax-checks it with `zsh -n`,
   and confirms every WKU setting landed.
3. **Publish:** each build becomes a **prerelease** on this fork, named like `v5.0.1-wku.b633788`
   (upstream version + overlay hash) or `dev-5.0.2b1-<commit>-wku.<hash>` for development heads.
   Assets:
   - `WKU-MHC-SelfService.mosyle.sh` → paste into Mosyle custom command **3303** (MacHealthCheck4)
   - `WKU-MHC-Silent.mosyle.sh` → paste into Mosyle custom command **2530** (MacHealthCheck4 - Silent)
   - `WKU-MHC-*.zsh` → the plain scripts, for review or for running by hand on a test Mac
4. **Test:** paste the wrapper into a Mosyle command scoped to the test device group.
5. **Promote:** once it's approved, edit the release, untick *Set as a pre-release*, and paste the
   same wrapper into the production command. The release page then records what's deployed.

If a build can't be made, the workflow opens an issue labeled `wku-build` with the log, and closes
it automatically once a later build of that version succeeds.

## The overlay

| File | What it does | When it breaks |
|---|---|---|
| `wku/settings.conf` | ~25 one-line settings: branding, colors, support info, Kerberos realm, VPN vendor, timers | Upstream renames or removes a setting → build fails naming the line |
| `wku/variants/*.conf` | One output per file. `silent.conf` changes the default `operationMode` | Same as above |
| `wku/overrides.zsh` | WKU help text for Inspect mode (wrappers that fall back to upstream), plus WKU versions of `checkVPN` and `checkAirDropSettings` (VPN and AirDrop-Everyone are warnings, not failures) | Upstream renames a wrapped function, or **changes** a replaced one (see below) |
| `wku/baselines/*.zsh` | Upstream's copy of each fully replaced function, as last reviewed | — |
| `wku/replacements.json` | Exact string swaps, each with an expected count | The string changes upstream → build fails |
| `wku/mosyle-wrapper.sh.template` | The Mosyle custom command wrapper | — |

**When upstream changes `checkVPN` or `checkAirDropSettings`**, the build stops with exit code 2
and the issue shows the upstream diff. Port the change into `wku/overrides.zsh`, then:

```sh
python3 tools/build.py --source /path/to/upstream/Mac-Health-Check.zsh --update-baselines
git add wku && git commit -m "Port upstream <version> changes to WKU overrides"
```

Every push to `wku/` or `tools/` changes the overlay hash, so the workflow rebuilds the current
upstream versions with the new overlay automatically.

## The Mosyle wrapper

The wrapper carries the script gzipped and base64-encoded, so a paste is about 127 KB instead of
about 600 KB. It decodes the script into `/Library/Management/edu.wku/mhc-staging/` (root-only,
replacing the old fixed path in `/var/tmp`, where a standard user could plant a symlink) and
checks its SHA-256 before running it. A truncated paste fails instead of running half a script.

## Building locally

```sh
git clone -b development --depth 1 https://github.com/dan-snelson/Mac-Health-Check.git /tmp/mhc-upstream
python3 tools/build.py --source /tmp/mhc-upstream/Mac-Health-Check.zsh --out dist
DRY_RUN=true tools/ci-build.sh v5.0.1     # what the workflow would do, without publishing
```

Python 3 standard library only; `zsh` is used for the syntax check when it's present.

## One-time setup

1. **Enable Actions** on this fork (Actions tab → *I understand my workflows, go ahead and enable
   them*). GitHub turns Actions off on forks by default, and pauses scheduled workflows after 60
   days without repository activity.
2. **Add the `SYNC_TOKEN` secret** for the mirror step: a fine-grained personal access token
   limited to this repository, with *Contents: Read and write* and *Workflows: Read and write*.
   Without it the mirror step is skipped with a warning and builds still run; they fetch upstream
   directly.
3. Optional: in Actions, disable upstream's **Security Scan** workflow if you don't want it running
   on the mirrored branches.

## Contributing upstream

Keep upstream pull requests on topic branches cut from `development`. Anything that gets accepted
upstream can be deleted from the overlay, so there's less to maintain.
