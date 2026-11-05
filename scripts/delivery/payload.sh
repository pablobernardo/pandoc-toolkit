#!/usr/bin/env bash
# What an installation carries, in one place.
#
# The packager and the local installer both build a managed tree, and until they
# shared this list the local one shipped `examples/`, `Makefile` and the whole
# `scripts/` directory — including the repository tooling — while dropping
# `LICENSE` and `README.md`. A local install then tested something the release
# does not ship, which is the one thing an installer must never do.
#
# Repository tooling is deliberately absent: `scripts/dev` and
# `scripts/delivery` are unusable from an installation and are not something a
# consumer should read as supported.

# Shipped whole, from the repository root.
PANDOC_PDF_PAYLOAD=(
  "bin"
  "filters"
  "i18n"
  "schemas"
  "templates"
  "VERSION"
  "README.md"
  "LICENSE"
)

# The only directories under `scripts/` an installation runs.
PANDOC_PDF_SCRIPT_DIRS=(
  "runtime"
  "tools"
)

# Fills `target` with the payload taken from `root`.
#
# `source_mode` decides which content ships:
#   worktree (default) — the files as they are on disk. A local development
#                        install exists to exercise uncommitted work, so this is
#                        what it wants.
#   tracked            — the content of `HEAD`. A published artifact is
#                        acceptance evidence, so it has to depend on the commit
#                        and not on who built it: an untracked file inside a
#                        shipped directory must not travel, and an uncommitted
#                        edit must not change the archive.
populate_payload() {
  local target="$1"
  local root="$2"
  local source_mode="${3:-worktree}"
  local asset dir

  mkdir -p "${target}/scripts"
  if [[ "$source_mode" == "tracked" ]]; then
    populate_payload_from_commit "$target" "$root" || return 1
  else
    for dir in "${PANDOC_PDF_SCRIPT_DIRS[@]}"; do
      if [[ -e "${root}/scripts/${dir}" ]]; then
        cp -R "${root}/scripts/${dir}" "${target}/scripts/${dir}"
      fi
    done
    for asset in "${PANDOC_PDF_PAYLOAD[@]}"; do
      if [[ -e "${root}/${asset}" ]]; then
        cp -R "${root}/${asset}" "${target}/"
      fi
    done
  fi

  # Never ship local Python bytecode caches.
  find "${target}" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
  find "${target}" -name '*.pyc' -type f -delete 2>/dev/null || true
}

# Copies the payload exactly as committed, through `git archive`.
#
# Refusing a non-Git tree is deliberate: packaging the working copy when the
# commit is unavailable would reintroduce, silently, the difference between two
# builders that made a published artifact depend on the machine.
populate_payload_from_commit() {
  local target="$1"
  local root="$2"
  local paths=() present=() dir asset entry

  for dir in "${PANDOC_PDF_SCRIPT_DIRS[@]}"; do
    paths+=("scripts/${dir}")
  done
  paths+=("${PANDOC_PDF_PAYLOAD[@]}")

  if ! git -C "${root}" rev-parse --git-dir >/dev/null 2>&1; then
    echo "payload: ${root} is not a Git work tree; a release payload is built from committed content" >&2
    return 1
  fi

  # `git archive` fails on a pathspec that matches nothing, so keep only the
  # entries `HEAD` actually has. Read with a loop instead of `mapfile`, which
  # does not exist in the bash 3.2 that macOS ships.
  while IFS= read -r entry; do
    [[ -n "$entry" ]] && present+=("$entry")
  done < <(git -C "${root}" ls-tree --name-only HEAD -- "${paths[@]}")

  if [[ "${#present[@]}" -eq 0 ]]; then
    echo "payload: HEAD in ${root} contains none of the payload paths" >&2
    return 1
  fi

  git -C "${root}" archive --format=tar HEAD -- "${present[@]}" | tar -x -C "${target}" -f -
}
