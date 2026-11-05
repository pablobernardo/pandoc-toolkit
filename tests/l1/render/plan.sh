#!/bin/bash
# The plan as a contract: --dry-run, JSON output and the human summary.
# Sourced by tests/run.sh (not run standalone).

run_render_plan_json_test() {
  if [[ -z "${REAL_PYTHON3}" ]]; then
    echo "SKIP render plan json (python3 not available)"
    return 0
  fi

  local sandbox tmpbin capture plan out code
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  plan="$(mktemp)"
  out="$(mktemp)"

  printf '# Chapter Two\n\ncontent two\n' >"${sandbox}/work/chapters/chapter-2.md"
  printf '# Chapter Ten\n\ncontent ten\n' >"${sandbox}/work/chapters/chapter-10.md"
  write_contract_config "${sandbox}/skelepress.config.yaml" natural true "" true

  set +e
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/skelepress" render \
    -c "${sandbox}/skelepress.config.yaml" --dry-run --json >"$plan" 2>"$out"
  code=$?
  set -e
  assert_exit_code "0" "$code" "render --dry-run --json exits 0"

  if "${REAL_PYTHON3}" -c "import json,sys; json.load(open(sys.argv[1]))" "$plan" >/dev/null 2>&1; then
    pass "render --dry-run --json emits valid JSON"
  else
    fail "render --dry-run --json must emit valid JSON ($(head -3 "$out"))"
  fi

  assert_json_expr "$plan" 'd["plan_version"] == 1' "plan declares plan_version 1"
  assert_json_expr "$plan" '[p.split("/")[-1] for p in d["chapters"]] == ["chapter-2.md", "chapter-10.md"]' "plan lists chapters in effective order"
  assert_json_expr "$plan" 'd["pandoc"]["argv"][0] == "pandoc"' "plan argv starts with pandoc"
  assert_json_expr "$plan" '"--pdf-engine=lualatex" in d["pandoc"]["argv"]' "plan reflects pdf_engine from config"
  assert_json_expr "$plan" 'd["env"]["PANDOC_EMOJI_BALLOT_ICONS"] == "1"' "plan carries the emoji ballot environment"
  assert_json_expr "$plan" 'd["side_effects"]["keep_merged_markdown"] is True' "plan declares keep_merged_markdown"
  assert_json_expr "$plan" 'd["side_effects"]["emoji"]["dir"].endswith("/work/out/emoji")' "plan resolves the emoji directory"
  assert_json_expr "$plan" 'd["toolkit"]["version"] != ""' "plan reports the toolkit version"

  if [[ -s "$capture" ]]; then
    fail "render --dry-run must not invoke pandoc"
  else
    pass "render --dry-run does not invoke pandoc"
  fi

  if [[ -e "${sandbox}/work/out" ]]; then
    fail "render --dry-run must not create output files or directories"
  else
    pass "render --dry-run has no side effects"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$plan" "$out"
}

run_render_dry_run_human_test() {
  local sandbox tmpbin capture out code
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"
  write_contract_config "${sandbox}/skelepress.config.yaml" natural true "" true

  set +e
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/skelepress" render \
    -c "${sandbox}/skelepress.config.yaml" --dry-run >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "render --dry-run exits 0"
  assert_contains "$out" "pandoc " "render --dry-run prints the pandoc invocation"
  assert_not_contains "$out" "Running:" "render --dry-run does not claim pandoc ran"

  if [[ -e "${sandbox}/work/out" ]]; then
    fail "render --dry-run (human) must not create output files"
  else
    pass "render --dry-run (human) has no side effects"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}
