#!/usr/bin/env bash
# Shared i18n runtime for the bash entry points (bin/pandoc-pdf, scripts/bootstrap.sh).
#
# Sourced, never executed. Contract: set I18N_ROOT to the toolkit root before
# sourcing. Optionally set GLOBAL_ENV_FILE / PROJECT_ENV_FILE to override where
# `pandoc-pdf locale set` persists the language.
#
# The catalog is loaded once per process and lookups are pure bash parameter
# expansion, so translating a message costs no subprocess. Before this helper
# every `t` call forked python3: `--help` alone meant five processes.

i18n_locales_dir() {
  printf '%s\n' "${I18N_ROOT}/i18n/locales"
}

list_supported_locales() {
  local dir
  dir="$(i18n_locales_dir)"
  if [[ -d "$dir" ]]; then
    local file
    for file in "$dir"/*.json; do
      [[ -e "$file" ]] || continue
      file="${file##*/}"
      printf '%s\n' "${file%.json}"
    done | sort -u
    return 0
  fi

  printf 'en\n'
}

is_supported_locale() {
  local candidate="$1"
  local loc
  while IFS= read -r loc; do
    [[ "$loc" == "$candidate" ]] && return 0
  done < <(list_supported_locales)
  return 1
}

supported_locales_csv() {
  local first=true
  local loc
  while IFS= read -r loc; do
    if [[ "$first" == true ]]; then
      printf '%s' "$loc"
      first=false
    else
      printf ', %s' "$loc"
    fi
  done < <(list_supported_locales)
}

read_lang_from_env_file() {
  local file_path="$1"
  [[ -f "$file_path" ]] || return 1

  local line value
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    case "$line" in
      *PANDOC_PDF_LANG=*)
        value="${line#*=}"
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        if [[ -n "$value" ]]; then
          printf '%s\n' "$value"
          return 0
        fi
        ;;
    esac
  done < "$file_path"

  return 1
}

read_global_lang() {
  read_lang_from_env_file "${GLOBAL_ENV_FILE:-${XDG_CONFIG_HOME:-${HOME}/.config}/pandoc-pdf/config.env}"
}

# The project locale belongs to the consuming repository, not to the toolkit
# installation. Look it up from the current directory upwards so running the CLI
# from a subdirectory still finds it.
project_env_file() {
  if [[ -n "${PANDOC_PDF_PROJECT_ENV:-}" ]]; then
    printf '%s\n' "${PANDOC_PDF_PROJECT_ENV}"
    return 0
  fi

  local dir="$PWD"
  while :; do
    if [[ -f "${dir}/.pandoc-pdf.env" ]]; then
      printf '%s\n' "${dir}/.pandoc-pdf.env"
      return 0
    fi
    [[ "$dir" == "/" ]] && break
    dir="$(dirname "$dir")"
  done

  return 1
}

read_project_lang() {
  local file
  file="$(project_env_file)" || return 1
  read_lang_from_env_file "$file"
}

# Normalises a raw locale ("es_ES.UTF-8@euro" -> "es") and prints it, or fails.
normalize_lang_or_fail() {
  local raw="$1"
  raw="${raw%%.*}"
  raw="${raw%%@*}"
  raw="${raw//_/-}"
  local lower
  lower="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"

  if is_supported_locale "$lower"; then
    printf '%s\n' "$lower"
    return 0
  fi

  local base="${lower%%-*}"
  if is_supported_locale "$base"; then
    printf '%s\n' "$base"
    return 0
  fi

  return 1
}

# Resolves the active locale: explicit argument, PANDOC_PDF_LANG, project file,
# global file, LC_ALL, LANG, then English.
resolve_lang() {
  local raw="${1:-}"
  if [[ -z "$raw" ]]; then
    if [[ -n "${PANDOC_PDF_LANG:-}" ]]; then
      raw="${PANDOC_PDF_LANG}"
    else
      local from_project=""
      local from_global=""
      from_project="$(read_project_lang || true)"
      if [[ -n "$from_project" ]]; then
        raw="$from_project"
      else
        from_global="$(read_global_lang || true)"
        if [[ -n "$from_global" ]]; then
          raw="$from_global"
        else
          raw="${LC_ALL:-${LANG:-en}}"
        fi
      fi
    fi
  fi

  local normalized
  if normalized="$(normalize_lang_or_fail "$raw")"; then
    printf '%s\n' "$normalized"
    return 0
  fi

  if is_supported_locale "en"; then
    printf 'en\n'
    return 0
  fi

  local first_locale
  first_locale=""
  while IFS= read -r first_locale; do
    printf '%s\n' "$first_locale"
    return 0
  done < <(list_supported_locales)

  printf 'en\n'
}

# Loads the catalog for LOCALE into I18N_CATALOG as "key<TAB>message" lines,
# prefixed by a newline so every key can be matched with ${var#*$'\n'KEY$'\t'}.
i18n_load_catalog() {
  local locale="${1:-en}"
  local locale_file
  locale_file="$(i18n_locales_dir)/${locale}.json"

  I18N_CATALOG=""
  [[ -f "$locale_file" ]] || return 0
  command -v python3 >/dev/null 2>&1 || return 0

  local dumped
  dumped="$(python3 - "$locale_file" <<'PY'
import json
import sys

try:
    data = json.load(open(sys.argv[1], "r", encoding="utf-8"))
except Exception:
    raise SystemExit(0)

for key, value in data.items():
    if isinstance(key, str) and isinstance(value, str) and "\t" not in value and "\n" not in value:
        print(f"{key}\t{value}")
PY
)"
  [[ -n "$dumped" ]] && I18N_CATALOG=$'\n'"$dumped"
  return 0
}

t() {
  local key="$1"
  local fallback="$2"
  local value=""

  if [[ -n "${I18N_CATALOG:-}" ]]; then
    local rest="${I18N_CATALOG#*$'\n'"$key"$'\t'}"
    if [[ "$rest" != "$I18N_CATALOG" ]]; then
      value="${rest%%$'\n'*}"
    fi
  fi

  if [[ -z "$value" ]]; then
    value="$fallback"
  fi

  printf '%s\n' "$value"
}

interp() {
  local template="$1"
  local token="$2"
  local value="$3"
  printf '%s\n' "${template//\{$token\}/$value}"
}
