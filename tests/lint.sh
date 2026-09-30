#!/usr/bin/env bash
#
# Static checks, run by CI on every pull request: syntax, ShellCheck, manifest
# consistency, and where the scripts download from.

set -u
cd "$(dirname "$0")/.." || exit 1

status=0
fail() { printf 'FAIL: %s\n' "$*" >&2; status=1; }

# Every shell script, including extension-less ones like fake-gcc/gcc.
scripts=()
while IFS= read -r f; do
    case "$f" in
        *.sh) scripts+=("$f") ;;
        *) head -n 1 "$f" | grep -qE '^#!.*[/ ](ba)?sh$' && scripts+=("$f") ;;
    esac
done < <(find install.sh confloose tests -type f | sort)

for f in "${scripts[@]}"; do
    bash -n "$f" || fail "syntax error in $f"
done

# The fleet runs sh as bash (see How it works in the README). Errors only: the
# warnings are mostly deliberate, like `echo $(curl ...)` and dynamic sourcing.
if command -v shellcheck >/dev/null; then
    shellcheck --shell=bash --severity=error "${scripts[@]}" || fail "shellcheck"
elif [ -n "${CI:-}" ]; then
    fail "shellcheck is not installed"
else
    echo "shellcheck is not installed, skipping it" >&2
fi

manifest=confloose/manifest.txt
names=()
while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    name=${line%%$'\t'*}
    if [ "$name" = "$line" ]; then
        fail "$manifest: expected name<TAB>description: $line"
        continue
    fi
    names+=("$name")
    for script in confloose antidote; do
        [ -f "confloose/$name/$script.sh" ] || fail "confloose/$name/$script.sh is missing"
    done
done < "$manifest"

dupes=$(printf '%s\n' "${names[@]}" | sort | uniq -d)
[ -z "$dupes" ] || fail "$manifest lists these more than once: $dupes"

for dir in confloose/*/; do
    dir=${dir#confloose/}
    dir=${dir%/}
    printf '%s\n' "${names[@]}" | grep -qxF -- "$dir" || fail "confloose/$dir is not in $manifest"
done

# A single fallback URL everywhere, so a repo move only means updating install.sh
# and replacing that one URL.
# shellcheck disable=SC2016
base=$(sed -n 's/^CONFLOOSE_BASE="${CONFLOOSE_BASE:-\(.*\)}"$/\1/p' install.sh)
if [ -z "$base" ]; then
    fail "cannot read the default CONFLOOSE_BASE in install.sh"
fi
while IFS= read -r hit; do
    [ "${hit#*:}" = "CONFLOOSE_BASE:-$base" ] || fail "fallback URL differs from install.sh: $hit"
done < <(grep -roIE 'CONFLOOSE_BASE:-[^}]*' confloose)

# Remote files come from CONFLOOSE_BASE only (see Contributing in the README).
while IFS= read -r hit; do
    rest=${hit//"CONFLOOSE_BASE:-$base"/}
    [[ $rest =~ https?:// ]] && fail "URL outside CONFLOOSE_BASE: $hit"
done < <(grep -rnIE 'https?://' confloose)

# Every file the scripts download has to exist, or it 404s once deployed.
while IFS= read -r path; do
    [ -f "$path" ] || fail "downloaded but missing from the repo: $path"
done < <(grep -rhoIE '(CONFLOOSE_BASE(:-[^}]*)?\}?|\$\{?base\}?)/confloose/[A-Za-z0-9_./-]+' install.sh confloose |
    grep -oE 'confloose/[A-Za-z0-9_./-]+$' | sort -u)

[ "$status" -eq 0 ] && echo "lint: ok (${#scripts[@]} scripts, ${#names[@]} confloose)"
exit "$status"
