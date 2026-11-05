#!/bin/bash
# release area tests. Sourced by tests/run.sh (not run standalone).

run_package_release_artifact_test() {  local out_dir artifact
  out_dir="$(mktemp -d)"

  if bash "${ROOT_DIR}/scripts/delivery/package-release.sh" "$out_dir" >/dev/null 2>&1; then
    pass "package-release builds artifacts"
  else
    fail "package-release should build artifacts"
  fi

  for artifact in pandoc-pdf_darwin_amd64.tar.gz pandoc-pdf_darwin_arm64.tar.gz pandoc-pdf_linux_amd64.tar.gz pandoc-pdf_linux_arm64.tar.gz; do
    if [[ -f "${out_dir}/${artifact}" ]]; then
      pass "package-release emits ${artifact}"
    else
      fail "package-release must emit ${artifact}"
    fi
  done

  if tar -tzf "${out_dir}/pandoc-pdf_linux_arm64.tar.gz" | grep -qE '__pycache__|\.pyc$'; then
    fail "package-release artifact must not ship Python bytecode caches"
  else
    pass "package-release artifact excludes Python bytecode caches"
  fi

  # Only what an installation runs ships: the runtime it executes and the tool it
  # exposes. dev and delivery are repository tooling, and shipping them made an
  # installed toolkit look like it carried supported developer commands.
  if tar -tzf "${out_dir}/pandoc-pdf_linux_arm64.tar.gz" | sed 's|^\./||' | grep -qE '^scripts/(dev|delivery)/'; then
    fail "package-release must not ship repository tooling: scripts/dev or scripts/delivery found"
  else
    pass "package-release ships no repository tooling"
  fi

  if tar -tzf "${out_dir}/pandoc-pdf_linux_arm64.tar.gz" | sed 's|^\./||' | grep -qx 'scripts/runtime/render-native.py'; then
    pass "package-release ships the runtime the CLI executes"
  else
    fail "package-release must ship scripts/runtime/render-native.py"
  fi

  if tar -tzf "${out_dir}/pandoc-pdf_linux_arm64.tar.gz" | sed 's|^\./||' | grep -qx 'scripts/tools/bookkit/build.py'; then
    pass "package-release ships the bookkit tool"
  else
    fail "package-release must ship scripts/tools/bookkit/build.py"
  fi

  # GNU tar and BSD tar do not print the "./" prefix the same way, which made this
  # assertion pass on macOS and fail on Ubuntu for the same artifact. Normalise it
  # instead of trusting one implementation's formatting.
  if tar -tzf "${out_dir}/pandoc-pdf_linux_arm64.tar.gz" | sed 's|^\./||' | grep -qx 'bin/pandoc-pdf'; then
    pass "package-release artifact contains the CLI entrypoint"
  else
    fail "package-release artifact must contain bin/pandoc-pdf; entries: $(tar -tzf "${out_dir}/pandoc-pdf_linux_arm64.tar.gz" | grep -E '^(\./)?bin/' | head -3 | tr '\n' ' ')"
  fi

  local expected actual
  expected="$(awk '$2=="pandoc-pdf_linux_arm64.tar.gz" {print $1}' "${out_dir}/checksums.txt")"
  if command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "${out_dir}/pandoc-pdf_linux_arm64.tar.gz" | awk '{print $1}')"
  else
    actual="$(sha256sum "${out_dir}/pandoc-pdf_linux_arm64.tar.gz" | awk '{print $1}')"
  fi
  if [[ -n "$expected" && "$expected" == "$actual" ]]; then
    pass "package-release checksums match the emitted artifacts"
  else
    fail "package-release checksums must match the emitted artifacts"
  fi

  rm -rf "$out_dir"
}

release_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

