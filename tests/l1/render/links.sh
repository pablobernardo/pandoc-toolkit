#!/bin/bash
# Links between selected chapters become internal anchors.
# Sourced by tests/run.sh (not run standalone).

run_chapter_link_rewrite_test() {
  if ! command -v pandoc >/dev/null 2>&1; then
    echo "SKIP chapter links (pandoc not available)"
    return 0
  fi

  local sandbox out epub md ch1 code=0
  sandbox="$(new_epub_sandbox)"
  out="$(mktemp)"
  epub="${sandbox}/work/out/epub-guide-manual.epub"
  md="${sandbox}/work/out/epub-guide-manual.md"
  ch1="${sandbox}/ch1.xhtml"

  printf '# First Chapter\n\nSee [the second chapter](chapter-2.md).\n' >"${sandbox}/work/chapters/chapter-1.md"
  printf '# Second Chapter\n\nText only.\n' >"${sandbox}/work/chapters/chapter-2.md"
  write_epub_config "${sandbox}/skelepress.config.yaml" epub "EPUB Sandbox Guide" es true

  (
    cd "${sandbox}/work" && "${sandbox}/bin/skelepress" render -c "${sandbox}/skelepress.config.yaml"
  ) >"$out" 2>&1 || code=$?
  assert_exit_code "0" "$code" "EPUB renders with a link to a sibling chapter"
  assert_contains "$md" '\]\(#ch-chapter-2\)' "a sibling chapter link becomes an in-document anchor"
  assert_contains "$md" '\[\]\{#ch-chapter-2\}' "the target chapter carries the matching anchor"

  unzip -p "$epub" EPUB/text/ch001.xhtml >"$ch1" 2>/dev/null
  assert_not_contains "$ch1" 'chapter-2\.md' "no dead link to a chapter file survives in the EPUB"
  assert_contains "$ch1" 'ch002\.xhtml#ch-chapter-2|href="#ch-chapter-2"' "the link resolves inside the publication"

  rm -rf "$sandbox"
  rm -f "$out"

  # A project with no sibling links must stay byte-identical: no anchors, no rewrites.
  local plain_md
  sandbox="$(new_epub_sandbox)"
  out="$(mktemp)"
  plain_md="${sandbox}/work/out/epub-guide-manual.md"
  printf '# First Chapter\n\nPlain text.\n' >"${sandbox}/work/chapters/chapter-1.md"
  printf '# Second Chapter\n\nText only.\n' >"${sandbox}/work/chapters/chapter-2.md"
  write_epub_config "${sandbox}/skelepress.config.yaml" epub "EPUB Sandbox Guide" es true
  code=0
  (
    cd "${sandbox}/work" && "${sandbox}/bin/skelepress" render -c "${sandbox}/skelepress.config.yaml"
  ) >"$out" 2>&1 || code=$?
  assert_exit_code "0" "$code" "EPUB renders without sibling links"
  assert_not_contains "$plain_md" '\[\]\{#' "a project without sibling links gets no injected anchors"

  rm -rf "$sandbox"
  rm -f "$out"
}
