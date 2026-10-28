#!/bin/bash
# validate area tests. Sourced by tests/run.sh (not run standalone).

run_validate_config_tests() {
  local out_ok
  out_ok="$(mktemp)"
  if "$CLI" validate-config -c "${FIXTURES_DIR}/valid.config.yaml" >"$out_ok" 2>&1; then
    pass "validate-config passes with valid config"
  else
    fail "validate-config should pass with valid config"
  fi
  assert_contains "$out_ok" "(Config valid|Config válida)" "validate-config prints success"
  rm -f "$out_ok"

  local out_no_template
  out_no_template="$(mktemp)"
  if "$CLI" validate-config -c "${FIXTURES_DIR}/valid-missing-template.config.yaml" >"$out_no_template" 2>&1; then
    pass "validate-config passes when pandoc.template is not provided"
  else
    fail "validate-config should pass without pandoc.template (uses default)"
  fi
  assert_contains "$out_no_template" "(Config valid|Config válida)" "validate-config confirms valid config without template"
  rm -f "$out_no_template"

  local out_bad
  out_bad="$(mktemp)"
  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-missing-version.yaml" >"$out_bad" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "validate-config fails when version is missing"
  assert_contains "$out_bad" "version" "validate-config reports missing field"
  rm -f "$out_bad"

  local out_type
  out_type="$(mktemp)"
  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-type-runtime-strict.yaml" >"$out_type" 2>&1
  local code_type=$?
  set -e
  assert_exit_code "1" "$code_type" "validate-config fails due to invalid type"
  assert_contains "$out_type" "runtime\.strict" "validate-config reports invalid type"
  rm -f "$out_type"

  local out_extra
  out_extra="$(mktemp)"
  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-extra-root-field.yaml" >"$out_extra" 2>&1
  local code_extra=$?
  set -e
  assert_exit_code "1" "$code_extra" "validate-config fails due to extra field"
  assert_contains "$out_extra" "(disallowed|no permitidos)" "validate-config reports additionalProperties"
  rm -f "$out_extra"

  local out_template_path
  out_template_path="$(mktemp)"
  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-missing-template-path.yaml" >"$out_template_path" 2>&1
  local code_template_path=$?
  set -e
  assert_exit_code "1" "$code_template_path" "validate-config fails when pandoc.template does not exist"
  assert_contains "$out_template_path" "pandoc\.template" "validate-config reports invalid template path"
  rm -f "$out_template_path"

  local out_chapters_path
  out_chapters_path="$(mktemp)"
  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-missing-chapters-dir.yaml" >"$out_chapters_path" 2>&1
  local code_chapters_path=$?
  set -e
  assert_exit_code "1" "$code_chapters_path" "validate-config fails when input.chapters_dir does not exist"
  assert_contains "$out_chapters_path" "input\.chapters_dir" "validate-config reports invalid chapters_dir path"
  rm -f "$out_chapters_path"

  local out_extra_filter_path
  out_extra_filter_path="$(mktemp)"
  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-missing-extra-filter-path.yaml" >"$out_extra_filter_path" 2>&1
  local code_extra_filter_path=$?
  set -e
  assert_exit_code "1" "$code_extra_filter_path" "validate-config fails when extra_lua_filter does not exist"
  assert_contains "$out_extra_filter_path" "extra_lua_filters\[0\]" "validate-config reports invalid extra_lua_filter path"
  rm -f "$out_extra_filter_path"
}

run_validate_metadata_file_test() {
  local out code
  out="$(mktemp)"

  if "$CLI" validate-config -c "${FIXTURES_DIR}/valid.config.yaml" >"$out" 2>&1; then
    pass "validate-config accepts a config whose metadata_file exists"
  else
    fail "validate-config should accept valid.config.yaml ($(tail -2 "$out"))"
  fi

  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-missing-metadata-file.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "validate-config rejects a metadata_file that does not exist"
  assert_contains "$out" "pandoc.metadata_file" "the error names the pandoc.metadata_file field"
  assert_contains "$out" "nope-missing.yaml" "the error names the missing file"

  rm -f "$out"
}

