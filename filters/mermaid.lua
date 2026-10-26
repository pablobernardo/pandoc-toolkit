-- Mermaid filter for Pandoc
-- Converts code blocks with class "mermaid" into rendered PNG images using mermaid-cli.
-- Requires: npm install -g @mermaid-js/mermaid-cli 
-- Alternative (macOS): brew install mermaid-cli
-- Works with XeLaTeX / LuaLaTeX outputs.

local system = require 'pandoc.system'

-- Directory for generated diagrams
local output_dir = os.getenv("PANDOC_MERMAID_OUTPUT_DIR") or "output/mermaid"
local mermaid_background = os.getenv("PANDOC_MERMAID_BACKGROUND") or "transparent"
os.execute('mkdir -p "' .. output_dir .. '"')

-- Compute a simple deterministic hash (fallback if pandoc.utils.sha1 unavailable)
local function simple_hash(s)
    local h = 5381
    for i = 1, #s do
        h = ((h * 33) ~ string.byte(s, i)) & 0x7FFFFFFF
    end
    return string.format("%08x", h)
    end

    local function hash(s)
    local ok, utils = pcall(require, "pandoc.utils")
    if ok and utils and utils.sha1 then return utils.sha1(s) end
    if pandoc and pandoc.sha1 then return pandoc.sha1(s) end
    return simple_hash(s)
    end

    function CodeBlock(block)
    if not block.classes:includes("mermaid") then
        return nil
    end

    local content = block.text
    local h = hash(content)
    local infile = output_dir .. "/mmd-" .. h .. ".mmd"
    local outfile = output_dir .. "/mmd-" .. h .. ".png"

    -- Render only if file doesn't exist yet
    local f = io.open(outfile, "rb")
    if f == nil then
        -- Write temp .mmd source
        local src = io.open(infile, "w")
        src:write(content)
        src:close()

        local cmd = string.format('mmdc -i "%s" -o "%s" -b "%s" -q', infile, outfile, mermaid_background)
        local ok = os.execute(cmd)
        if not ok then
            io.stderr:write("[mermaid.lua] ERROR: mmdc failed. Diagram left as code block.\n")
            return nil
        end
    else
        f:close()
    end

    -- return pandoc.Para({ pandoc.Image({}, outfile) })
    -- modified to add space above and below the generated image
    local img = pandoc.Image({}, outfile)

    local top_space = pandoc.RawBlock("latex", "\\vspace{1.2em}")
    local bottom_space = pandoc.RawBlock("latex", "\\vspace{1.2em}")

    return { top_space, pandoc.Para(img), bottom_space }

end
