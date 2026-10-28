-- Give inline code a chance to wrap.
--
-- Pandoc writes `code` as a single \texttt{...} box, which LaTeX will not break:
-- a long path or flag runs past the margin. This filter splits each Code element
-- at path and assignment boundaries (/ . =) and puts a zero-width \allowbreak
-- between the chunks.
--
-- Deliberately NOT a break point: "-" and "_". They appear inside identifiers, so
-- breaking there produces "PUPPETEER_" on one line and "EXECUTABLE_PATH" on the
-- next, which reads as a typo. Knowing where the boundary is matters more than
-- reaching zero overfull lines.
--
-- Two properties are deliberate:
--
-- 1. pandoc keeps doing the escaping. Each chunk stays a Code element, so no LaTeX
--    escaping is reimplemented here; the only raw output is \allowbreak.
-- 2. Nothing is added to the text. A command copied out of the PDF is unchanged,
--    unlike solutions that insert real line breaks.
--
-- Output is identical when the line fits: \allowbreak is only an opportunity.
local BREAK_CHARS = { ["/"] = true, ["."] = true, ["="] = true }

local function tex_output()
  return FORMAT == "latex" or FORMAT == "beamer"
end

function Code(el)
  if not tex_output() then
    return nil
  end

  local out = {}
  local buffer = ""
  for i = 1, #el.text do
    local ch = el.text:sub(i, i)
    buffer = buffer .. ch
    if BREAK_CHARS[ch] then
      out[#out + 1] = pandoc.Code(buffer)
      out[#out + 1] = pandoc.RawInline("latex", "\\allowbreak{}")
      buffer = ""
    end
  end

  if #out == 0 then
    return nil
  end
  if buffer ~= "" then
    out[#out + 1] = pandoc.Code(buffer)
  end
  return out
end
