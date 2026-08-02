#!/usr/bin/env ruby

require "json"
require "open-uri"
require "yaml"

ROOT = File.expand_path("..", __dir__)
DEFAULT_MAP = File.join(ROOT, "references", "api-map.json")
DEFAULT_SPEC = "https://api.scarf.sh/static/api-v2.yaml"
DEFAULT_INVENTORY = File.join(ROOT, "references", "api-v2-endpoint-inventory.md")
HTTP_METHODS = %w[get put post delete options head patch trace].freeze
APPROVED_READ_LIKE_POSTS = %w[search chat_with_scarf_ai].freeze
EXPECTED_CONDITIONALLY_PROTECTED = %w[
  createInsightsFilter
  updateInsightsFilter
  createCollection
  updateCollection
].freeze

map_path = ARGV[0] || DEFAULT_MAP
spec_source = ARGV[1] || DEFAULT_SPEC
inventory_path = ARGV[2] || DEFAULT_INVENTORY

def read_source(source)
  return URI.open(source, &:read) if source.match?(%r{\Ahttps?://})

  File.read(source)
end

def duplicates(values)
  values.group_by { |value| value }.select { |_value, matches| matches.length > 1 }.keys
end

map = JSON.parse(File.read(map_path))
spec = YAML.load(read_source(spec_source))

operations = []
(spec["paths"] || {}).each do |path, path_item|
  path_item.each do |method, operation|
    next unless HTTP_METHODS.include?(method)

    operations << [operation.fetch("operationId"), method.upcase, path]
  end
end

operation_ids = operations.map(&:first)
inventory_operations = File.readlines(inventory_path).each_with_object([]) do |line, entries|
  match = line.match(/^\| `([^`]+)` \| `(#{HTTP_METHODS.map(&:upcase).join("|")})` \| `([^`]+)` \|/)
  entries << [match[1], match[2], match[3]] if match
end
inventory_operation_ids = inventory_operations.map(&:first)
manifest = map.fetch("publicOperationManifest")
read_profile = map.dig("deploymentProfiles", "read")
admin_profile = map.dig("deploymentProfiles", "admin")
policy = map.fetch("policy")
read_like_posts = policy.fetch("readLikePost")
standard_mutations = policy.fetch("standardMutations")
protected_mutations = policy.fetch("protectedMutations")
protected_conditions = policy.fetch("protectedConditions")
classified_writes = read_like_posts + standard_mutations + protected_mutations
non_get_operations = operations.reject { |_id, method, _path| method == "GET" }.map(&:first)
expected_read_profile = operations.select { |_id, method, _path| method == "GET" }.map(&:first) + read_like_posts
expected_admin_profile = standard_mutations + protected_mutations
operation_methods = operations.each_with_object({}) { |(id, method, _path), result| result[id] = method }
capabilities = map.fetch("capabilities")
invalid_capability_groups = capabilities.select do |_name, operation_list|
  !operation_list.is_a?(Array) || !operation_list.all? { |operation_id| operation_id.is_a?(String) }
end
capability_operations = capabilities.values.select { |value| value.is_a?(Array) }.flatten.uniq

errors = []
errors << "source count is #{operation_ids.length}, map declares #{map.dig("source", "operationCount")}" unless operation_ids.length == map.dig("source", "operationCount")
errors << "manifest has duplicates: #{duplicates(manifest).join(", ")}" unless duplicates(manifest).empty?
errors << "manifest is missing: #{(operation_ids - manifest).join(", ")}" unless (operation_ids - manifest).empty?
errors << "manifest has unknown operations: #{(manifest - operation_ids).join(", ")}" unless (manifest - operation_ids).empty?
errors << "inventory has duplicates: #{duplicates(inventory_operation_ids).join(", ")}" unless duplicates(inventory_operation_ids).empty?
errors << "inventory is missing or stale: #{(operations - inventory_operations).map { |entry| entry.join(" ") }.join(", ")}" unless (operations - inventory_operations).empty?
errors << "inventory has unknown or stale entries: #{(inventory_operations - operations).map { |entry| entry.join(" ") }.join(", ")}" unless (inventory_operations - operations).empty?
errors << "read profile has duplicates: #{duplicates(read_profile).join(", ")}" unless duplicates(read_profile).empty?
errors << "read profile is missing: #{(expected_read_profile - read_profile).join(", ")}" unless (expected_read_profile - read_profile).empty?
errors << "read profile has non-read operations: #{(read_profile - expected_read_profile).join(", ")}" unless (read_profile - expected_read_profile).empty?
errors << "admin profile has duplicates: #{duplicates(admin_profile).join(", ")}" unless duplicates(admin_profile).empty?
errors << "admin profile is missing: #{(expected_admin_profile - admin_profile).join(", ")}" unless (expected_admin_profile - admin_profile).empty?
errors << "admin profile has non-admin operations: #{(admin_profile - expected_admin_profile).join(", ")}" unless (admin_profile - expected_admin_profile).empty?
errors << "deployment profiles overlap: #{(read_profile & admin_profile).join(", ")}" unless (read_profile & admin_profile).empty?
errors << "deployment profiles do not cover the manifest" unless (read_profile + admin_profile).sort == manifest.sort
errors << "read-like operations must be exactly: #{APPROVED_READ_LIKE_POSTS.join(", ")}" unless read_like_posts.sort == APPROVED_READ_LIKE_POSTS.sort
errors << "read-like operations must use POST: #{read_like_posts.reject { |id| operation_methods[id] == "POST" }.join(", ")}" unless read_like_posts.all? { |id| operation_methods[id] == "POST" }
errors << "conditionally protected operations must be exactly: #{EXPECTED_CONDITIONALLY_PROTECTED.join(", ")}" unless protected_conditions.keys.sort == EXPECTED_CONDITIONALLY_PROTECTED.sort
errors << "conditional protection keys must also be standard mutations: #{(protected_conditions.keys - standard_mutations).join(", ")}" unless (protected_conditions.keys - standard_mutations).empty?
errors << "conditional protection descriptions must be non-empty strings" unless protected_conditions.values.all? { |value| value.is_a?(String) && !value.empty? }
errors << "default profile must be read" unless policy["defaultProfile"] == "read"
errors << "admin profile must require explicit enablement" unless policy["adminRequiresExplicitEnablement"] == true
errors << "deployment profiles must not combine by default" unless policy["combineDeploymentProfilesByDefault"] == false
errors << "write classifications have duplicates: #{duplicates(classified_writes).join(", ")}" unless duplicates(classified_writes).empty?
errors << "non-GET operations are unclassified: #{(non_get_operations - classified_writes).join(", ")}" unless (non_get_operations - classified_writes).empty?
errors << "write classifications include GET or unknown operations: #{(classified_writes - non_get_operations).join(", ")}" unless (classified_writes - non_get_operations).empty?
errors << "capability groups must be arrays of operation IDs: #{invalid_capability_groups.keys.join(", ")}" unless invalid_capability_groups.empty?
errors << "capability groups are missing: #{(operation_ids - capability_operations).join(", ")}" unless (operation_ids - capability_operations).empty?
errors << "capability groups have unknown operations: #{(capability_operations - operation_ids).join(", ")}" unless (capability_operations - operation_ids).empty?

unless errors.empty?
  warn errors.join("\n")
  exit 1
end

puts "API coverage OK: #{operation_ids.length} operations; #{read_profile.length} read and #{admin_profile.length} explicitly enabled admin operations"
