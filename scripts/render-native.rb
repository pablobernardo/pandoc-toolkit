#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'time'
require 'pathname'
require 'json'

def locales_dir
  Pathname.new(__dir__).parent + 'i18n' + 'locales'
end

def available_locales
  dir = locales_dir
  return ['en'] unless dir.directory?

  locales = dir.children
               .select { |p| p.file? && p.extname == '.json' }
               .map { |p| p.basename('.json').to_s }
               .reject(&:empty?)
               .uniq
               .sort

  locales.empty? ? ['en'] : locales
end

def resolve_lang(raw = nil)
  value = (raw || ENV['PANDOC_PDF_LANG'] || ENV['LC_ALL'] || ENV['LANG'] || 'en').to_s
  value = value.split('.', 2).first.to_s.split('@', 2).first.to_s.tr('_', '-').downcase
  supported = available_locales

  return value if supported.include?(value)

  base = value.split('-', 2).first
  return base if supported.include?(base)

  return 'en' if supported.include?('en')

  supported.first
end

LANG_CODE = resolve_lang

def load_catalog(lang)
  path = locales_dir + "#{lang}.json"
  return {} unless path.file?

  data = JSON.parse(File.read(path.to_s, encoding: 'UTF-8'))
  data.is_a?(Hash) ? data : {}
rescue StandardError
  {}
end

MESSAGES = load_catalog(LANG_CODE).freeze

def t(key, fallback, vars = {})
  template = MESSAGES.fetch(key, fallback)
  template.gsub(/\{([a-zA-Z_][a-zA-Z0-9_]*)\}/) do
    k = Regexp.last_match(1).to_sym
    vars.fetch(k, Regexp.last_match(0)).to_s
  end
end

ORDER_NATURAL = 'natural'
ORDER_ALPHABETICAL = 'alphabetical'
ORDER_CHOICES = [ORDER_NATURAL, ORDER_ALPHABETICAL].freeze
DOCUMENT_VAR_FIELDS = %w[title subtitle publisher author date rights].freeze

# Sort key where digit runs compare numerically (chapter-2 < chapter-10).
def natural_key(path)
  File.basename(path.to_s).downcase.split(/(\d+)/).map do |part|
    part.match?(/\A\d+\z/) ? [0, part.length, part] : [1, 0, part]
  end
end

def select_chapter_files(input_cfg, chapters_dir)
  explicit_files = input_cfg['explicit_files']
  explicit_files = [] unless explicit_files.is_a?(Array)

  unless explicit_files.empty?
    return explicit_files.map do |name|
      candidate = chapters_dir + name.to_s
      die(t('render.error.explicit_file_missing', 'Explicit file not found: {path}', path: candidate)) unless candidate.exist?
      candidate
    end
  end

  pattern = (input_cfg['glob'] || '*.md').to_s
  order = (input_cfg['order'] || ORDER_NATURAL).to_s.strip.downcase
  files = Dir.glob((chapters_dir + pattern).to_s).map { |f| Pathname.new(f) }

  return files.sort_by { |p| p.basename.to_s } if order == ORDER_ALPHABETICAL
  return files.sort_by { |p| natural_key(p) } if order == ORDER_NATURAL

  die(t('render.error.order_invalid',
        "Invalid 'input.order' value: {value}. Supported values: {supported}",
        value: order, supported: ORDER_CHOICES.join(', ')))
end

def deep_merge(base, override)
  merged = base.dup
  override.each do |key, value|
    if merged[key].is_a?(Hash) && value.is_a?(Hash)
      merged[key] = deep_merge(merged[key], value)
    else
      merged[key] = value
    end
  end
  merged
end

def load_yaml_map(path)
  data = YAML.safe_load(File.read(path.to_s), permitted_classes: [], aliases: false)
  return {} if data.nil?

  die(t('render.error.yaml_root_object', 'Root of {path} must be an object/map', path: path)) unless data.is_a?(Hash)
  data
rescue StandardError => e
  die(t('render.error.yaml_parse', 'Could not parse YAML: {error}', error: e.message))
end

def die(msg)
  puts "❌ #{msg}"
  exit 1
end

