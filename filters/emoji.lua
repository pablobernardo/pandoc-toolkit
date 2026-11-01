-- emoji.lua — replaces emojis with SVG images without touching code blocks
-- Looks up SVGs at: filters/emoji/<hex>.svg  (e.g. 2705.svg, 1f6ab.svg)
-- If the specific SVG is missing, leave the character as is (or use _missing.svg when present)

local utf8 = require 'utf8'

local emoji_dirs = {
  os.getenv("PANDOC_EMOJI_DIR") or "output/emoji",  -- configurable via env
}

local function file_exists(path)
  local f = io.open(path, "r")
  if f then f:close(); return true end
  return false
end

local function first_existing(path_list)
  for _, p in ipairs(path_list) do
    if file_exists(p) then return p end
  end
end

local function svg_for_hex(hex)
  hex = string.lower(hex)
  local candidates = {}
  for _, dir in ipairs(emoji_dirs) do
    table.insert(candidates, string.format("%s/%s.svg", dir, hex))
  end
  local found = first_existing(candidates)
  if found then return found end

  -- optional placeholder
  local placeholders = {}
  for _, dir in ipairs(emoji_dirs) do
    table.insert(placeholders, string.format("%s/_missing.svg", dir))
  end
  return first_existing(placeholders)
end

-- Normalises codepoints: ignores VS-15/VS-16, ZWJ and combining keycap (U+20E3)
local function normalize_cp(cp)
  if cp == 0xFE0F or cp == 0xFE0E or cp == 0x200D or cp == 0x20E3 then
    return nil
  end
  return cp
end

local function is_variation_selector(cp)
  return cp == 0xFE0F or cp == 0xFE0E
end

local function is_keycap_base(cp)
  return cp == 0x0023 or cp == 0x002A or (cp >= 0x0030 and cp <= 0x0039)
end

-- Only treat codepoints in the Emoji planes as emoji
-- plus a small set of dingbats used as emoji (✅, ❌, ⛔).
local ALLOWED_DINGBATS = {
  [0x2705] = true, -- ✅ WHITE HEAVY CHECK MARK
  [0x274C] = true, -- ❌ CROSS MARK
  [0x26D4] = true, -- ⛔ NO ENTRY
  [0x26A0] = true, -- ⚠ WARNING)
}

-- Markdown task-list boxes; they can be disabled with
-- filters.emoji.include_ballot_icons=false (the runtime exports the variable).
local BALLOT_DINGBATS = {
  [0x2610] = true, -- ☐ BALLOT BOX (Markdown - [ ])
  [0x2611] = true, -- ☑ BALLOT BOX WITH CHECK
  [0x2612] = true, -- ☒ BALLOT BOX WITH X (Markdown - [x])
}

local ballot_icons = os.getenv("PANDOC_EMOJI_BALLOT_ICONS") ~= "0"

local function is_emojiish(cp)
  -- Main emoji planes
  if cp >= 0x1F000 and cp <= 0x1FAFF then return true end
  -- Markdown task boxes (configurable)
  if BALLOT_DINGBATS[cp] then return ballot_icons end
  -- Explicitly allowed dingbats
  if ALLOWED_DINGBATS[cp] then return true end
  -- Everything else is NOT emoji (this excludes á, é, ñ, ¿, ¡, and so on)
  return false
end

local function emoji_image_for_hex(hex)
  local svg = svg_for_hex(hex)
  if not svg then return nil end
  local attr = pandoc.Attr("", {"emoji"}, {["height"] = "1.05em"})
  return pandoc.Image({}, svg, "", attr)
end

local function emoji_image_for_cp(cp)
  local hex = string.format("%x", cp)
  return emoji_image_for_hex(hex)
end

local function string_to_inlines(text)
  local cps = {}
  for _, cp in utf8.codes(text) do
    table.insert(cps, cp)
  end

  local out = {}
  local i = 1
  while i <= #cps do
    local rawcp = cps[i]

    -- Keycap sequence: [0-9#*] + optional VS + U+20E3
    if is_keycap_base(rawcp) then
      local j = i + 1
      if j <= #cps and is_variation_selector(cps[j]) then
        j = j + 1
      end
      if j <= #cps and cps[j] == 0x20E3 then
        local keycap_hex = string.format("%x-20e3", rawcp)
        local keycap_img = emoji_image_for_hex(keycap_hex)
        if keycap_img then
          table.insert(out, keycap_img)
          i = j + 1
          goto continue
        end
      end
    end

    local cp = normalize_cp(rawcp)
    if cp then
      if is_emojiish(cp) then
        local img = emoji_image_for_cp(cp)
        if img then
          table.insert(out, img)
        else
          table.insert(out, pandoc.Str(utf8.char(cp)))
        end
      else
        -- Not emoji: leave the character as is (keeps accents, ¿, ¡, and so on)
        table.insert(out, pandoc.Str(utf8.char(cp)))
      end
    end
    i = i + 1
    ::continue::
  end
  return out
end

-- Do not transform code blocks
function Code(el) return nil end
function CodeBlock(el) return nil end

-- The EPUB writer reuses headings in the navigation document, where a link must
-- contain text and Pandoc writes an image path relative to the text directory
-- that escapes the package from the navigation root. A reader renders emoji
-- natively, so EPUB keeps the characters in headings instead of the images the
-- PDF needs to cover its font gap.
local epub_output = tostring(FORMAT) == "epub"

-- Replaces emojis inside words and strings.
-- Wraps in a Span only when something was actually substituted: wrapping plain
-- text makes any heading count as formatted and makes pandoc emit
-- \texorpdfstring, which requires hyperref in the template (it broke minimal
-- templates without hyperref).
function Str(el)
  -- This hook cannot tell whether it is inside a heading, and filters run
  -- bottom-up, so it would transform the heading before Header could skip it.
  -- EPUB relies on the block handlers below, which are scoped by construction.
  if epub_output then
    return nil
  end
  local inlines = string_to_inlines(el.text)
  local replaced = false
  for _, inline in ipairs(inlines) do
    if inline.t ~= "Str" then
      replaced = true
      break
    end
  end
  if not replaced then
    return nil
  end
  return pandoc.Span(inlines)
end

-- Walk inlines recursively (Links, Emph, Strong, and so on)
local function map_inlines(inlines)
  local out = {}
  for _, x in ipairs(inlines) do
    if x.t == "Str" then
      for _, y in ipairs(string_to_inlines(x.text)) do table.insert(out, y) end
    elseif x.t == "Link" or x.t == "Emph" or x.t == "Strong" or x.t == "Span"
        or x.t == "Quoted" or x.t == "Underline" or x.t == "Superscript" or x.t == "Subscript" then
      local copy = x:clone()
      copy.content = map_inlines(copy.content)
      table.insert(out, copy)
    else
      table.insert(out, x)
    end
  end
  return out
end

function Para(el)
  el.content = map_inlines(el.content)
  return el
end

function Plain(el)
  el.content = map_inlines(el.content)
  return el
end

function Header(el)
  if epub_output then
    return nil
  end
  el.content = map_inlines(el.content)
  return el
end

function BlockQuote(el)
  el.content = pandoc.walk_block(el, {Para = Para, Plain = Plain})
  return el
end
