-- emoji.lua — reemplaza emojis por imágenes SVG sin tocar bloques de código
-- Busca SVGs en: filters/emoji/<hex>.svg  (ej: 2705.svg, 1f6ab.svg)
-- Si no existe el SVG específico, deja el carácter tal cual (o usa _missing.svg si está presente)

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

  -- placeholder opcional
  local placeholders = {}
  for _, dir in ipairs(emoji_dirs) do
    table.insert(placeholders, string.format("%s/_missing.svg", dir))
  end
  return first_existing(placeholders)
end

-- Normaliza codepoints: ignora VS-15/VS-16 y ZWJ para que no rompan el flujo
local function normalize_cp(cp)
  if cp == 0xFE0F or cp == 0xFE0E or cp == 0x200D then
    return nil
  end
  return cp
end

-- Solo tratar como "emoji" los codepoints de los planos de Emoji
-- y un pequeño conjunto de dingbats usados como emoji (✅, ❌, ⛔).
local ALLOWED_DINGBATS = {
  [0x2705] = true, -- ✅ WHITE HEAVY CHECK MARK
  [0x274C] = true, -- ❌ CROSS MARK
  [0x26D4] = true, -- ⛔ NO ENTRY
  [0x2610] = true, -- ☐ BALLOT BOX (Markdown - [ ])
  [0x2611] = true, -- ☑ BALLOT BOX WITH CHECK
  [0x2612] = true, -- ☒ BALLOT BOX WITH X (Markdown - [x])
  [0x26A0] = true, -- ⚠ WARNING)
}

local function is_emojiish(cp)
  -- Planos principales de emoji
  if cp >= 0x1F000 and cp <= 0x1FAFF then return true end
  -- Dingbats permitidos explícitamente
  if ALLOWED_DINGBATS[cp] then return true end
  -- Todo lo demás NO es emoji (esto excluye á, é, ñ, ¿, ¡, etc.)
  return false
end

local function emoji_image_for_cp(cp)
  local hex = string.format("%x", cp)
  local svg = svg_for_hex(hex)
  if not svg then return nil end
  local attr = pandoc.Attr("", {"emoji"}, {["height"] = "1.05em"})
  return pandoc.Image({}, svg, "", attr)
end

local function string_to_inlines(text)
  local out = {}
  for _, rawcp in utf8.codes(text) do
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
        -- No es emoji: dejar el carácter tal cual (preserva tildes, ¿, ¡, etc.)
        table.insert(out, pandoc.Str(utf8.char(cp)))
      end
    end
  end
  return out
end

-- No transformar bloques de código
function Code(el) return nil end
function CodeBlock(el) return nil end

-- Reemplaza emojis dentro de palabras/strings
function Str(el)
  return pandoc.Span(string_to_inlines(el.text))
end

-- Procesar inline recursivamente (Links, Emph, Strong, etc.)
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
  el.content = map_inlines(el.content)
  return el
end

function BlockQuote(el)
  el.content = pandoc.walk_block(el, {Para = Para, Plain = Plain})
  return el
end
