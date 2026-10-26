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

PLAN_VERSION = 1

MISSING_SVG = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\" viewBox=\"0 0 16 16\">\n" \
              "  <rect width=\"16\" height=\"16\" rx=\"2\" ry=\"2\" fill=\"#ddd\" stroke=\"#999\"/>\n" \
              "  <text x=\"8\" y=\"11\" font-size=\"10\" text-anchor=\"middle\" fill=\"#666\">?</text>\n" \
              "</svg>\n"

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

def toolkit_version(root_dir)
  File.read((root_dir + 'VERSION').to_s, encoding: 'UTF-8').strip
rescue SystemCallError, IOError
  ''
end

def truthy?(value)
  value ? true : false
end

# Compute the render plan. Pure: no writes, no directory creation, no subprocess.
def build_plan(cfg_user, cfg_path, root_dir)
  cfg = cfg_user

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
  filename_out = "#{title}-#{suffix}"
  pdf_out = output_dir + "#{filename_out}.pdf"
  md_out = output_dir + "#{filename_out}.md"

  keep_merged_markdown = truthy?(output.fetch('keep_merged_markdown', true))

  compat = cfg['compat'] || {}
  insert_clearpage = truthy?(compat.fetch('legacy_clearpage_between_h1', true))

  user_pandoc_cfg = cfg_user['pandoc'].is_a?(Hash) ? cfg_user['pandoc'] : {}
  user_template_raw = user_pandoc_cfg.fetch('template', '').to_s.strip

  if user_template_raw.empty?
    template_default_raw = (pandoc['template'] || 'templates/default.tex').to_s.strip
    template_default_raw = 'templates/default.tex' if template_default_raw.empty?
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

  emoji_enabled = truthy?(emoji_cfg.fetch('enabled', true))
  mermaid_enabled = truthy?(mermaid_cfg.fetch('enabled', true))

  emoji_dir = Pathname.new((emoji_cfg['emoji_dir'] || 'output/emoji').to_s)
  emoji_dir = (base_dir_path + emoji_dir).expand_path unless emoji_dir.absolute?

  mermaid_output_dir = Pathname.new((mermaid_cfg['output_dir'] || 'output/mermaid').to_s)
  mermaid_output_dir = (base_dir_path + mermaid_output_dir).expand_path unless mermaid_output_dir.absolute?

  # NOTE: the Python renderer records its own interpreter (sys.executable, an
  # environment-specific absolute path) as argv[0]. A port must stay
  # renderer-neutral, so the Ruby plan records the plain `python3` command and
  # lets the executor resolve it through PATH.
  prepare_script = root_dir + 'scripts/prepare-emojis.py'
  prepare_argv = nil
  if emoji_enabled && prepare_script.file?
    prepare_argv = [
      'python3',
      prepare_script.to_s,
      md_out.to_s,
      emoji_dir.to_s,
      (root_dir + 'filters/emoji').to_s
    ]
  end

  cmd = [
    'pandoc',
    md_out.to_s,
    "--pdf-engine=#{pandoc['pdf_engine'] || 'xelatex'}",
    "--template=#{template_path}"
  ]

  cmd << "--lua-filter=#{(root_dir + 'filters/emoji.lua')}" if emoji_enabled
  cmd << "--lua-filter=#{(root_dir + 'filters/mermaid.lua')}" if mermaid_enabled

  (filters['extra_lua_filters'] || []).each do |extra|
    p = Pathname.new(extra.to_s)
    p = (base_dir_path + p).expand_path unless p.absolute?
    cmd << "--lua-filter=#{p}"
  end

  if truthy?(pandoc.fetch('toc', true))
    cmd << '--toc'
    cmd << "--toc-depth=#{(pandoc['toc_depth'] || 2).to_i}"
  end
  cmd << '--number-sections' if truthy?(pandoc.fetch('number_sections', true))
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

  {
    'plan_version' => PLAN_VERSION,
    'toolkit' => { 'version' => toolkit_version(root_dir), 'root' => root_dir.to_s },
    'config' => { 'path' => cfg_path.to_s, 'base_dir' => base_dir_path.to_s },
    'chapters' => selected_files.map(&:to_s),
    'pandoc' => {
      'target' => { 'markdown' => md_out.to_s, 'pdf' => pdf_out.to_s },
      'argv' => cmd,
      'cwd' => nil
    },
    'env' => {
      'PANDOC_EMOJI_DIR' => emoji_dir.to_s,
      'PANDOC_EMOJI_BALLOT_ICONS' => truthy?(emoji_cfg.fetch('include_ballot_icons', true)) ? '1' : '0',
      'PANDOC_MERMAID_OUTPUT_DIR' => mermaid_output_dir.to_s,
      'PANDOC_MERMAID_BACKGROUND' => (mermaid_cfg['background'] || 'transparent').to_s
    },
    'side_effects' => {
      'keep_merged_markdown' => keep_merged_markdown,
      'clearpage_between_h1' => insert_clearpage,
      'emoji' => {
        'enabled' => emoji_enabled,
        'dir' => emoji_dir.to_s,
        'missing_svg' => (emoji_dir + '_missing.svg').to_s,
        'prepare_argv' => prepare_argv
      },
      'mermaid' => {
        'enabled' => mermaid_enabled,
        'dir' => mermaid_output_dir.to_s,
        'background' => (mermaid_cfg['background'] || 'transparent').to_s
      }
    }
  }
