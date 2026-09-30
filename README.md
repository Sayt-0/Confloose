# Confloose

A collection of *confloose* (small prank/config scripts for the EPITA computer
fleet: German keyboard, upside-down screen, fake `gcc`, fake `i3lock`, and so on)
installable with a single `curl`, with a **menu** to pick them and an **antidote**
to undo everything.

Collection reused from [`d-002/epita`](https://github.com/d-002/epita) (thanks
d-002 / leo). Everything is **user-level** (dotfiles, `~/.local/bin`, i3 config, no
root) and **reversible**.

## Usage

```sh
# Interactive menu
curl -fsSL confloose.sayto.dev | bash

# Or, without a domain, straight from GitHub Pages
curl -fsSL https://sayt-0.github.io/Confloose/install.sh | bash
```

In the menu:

- numbers to apply, e.g. `1 4 7`
- `a` then numbers for the **antidote**, e.g. `a 4`
- `l` lists installed confloose, `q` quits

### Without the menu (direct / scriptable)

```sh
# Apply one or more confloose
curl -fsSL confloose.sayto.dev | bash -s -- de-keyboard flip-screen

# Antidote (undo)
curl -fsSL confloose.sayto.dev | bash -s -- -a de-keyboard flip-screen

# List the confloose installed on this machine
curl -fsSL confloose.sayto.dev | bash -s -- -l
```

Keep `-fsSL`: the `-L` follows the redirect (see Deployment).

## How it works

- `install.sh` is the entry point. It reads `confloose/manifest.txt` to build the
  menu, then for each choice downloads `confloose/<name>/confloose.sh` (or
  `antidote.sh`) and runs it.
- Choices are read from `/dev/tty`, because with `curl | bash` the standard input
  is already taken by the piped script.
- Active confloose are tracked in `~/.confloose/confloose.lock` (or
  `$AFS_DIR/.confloose` when the AFS home is present), so you know what to remove.
- The scripts download each other through the `CONFLOOSE_BASE` variable (default:
  the repo's GitHub Pages URL). Handy for local testing:

  ```sh
  python3 -m http.server 8000            # at the repo root
  CONFLOOSE_BASE=http://127.0.0.1:8000 bash install.sh
  ```

- The confloose target the fleet environment (i3wm, X11, bash) and assume, like
  d-002, that `/bin/sh` accepts the `function` keyword (sh = bash). They no
  longer use `source`: in POSIX mode a `.` on a missing file aborts the shell, so
  each rc file is sourced in a subshell guarded by `[ -f ]`.
- Reversibility is per-confloose, never a whole-file snapshot shared between
  them. The i3 confloose either tag the lines they add/comment with
  `# confloose by leo [<name>]` and delete exactly those, or apply a transform
  that is its own inverse; only the binaries keep a `<file>.confloose.bak`. This
  is what keeps one antidote from reverting another confloose -- or the user's
  own edits.

## Adding a confloose

1. Create `confloose/<name>/confloose.sh` (apply) and `confloose/<name>/antidote.sh`
   (undo). For any remote resource, use
   `"${CONFLOOSE_BASE:-https://sayt-0.github.io/Confloose}/confloose/..."`.
2. Add a `name<TAB>description` line to `confloose/manifest.txt`.

## Contributing

Contributions are welcome: new confloose, fixes, better antidotes. Keep in mind that
`main` is served as-is by GitHub Pages, so whatever gets merged runs on the machine
of everyone who pipes `confloose.sayto.dev` into `bash`. Every change therefore goes
through a pull request and is reviewed line by line.

1. Fork the repo and branch off `main`.
2. Make your change, following [Adding a confloose](#adding-a-confloose) for a new
   one.
3. Test it with the local server shown in [How it works](#how-it-works): apply the
   confloose, run its antidote, and check that your dotfiles are back to their
   previous state.
4. Run the checks that CI runs on every pull request (both must pass):

   ```sh
   bash tests/lint.sh    # syntax, ShellCheck, manifest, download URLs
   bash tests/smoke.sh   # applies then undoes each confloose in a throwaway HOME
   ```

   `smoke.sh` is safe to run on your machine: it stubs out the X11/i3 tools and
   never touches your session. A confloose that starts a background daemon cannot
   be checked that way and goes in its `SKIP` list.
5. Open a pull request against `main`, one confloose per PR, saying what it does,
   how the antidote undoes it and where it was tested.

A confloose is merged only if it:

- has an antidote that undoes all of it and nothing else: never the user's own
  edits or another confloose (see the tagging in [How it works](#how-it-works));
- stays user-level: no `sudo`, and anything it installs lives under `$HOME` (or
  `$AFS_DIR`);
- loses no user data: a file it replaces is backed up and put back by the antidote
  (like `alacritty-color`);
- sends nothing off the machine;
- downloads remote files only through `CONFLOOSE_BASE`, never from another host;
- ships sources rather than prebuilt binaries (like `fake-i3lock`, built on the
  target), so the whole diff can be reviewed;
- only includes pictures or recordings of people who agreed to it;
- is creative and knows no limits (well, apart from the ones above).

## Deployment

### 1. GitHub Pages (hosts the script)

Settings > Pages > Source: branch `main`, folder `/` (root). Then check:

```sh
curl -fsSL https://sayt-0.github.io/Confloose/install.sh | head
```

The `.nojekyll` file makes Pages serve the files as-is.

### 2. Custom domain (shorter curl)

`confloose.sayto.dev` is set up as an HTTP redirect to the Pages `install.sh`, so
the short form works:

```sh
curl -fsSL confloose.sayto.dev | bash
```

> If the repo is renamed (e.g. to lowercase `confloose`), update the default
> `CONFLOOSE_BASE` URL at the top of `install.sh`.

## Responsible use

These confloose alter a session (keyboard, screen, aliases, fake binaries...). They
stay user-level, need no root, and **every confloose has its antidote** (plus the
`confloose.lock` that lists what is installed). Use them only on your own machines
or on consenting sessions.
