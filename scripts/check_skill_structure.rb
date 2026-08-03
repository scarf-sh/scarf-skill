#!/usr/bin/env ruby

require "yaml"

root = File.expand_path("..", __dir__)
skill_path = File.join(root, "SKILL.md")
parts = File.read(skill_path).split(/^---\s*$/, 3)
abort "SKILL.md must begin with YAML frontmatter" unless parts.length == 3 && parts.first.strip.empty?

frontmatter = YAML.safe_load(parts.fetch(1), aliases: false)
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
