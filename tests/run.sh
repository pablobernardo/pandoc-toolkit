#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="${ROOT_DIR}/bin/pandoc-pdf"
FIXTURES_DIR="${ROOT_DIR}/tests/fixtures"
REAL_PYTHON3="$(command -v python3 || true)"

# Keep functional tests deterministic in English.
export PANDOC_PDF_LANG="en"

PASS=0
FAIL=0

# Shared assertions plus one file per area; this file only orchestrates.
source "${ROOT_DIR}/tests/lib.sh"
# shellcheck disable=SC1090,SC1091  # area paths are resolved at runtime
for area in "${ROOT_DIR}"/tests/l1/*.sh; do
  [[ -e "$area" ]] || continue
  source "$area"
done

main() {
  echo "== Running pandoc-pdf tests =="
  run_help_test
  run_help_i18n_notes_test
  run_version_tests
  run_info_tests
  run_i18n_catalog_consistency_test
  run_shared_i18n_runtime_test
  run_unknown_command_test
  run_i18n_default_fallback_english_test
  run_i18n_force_english_unknown_command_test
  run_locale_command_tests
  run_update_check_tests
  run_update_diagnostics_tests
  run_update_install_tests
  run_update_dev_command_blocked_test
  run_update_rollback_on_validation_failure_test
  run_install_local_dev_link_test
  run_doctor_success_with_mocked_path
  run_doctor_failure_missing_cmd
  run_doctor_with_config_required_cmd
  run_doctor_rejects_invalid_required_cmd
  run_bootstrap_linux_pkg_manager_detection_tests
  run_bootstrap_mermaid_browser_warning_test
  run_validate_config_tests
  run_validate_metadata_file_test
  run_schema_keyword_support_test
  run_validate_order_enum_test
  run_render_legacy_flag_rejected_test
  run_render_no_yaml_parser_hints_i18n_test
  run_render_native_test
  run_render_native_advanced_paths_test
  run_render_missing_explicit_file_test
  run_no_hidden_defaults_test
  run_render_order_semantics_test
  run_render_keep_merged_markdown_test
  run_render_document_vars_test
  run_render_ballot_icons_test
  run_doctor_strict_semantics_test
  run_doctor_mermaid_smoke_test
  run_emoji_source_allowlist_test
  run_template_modern_pandoc_guard_test
  run_render_filter_defaults_test
  run_render_output_file_name_test
  run_render_slug_accents_test
  run_render_document_metadata_test
  run_validate_metadata_contract_tests
  run_validate_optional_inert_fields_tests
  run_documentation_example_coverage_test
  run_docs_consistency_test
  run_examples_validate_test
  run_render_mermaid_failed_test
  run_mermaid_filter_marks_failure_test
  run_locale_missing_target_message_test
  run_locale_project_file_location_test
  run_package_release_artifact_test
  run_emoji_filter_plain_heading_test
  run_emoji_filter_contexts_test
  run_render_keep_merged_on_pandoc_failure_test
  run_render_mermaid_dir_gate_test
  run_render_plan_json_test
  run_render_dry_run_human_test
  run_plan_conformance_tests

  echo ""
  echo "Summary: PASS=${PASS} FAIL=${FAIL}"
  if [[ "$FAIL" -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
