#!/bin/bash
# Chapter selection, order and the merged markdown.
# Sourced by tests/run.sh (not run standalone).

run_render_order_semantics_test() {
  local sandbox tmpbin capture out merged
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"
  merged="${sandbox}/work/out/s1-manual.md"

  printf '# Chapter Two\n\ncontent two\n' >"${sandbox}/work/chapters/chapter-2.md"
  printf '# Chapter Ten\n\ncontent ten\n' >"${sandbox}/work/chapters/chapter-10.md"

  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts input.order=natural"
  else
    fail "render should accept input.order=natural ($(tail -2 "$out"))"
  fi

  local pos_two pos_ten
  pos_two="$(line_of_match "$merged" '^# Chapter Two')"
  pos_ten="$(line_of_match "$merged" '^# Chapter Ten')"
  if [[ -n "$pos_two" && -n "$pos_ten" && "$pos_two" -lt "$pos_ten" ]]; then
    pass "input.order=natural sorts chapter-2 before chapter-10"
  else
    fail "input.order=natural must sort chapter-2 before chapter-10 (two=${pos_two:-none}, ten=${pos_ten:-none})"
  fi

  write_contract_config "${sandbox}/pdf.config.yaml" alphabetical true "" true
  rm -f "$merged"
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts input.order=alphabetical"
  else
    fail "render should accept input.order=alphabetical ($(tail -2 "$out"))"
  fi

  pos_two="$(line_of_match "$merged" '^# Chapter Two')"
  pos_ten="$(line_of_match "$merged" '^# Chapter Ten')"
  if [[ -n "$pos_two" && -n "$pos_ten" && "$pos_ten" -lt "$pos_two" ]]; then
    pass "input.order=alphabetical sorts chapter-10 before chapter-2"
  else
    fail "input.order=alphabetical must sort chapter-10 before chapter-2 (two=${pos_two:-none}, ten=${pos_ten:-none})"
  fi

  write_contract_config "${sandbox}/pdf.config.yaml" bogus true "" true
  local code
  set +e
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "render rejects an unsupported input.order"
  assert_contains "$out" "input.order" "unsupported input.order names the field"
  assert_contains "$out" "alphabetical" "unsupported input.order lists supported values"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_keep_merged_markdown_test() {
  local sandbox tmpbin capture out merged pdf
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"
  merged="${sandbox}/work/out/s1-manual.md"
  pdf="${sandbox}/work/out/s1-manual.pdf"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"

  write_contract_config "${sandbox}/pdf.config.yaml" natural false "" true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts output.keep_merged_markdown=false"
  else
    fail "render should accept output.keep_merged_markdown=false ($(tail -2 "$out"))"
  fi

  if [[ -f "$pdf" ]]; then
    pass "keep_merged_markdown=false still writes the PDF"
  else
    fail "keep_merged_markdown=false must still write the PDF"
  fi

  if [[ -f "$merged" ]]; then
    fail "keep_merged_markdown=false must remove the merged markdown"
  else
    pass "keep_merged_markdown=false removes the merged markdown"
  fi

  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts output.keep_merged_markdown=true"
  else
    fail "render should accept output.keep_merged_markdown=true ($(tail -2 "$out"))"
  fi

  if [[ -f "$merged" ]]; then
    pass "keep_merged_markdown=true keeps the merged markdown"
  else
    fail "keep_merged_markdown=true must keep the merged markdown"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_keep_merged_on_pandoc_failure_test() {
  local sandbox tmpbin capture out merged code
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  mkdir -p "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"

  cat >"${tmpbin}/pandoc" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "ARGS:$*" > "${TMP_PANDOC_CAPTURE}"
echo "failing on purpose" >&2
exit 7
EOF
  chmod +x "${tmpbin}/pandoc"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"
  write_contract_config "${sandbox}/pdf.config.yaml" natural false "" true
  merged="${sandbox}/work/out/s1-manual.md"

  set +e
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render \
    -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1
  code=$?
  set -e

  assert_exit_code "7" "$code" "render propagates pandoc's exit code"
  if [[ -f "$merged" ]]; then
    pass "keep_merged_markdown=false preserves the markdown when pandoc fails"
  else
    fail "keep_merged_markdown=false must keep the markdown when pandoc fails (diagnosis)"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}
