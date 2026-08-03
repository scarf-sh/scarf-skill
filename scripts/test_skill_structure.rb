#!/usr/bin/env ruby

require "open3"
require "rbconfig"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)
CHECKER = File.join(__dir__, "check_skill_structure.rb")
SKILL_PATH = File.join(ROOT, "SKILL.md")

def run_checker(contents)
  Dir.mktmpdir("scarf-skill-structure-test") do |directory|
    skill_path = File.join(directory, "SKILL.md")
    File.write(skill_path, contents)
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, CHECKER, skill_path)
    [stdout + stderr, status.success?]
  end
end

baseline = File.read(SKILL_PATH)
baseline_output, baseline_success = run_checker(baseline)
abort "baseline skill-structure check failed:\n#{baseline_output}" unless baseline_success

cases = [
  [
    "duplicate invocation key",
    "duplicate SKILL.md frontmatter key: user-invocable",
    baseline.sub("user-invocable: true", "user-invocable: false\nuser-invocable: true")
  ],
  [
    "duplicate description key",
    "duplicate SKILL.md frontmatter key: description",
    baseline.sub("description:", "description: shadowed\ndescription:")
  ],
  [
    "frontmatter merge key",
    "SKILL.md frontmatter merge keys are not allowed",
    baseline.sub("name: scarf-skill", "<<: &defaults {name: shadowed}\nname: scarf-skill")
  ]
]

failures = []
cases.each do |label, expected, contents|
  output, success = run_checker(contents)
  next if !success && output.include?(expected)

  failures << "#{label}: expected #{expected.inspect}; success=#{success}\n#{output}"
end

abort failures.join("\n\n") unless failures.empty?
puts "Skill structure mutation tests OK: baseline plus #{cases.length} fail-closed scenarios"
