#!/bin/bash
# release area tests. Sourced by tests/run.sh (not run standalone).

run_package_release_artifact_test() {
  local out_dir artifact
  out_dir="$(mktemp -d)"

  if bash "${ROOT_DIR}/scripts/package-release.sh" "$out_dir" >/dev/null 2>&1; then
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

  if tar -tzf "${out_dir}/pandoc-pdf_linux_arm64.tar.gz" | grep -qxE '\./bin/pandoc-pdf'; then
    pass "package-release artifact contains the CLI entrypoint"
  else
    fail "package-release artifact must contain ./bin/pandoc-pdf"
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
