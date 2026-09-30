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