run_package_release_reproducibility_test() {
  local first second first_hash second_hash
  first="$(mktemp -d)"
  second="$(mktemp -d)"

  if ! bash "${ROOT_DIR}/scripts/delivery/package-release.sh" "$first" >/dev/null 2>&1; then
    fail "package-release should build artifacts for the reproducibility check"
    rm -rf "$first" "$second"
    return
  fi

  # Sleep past a whole-second boundary so a timestamp inside the archive or in
  # the gzip header cannot hide behind two builds started in the same second.
  sleep 1

  if ! bash "${ROOT_DIR}/scripts/delivery/package-release.sh" "$second" >/dev/null 2>&1; then
    fail "package-release should build artifacts twice"
    rm -rf "$first" "$second"
    return
  fi

  first_hash="$(release_sha256 "${first}/pandoc-pdf_linux_arm64.tar.gz")"
  second_hash="$(release_sha256 "${second}/pandoc-pdf_linux_arm64.tar.gz")"
  if [[ -n "$first_hash" && "$first_hash" == "$second_hash" ]]; then
    pass "package-release is reproducible: two builds produce identical archives"
  else
    fail "package-release must be reproducible: ${first_hash} != ${second_hash}"
  fi

  rm -rf "$first" "$second"
}

# A published artifact is acceptance evidence, so it must depend on the commit
# and not on who built it: an untracked file inside a shipped directory, or an
# uncommitted edit to a shipped file, must never reach the archive.
run_package_release_tracked_tree_test() {
  local out_dir probe backup clean_hash dirty_hash listed

  out_dir="$(mktemp -d)"
  probe="${ROOT_DIR}/templates/.untracked-payload-probe.tex"
  printf 'untracked probe\n' > "$probe"

  if bash "${ROOT_DIR}/scripts/delivery/package-release.sh" "$out_dir" >/dev/null 2>&1; then
    listed="$(tar -tzf "${out_dir}/pandoc-pdf_linux_arm64.tar.gz" | sed 's|^\./||')"
    if printf '%s\n' "$listed" | grep -qx 'templates/.untracked-payload-probe.tex'; then
      fail "package-release must not ship an untracked file from a payload directory"
    else
      pass "package-release ships only tracked files from a payload directory"
    fi
    # Guard against a vacuous pass: the tracked payload has to still be there.
    if printf '%s\n' "$listed" | grep -qx 'templates/book.tex'; then
      pass "package-release still ships the tracked payload"
    else
      fail "package-release must ship tracked payload files such as templates/book.tex"
    fi
  else
    fail "package-release should build artifacts while an untracked file sits in a payload directory"
  fi
  rm -f "$probe"
  rm -rf "$out_dir"

  out_dir="$(mktemp -d)"
  if ! bash "${ROOT_DIR}/scripts/delivery/package-release.sh" "$out_dir" >/dev/null 2>&1; then
    fail "package-release should build a clean artifact for the dirty-tree comparison"
    rm -rf "$out_dir"
    return
  fi
  clean_hash="$(release_sha256 "${out_dir}/pandoc-pdf_linux_arm64.tar.gz")"
  rm -rf "$out_dir"

  backup="$(mktemp)"
  cp "${ROOT_DIR}/README.md" "$backup"
  printf '\n<!-- uncommitted local marker -->\n' >> "${ROOT_DIR}/README.md"
  out_dir="$(mktemp -d)"
  if bash "${ROOT_DIR}/scripts/delivery/package-release.sh" "$out_dir" >/dev/null 2>&1; then
    dirty_hash="$(release_sha256 "${out_dir}/pandoc-pdf_linux_arm64.tar.gz")"
    if [[ -n "$clean_hash" && "$clean_hash" == "$dirty_hash" ]]; then
      pass "package-release produces the same artifact from a dirty tree"
    else
      fail "package-release must ignore uncommitted edits: ${clean_hash} != ${dirty_hash}"
    fi
    if tar -xzOf "${out_dir}/pandoc-pdf_linux_arm64.tar.gz" README.md 2>/dev/null | grep -q 'uncommitted local marker'; then
      fail "package-release must not ship an uncommitted edit to a tracked file"
    else
      pass "package-release ships committed content for a modified tracked file"
    fi
  else
    fail "package-release should build artifacts while a tracked payload file is modified"
  fi

  # Restore the working copy even if an assertion above already failed.
  cp "$backup" "${ROOT_DIR}/README.md"
  rm -f "$backup"
  rm -rf "$out_dir"
}