def resolve_suffix(raw)
  return Time.now.strftime('%Y%m%d') if raw.nil? || raw.to_s.strip.empty?

  raw.to_s.gsub('${date:YYYYMMDD}', Time.now.strftime('%Y%m%d'))
end

cfg_path = Pathname.new(ARGV[0].to_s)
root_dir = Pathname.new(ARGV[1].to_s)

die(t('render.error.usage', 'Usage: render-native.rb <config.yaml> <toolkit_root>')) if cfg_path.to_s.empty? || root_dir.to_s.empty?
die(t('render.error.config_not_found', 'Config not found: {path}', path: cfg_path)) unless cfg_path.file?

cfg_user = load_yaml_map(cfg_path)
cfg = cfg_user

defaults_path = root_dir + 'defaults/default.yaml'
cfg = deep_merge(load_yaml_map(defaults_path), cfg) if defaults_path.file?

%w[project document input output pandoc].each do |k|
  die(t('render.error.required_section', 'Invalid or missing required section: {section}', section: k)) unless cfg[k].is_a?(Hash)
end

project = cfg['project']
document = cfg['document']
input_cfg = cfg['input']
output = cfg['output']
pandoc = cfg['pandoc']

base_dir = project['base_dir']
die(t('render.error.base_dir_required', "'project.base_dir' is required")) if base_dir.nil? || base_dir.to_s.strip.empty?

base_dir_path = (cfg_path.dirname + base_dir.to_s).expand_path
title = document['title'] || output['file_prefix'] || 'document'
suffix = resolve_suffix(output['suffix'])

chapters_dir = (base_dir_path + (input_cfg['chapters_dir'] || 'chapters').to_s).expand_path
die(t('render.error.chapters_dir_missing', 'input.chapters_dir does not exist: {path}', path: chapters_dir)) unless chapters_dir.directory?

selected_files = select_chapter_files(input_cfg, chapters_dir)

die(t('render.error.no_chapters', 'No chapters found to render')) if selected_files.empty?

output_dir = (base_dir_path + (output['dir'] || 'output').to_s).expand_path
output_dir.mkpath
filename_out = "#{title}-#{suffix}"
pdf_out = output_dir + "#{filename_out}.pdf"
md_out = output_dir + "#{filename_out}.md"

keep_merged_markdown = output.fetch('keep_merged_markdown', true) ? true : false

compat = cfg['compat'] || {}
insert_clearpage = compat.fetch('legacy_clearpage_between_h1', true)

File.open(md_out.to_s, 'w:utf-8') do |merged|
  selected_files.each_with_index do |file, idx|
    text = File.read(file.to_s, encoding: 'UTF-8')
    if idx.positive? && insert_clearpage
      first_nonempty = text.lines.find { |line| !line.strip.empty? } || ''
      merged << "\n\n\\clearpage\n\n" if first_nonempty.start_with?('# ')
    end
    merged << "\n"
    merged << text
    merged << "\n\n"
  end
end

user_pandoc_cfg = cfg_user['pandoc'].is_a?(Hash) ? cfg_user['pandoc'] : {}
user_template_raw = user_pandoc_cfg.fetch('template', '').to_s.strip

if user_template_raw.empty?
  template_default_raw = (pandoc['template'] || 'templates/default.tex').to_s
  template_path = Pathname.new(template_default_raw)
  template_path = (root_dir + template_path).expand_path unless template_path.absolute?
else
  template_path = Pathname.new(user_template_raw)
  template_path = (base_dir_path + template_path).expand_path unless template_path.absolute?
end

metadata_path = nil
metadata_raw = (pandoc['metadata_file'] || '').to_s
unless metadata_raw.strip.empty?
  metadata_path = Pathname.new(metadata_raw)
  metadata_path = (base_dir_path + metadata_path).expand_path unless metadata_path.absolute?
end

resource_path_values = (pandoc['resource_path'] || []).map do |item|
  p = Pathname.new(item.to_s)
  p = (base_dir_path + p).expand_path unless p.absolute?
  p.to_s
end

filters = cfg['filters'] || {}
emoji_cfg = filters['emoji'] || {}
mermaid_cfg = filters['mermaid'] || {}

