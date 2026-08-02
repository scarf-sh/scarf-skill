#!/usr/bin/env ruby

require "json"
require "open-uri"
require "yaml"

ROOT = File.expand_path("..", __dir__)
DEFAULT_MAP = File.join(ROOT, "references", "api-map.json")
DEFAULT_SPEC = "https://api.scarf.sh/static/api-v2.yaml"
DEFAULT_INVENTORY = File.join(ROOT, "references", "api-v2-endpoint-inventory.md")
HTTP_METHODS = %w[get put post delete options head patch trace].freeze

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
(spec["paths"] || {}).each_value do |path_item|
  path_item.each do |method, operation|
    next unless HTTP_METHODS.include?(method)

    operations << [operation.fetch("operationId"), method.upcase]
  end
end

operation_ids = operations.map(&:first)
inventory_operation_ids = File.readlines(inventory_path).each_with_object([]) do |line, ids|
  match = line.match(/^\| `([^`]+)` \| `(#{HTTP_METHODS.map(&:upcase).join("|")})` \|/)
  ids << match[1] if match
end
allowlist = map.fetch("explicitAllowlist")
policy = map.fetch("policy")
classified_writes = policy.fetch("readLikePost") +
                    policy.fetch("standardMutations") +
                    policy.fetch("protectedMutations")
non_get_operations = operations.reject { |_id, method| method == "GET" }.map(&:first)
capability_operations = map.fetch("capabilities").values.flatten.uniq

errors = []
errors << "source count is #{operation_ids.length}, map declares #{map.dig("source", "operationCount")}" unless operation_ids.length == map.dig("source", "operationCount")
errors << "allowlist has duplicates: #{duplicates(allowlist).join(", ")}" unless duplicates(allowlist).empty?
errors << "allowlist is missing: #{(operation_ids - allowlist).join(", ")}" unless (operation_ids - allowlist).empty?
errors << "allowlist has unknown operations: #{(allowlist - operation_ids).join(", ")}" unless (allowlist - operation_ids).empty?
errors << "inventory has duplicates: #{duplicates(inventory_operation_ids).join(", ")}" unless duplicates(inventory_operation_ids).empty?
errors << "inventory is missing: #{(operation_ids - inventory_operation_ids).join(", ")}" unless (operation_ids - inventory_operation_ids).empty?
errors << "inventory has unknown operations: #{(inventory_operation_ids - operation_ids).join(", ")}" unless (inventory_operation_ids - operation_ids).empty?
errors << "write classifications have duplicates: #{duplicates(classified_writes).join(", ")}" unless duplicates(classified_writes).empty?
errors << "non-GET operations are unclassified: #{(non_get_operations - classified_writes).join(", ")}" unless (non_get_operations - classified_writes).empty?
errors << "write classifications include GET or unknown operations: #{(classified_writes - non_get_operations).join(", ")}" unless (classified_writes - non_get_operations).empty?
errors << "capability groups are missing: #{(operation_ids - capability_operations).join(", ")}" unless (operation_ids - capability_operations).empty?

unless errors.empty?
  warn errors.join("\n")
  exit 1
end

puts "API coverage OK: #{operation_ids.length} operations; #{non_get_operations.length} non-GET operations classified"
