#!/usr/bin/env ruby

require "yaml"

root = File.expand_path("..", __dir__)
skill_path = ARGV[0] || File.join(root, "SKILL.md")
parts = File.read(skill_path).split(/^---\s*$/, 3)
abort "SKILL.md must begin with YAML frontmatter" unless parts.length == 3 && parts.first.strip.empty?

frontmatter_text = parts.fetch(1)
begin
  stream = Psych.parse_stream(frontmatter_text)
  abort "SKILL.md frontmatter must contain exactly one YAML document" unless stream.children.length == 1
  mapping = stream.children.first.root
  abort "SKILL.md frontmatter must be a mapping" unless mapping.is_a?(Psych::Nodes::Mapping)

  seen = {}
  mapping.children.each_slice(2) do |key_node, _value_node|
    abort "SKILL.md frontmatter keys must be scalars" unless key_node.is_a?(Psych::Nodes::Scalar)

    key = key_node.value
    abort "SKILL.md frontmatter merge keys are not allowed" if key == "<<"
    abort "duplicate SKILL.md frontmatter key: #{key}" if seen[key]

    seen[key] = true
  end
  frontmatter = YAML.safe_load(frontmatter_text, aliases: false)
rescue Psych::SyntaxError => error
  abort "invalid SKILL.md frontmatter: #{error.message}"
end
abort "SKILL.md frontmatter must be a mapping" unless frontmatter.is_a?(Hash)

expected_keys = %w[description name user-invocable]
unless frontmatter.keys.sort == expected_keys
  abort "SKILL.md frontmatter keys must be exactly: #{expected_keys.join(", ")}"
end

abort "SKILL.md name must be scarf-skill" unless frontmatter["name"] == "scarf-skill"
description = frontmatter["description"]
abort "SKILL.md description must be non-empty" unless description.is_a?(String) && !description.strip.empty?
abort "SKILL.md must remain user-invocable" unless frontmatter["user-invocable"] == true

puts "Skill structure OK"