run_schema_keyword_support_test() {
  if [[ -z "${REAL_PYTHON3}" ]]; then
    echo "SKIP schema keyword support (python3 not available)"
    return 0
  fi

  local out
  out="$(mktemp)"
  if "${REAL_PYTHON3}" - "${ROOT_DIR}/schemas/pdf-config.schema.json" >"$out" 2>&1 <<'PY'
import json
import sys

# Keywords validate-config.py actually implements, plus pure annotations.
SUPPORTED = {
    "type", "properties", "required", "additionalProperties",
    "items", "minItems", "minLength", "minimum", "enum",
}
ANNOTATIONS = {"$schema", "$id", "title", "description", "default", "examples"}

schema = json.load(open(sys.argv[1], encoding="utf-8"))
used = set()


def walk(node):
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "properties":
                for subschema in value.values():
                    walk(subschema)
                continue
            used.add(key)
            walk(value)
    elif isinstance(node, list):
        for item in node:
            walk(item)


walk(schema)
unknown = sorted(used - SUPPORTED - ANNOTATIONS)
if unknown:
    print("unsupported JSON-Schema keywords: " + ", ".join(unknown))
    raise SystemExit(1)
PY
  then
    pass "the schema only uses keywords the validator implements"
  else
    fail "the schema uses keywords validate-config.py ignores: $(cat "$out")"
  fi
  rm -f "$out"
}

run_validate_order_enum_test() {
  local out code
  out="$(mktemp)"

  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-order-value.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "validate-config rejects an input.order outside the enum"
  assert_contains "$out" "input.order" "the enum error names the field"
  assert_contains "$out" "alphabetical" "the enum error lists the allowed values"

  rm -f "$out"
}

run_validate_metadata_contract_tests() {
  local out code

  # S1: a configuration without a metadata file is valid, and document.* is what
  # the renderer uses instead.
  out="$(mktemp)"
  set +e
  PANDOC_PDF_LANG=en "$CLI" validate-config -c "${FIXTURES_DIR}/valid-no-metadata.config.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "a config without pandoc.metadata_file is valid"
  rm -f "$out"

  # S4, S5, S6: language, titlepage and the free-form metadata map are part of the
  # contract instead of being rejected as extra fields.
  out="$(mktemp)"
  set +e
  PANDOC_PDF_LANG=en "$CLI" validate-config -c "${FIXTURES_DIR}/valid-document-metadata.config.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "document.language, titlepage and a metadata map are accepted"
  rm -f "$out"

  # The map is a map of scalars: a nested value is a configuration error, and the
  # message must name the offending key.
  out="$(mktemp)"
  set +e
  PANDOC_PDF_LANG=en "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-document-metadata.config.yaml" >"$out" 2>&1
  code=$?
  set -e
  if [[ "$code" -ne 0 ]]; then
    pass "a non-scalar value in document.metadata is rejected"
  else
    fail "a non-scalar value in document.metadata must be rejected"
  fi
  assert_contains "$out" "subject" "the failure names the offending metadata key"
  rm -f "$out"
}

run_validate_optional_inert_fields_tests() {
  local out code

  # A section whose only switch is a legacy compatibility flag should not be
  # mandatory to write down.
  out="$(mktemp)"
  set +e
  PANDOC_PDF_LANG=en "$CLI" validate-config -c "${FIXTURES_DIR}/valid-no-compat.config.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "a config without the compat section is valid"
  rm -f "$out"

  # A disabled filter says nothing about the document, so its settings are noise.
  out="$(mktemp)"
  set +e
  PANDOC_PDF_LANG=en "$CLI" validate-config -c "${FIXTURES_DIR}/valid-disabled-filters.config.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "a disabled filter does not need its settings"
  rm -f "$out"

  # And an enabled filter without settings falls back to what the renderer assumes.
  out="$(mktemp)"
  set +e
  PANDOC_PDF_LANG=en "$CLI" validate-config -c "${FIXTURES_DIR}/valid-filter-defaults.config.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "an enabled filter without settings is valid"
  rm -f "$out"
}