emoji_dir = Pathname.new((emoji_cfg['emoji_dir'] || 'output/emoji').to_s)
emoji_dir = (base_dir_path + emoji_dir).expand_path unless emoji_dir.absolute?
emoji_dir.mkpath

missing_svg = emoji_dir + '_missing.svg'
unless missing_svg.file?
  File.write(
    missing_svg.to_s,
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\" viewBox=\"0 0 16 16\">\n" \
    "  <rect width=\"16\" height=\"16\" rx=\"2\" ry=\"2\" fill=\"#ddd\" stroke=\"#999\"/>\n" \
    "  <text x=\"8\" y=\"11\" font-size=\"10\" text-anchor=\"middle\" fill=\"#666\">?</text>\n" \
    "</svg>\n"
  )
end

if emoji_cfg.fetch('enabled', true)
  prepare_script = (root_dir + 'scripts/prepare-emojis.py').to_s
  if File.file?(prepare_script)
    ok_prep = system('python3', prepare_script, md_out.to_s, emoji_dir.to_s, (root_dir + 'filters/emoji').to_s)
    puts "⚠️  #{t('render.warn.emoji_prepare', 'Could not auto-prepare emojis; continuing with fallback')}" unless ok_prep
  end
end

mermaid_output_dir = Pathname.new((mermaid_cfg['output_dir'] || 'output/mermaid').to_s)
mermaid_output_dir = (base_dir_path + mermaid_output_dir).expand_path unless mermaid_output_dir.absolute?
mermaid_output_dir.mkpath

cmd = [
  'pandoc',
  md_out.to_s,
  "--pdf-engine=#{pandoc['pdf_engine'] || 'xelatex'}",
  "--template=#{template_path}"
]

cmd << "--lua-filter=#{(root_dir + 'filters/emoji.lua').to_s}" if emoji_cfg.fetch('enabled', true)
cmd << "--lua-filter=#{(root_dir + 'filters/mermaid.lua').to_s}" if mermaid_cfg.fetch('enabled', true)

(filters['extra_lua_filters'] || []).each do |extra|
  p = Pathname.new(extra.to_s)
  p = (base_dir_path + p).expand_path unless p.absolute?
  cmd << "--lua-filter=#{p}"
end

if pandoc.fetch('toc', true)
  cmd << '--toc'
  cmd << "--toc-depth=#{pandoc['toc_depth'] || 2}"
end
cmd << '--number-sections' if pandoc.fetch('number_sections', true)
cmd << '-V' << 'titlepage=true' << '-V' << 'fig-pos=!htbp'
cmd << "--resource-path=#{resource_path_values.join(File::PATH_SEPARATOR)}" unless resource_path_values.empty?
if metadata_path && metadata_path.file?
  cmd << "--metadata-file=#{metadata_path}"
else
  DOCUMENT_VAR_FIELDS.each do |field|
    value = document[field]
    cmd << '-V' << "#{field}=#{value}" if value.is_a?(String) && !value.strip.empty?
  end
end
cmd << '-o' << pdf_out.to_s

ENV['PANDOC_EMOJI_DIR'] = emoji_dir.to_s
ENV['PANDOC_EMOJI_BALLOT_ICONS'] = emoji_cfg.fetch('include_ballot_icons', true) ? '1' : '0'
ENV['PANDOC_MERMAID_OUTPUT_DIR'] = mermaid_output_dir.to_s
ENV['PANDOC_MERMAID_BACKGROUND'] = (mermaid_cfg['background'] || 'transparent').to_s

puts "✅ #{t('render.mode.native', 'Native mode enabled')}"
puts "📄 #{t('render.output.markdown', 'Merged markdown: {path}', path: md_out)}"
puts "🖨️  #{t('render.output.pdf', 'Output PDF: {path}', path: pdf_out)}"
puts "▶ #{t('render.command.exec', 'Running: {command}', command: cmd.join(' '))}"

ok = system(*cmd)
exit_code = ok ? 0 : ($?.exitstatus || 1)
File.delete(md_out.to_s) if exit_code.zero? && !keep_merged_markdown
exit(exit_code)