end

def merged_markdown(chapters, insert_clearpage)
  parts = +''
  chapters.each_with_index do |raw_path, index|
    text = File.read(raw_path.to_s, encoding: 'UTF-8')
    if index.positive? && insert_clearpage
      first_nonempty = text.lines.find { |line| !line.strip.empty? } || ''
      parts << "\n\n\\clearpage\n\n" if first_nonempty.start_with?('# ')
    end
    parts << "\n"
    parts << text
    parts << "\n\n"
  end
  parts
end

# Materialise and run the plan. This is the only function with side effects.
def execute_plan(plan)
  target = plan['pandoc']['target']
  md_out = Pathname.new(target['markdown'])
  pdf_out = Pathname.new(target['pdf'])
  side_effects = plan['side_effects']

  md_out.dirname.mkpath
  File.write(md_out.to_s, merged_markdown(plan['chapters'], side_effects['clearpage_between_h1']))

  emoji = side_effects['emoji']
  if emoji['enabled']
    emoji_dir = Pathname.new(emoji['dir'])
    emoji_dir.mkpath
    missing_svg = Pathname.new(emoji['missing_svg'])
    File.write(missing_svg.to_s, MISSING_SVG) unless missing_svg.file?

    prepare_argv = emoji['prepare_argv']
    if prepare_argv
      ok_prep = system(*prepare_argv)
      puts "⚠️  #{t('render.warn.emoji_prepare', 'Could not auto-prepare emojis; continuing with fallback')}" unless ok_prep
    end
  end

  Pathname.new(side_effects['mermaid']['dir']).mkpath

  puts "✅ #{t('render.mode.native', 'Native mode enabled')}"
  puts "📄 #{t('render.output.markdown', 'Merged markdown: {path}', path: md_out)}"
  puts "🖨️  #{t('render.output.pdf', 'Output PDF: {path}', path: pdf_out)}"
  puts "▶ #{t('render.command.exec', 'Running: {command}', command: plan['pandoc']['argv'].join(' '))}"

  ok = system(plan['env'], *plan['pandoc']['argv'])
  exit_code = ok ? 0 : ($?.exitstatus || 1)
  if exit_code.zero? && !side_effects['keep_merged_markdown'] && md_out.file?
    File.delete(md_out.to_s)
  end
  exit_code
end

def print_plan(plan)
  target = plan['pandoc']['target']
  puts t('render.plan.title', 'Render plan (dry run, nothing written)')
  puts "📄 #{t('render.output.markdown', 'Merged markdown: {path}', path: target['markdown'])}"
  puts "🖨️  #{t('render.output.pdf', 'Output PDF: {path}', path: target['pdf'])}"
  puts "▶ #{t('render.plan.command', 'Command: {command}', command: plan['pandoc']['argv'].join(' '))}"
end

def main(argv)
  plan_mode = nil
  positional = []
  argv.each do |arg|
    case arg
    when '--plan-json'
      plan_mode = 'json'
    when '--plan'
      plan_mode ||= 'human'
    else
      positional << arg
    end
  end

  if positional.size < 2
    die(t('render.error.usage', 'Usage: render-native.rb <config.yaml> <toolkit_root> [--plan|--plan-json]'))
  end

  cfg_path = Pathname.new(positional[0])
  root_dir = Pathname.new(positional[1])

  die(t('render.error.config_not_found', 'Config not found: {path}', path: cfg_path)) unless cfg_path.file?

  cfg_user = load_yaml_map(cfg_path)
  plan = build_plan(cfg_user, cfg_path, root_dir)

  if plan_mode == 'json'
    puts JSON.pretty_generate(plan)
    exit 0
  end
  if plan_mode == 'human'
    print_plan(plan)
    exit 0
  end

  exit(execute_plan(plan))
end

main(ARGV) if $PROGRAM_NAME == __FILE__
