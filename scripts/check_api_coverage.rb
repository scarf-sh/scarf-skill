#!/usr/bin/env ruby

require "digest"
require "json"
require "open-uri"
require "yaml"

ROOT = File.expand_path("..", __dir__)
DEFAULT_MAP = File.join(ROOT, "references", "api-map.json")
DEFAULT_SPEC = "https://api.scarf.sh/static/api-v2.yaml"
DEFAULT_INVENTORY = File.join(ROOT, "references", "api-v2-endpoint-inventory.md")

HTTP_METHODS = %w[get put post delete options head patch trace].freeze
HTTP_METHODS_UPPER = HTTP_METHODS.map(&:upcase).freeze
EXPECTED_TOP_LEVEL_KEYS = %w[capabilities deploymentProfiles policy publicOperationManifest source version].freeze
EXPECTED_SOURCE_KEYS = %w[asOf operationCount url].freeze
EXPECTED_POLICY_KEYS = %w[
  adminRequiresExplicitEnablement
  adminScope
  combineDeploymentProfilesByDefault
  defaultProfile
  protectedConditions
  protectedMutations
  readLikePost
  standardMutations
].freeze
EXPECTED_DEPLOYMENT_PROFILES = %w[admin read].freeze

# These are independent release pins. A published route change must be reviewed,
# then updated here and in the manifest, inventory, profiles, and policy together.
EXPECTED_PUBLIC_OPERATION_DIGEST = "d1412c2211f9e66bca7db78377c6f3b655174fee820e63ef4a8f25c3809e6f3f"
EXPECTED_CAPABILITY_DIGEST = "58f737c52059f377bb4a3a6ce28af730686ec12f04e2b9b554577a9ce7dd54f5"
APPROVED_READ_LIKE_OPERATIONS = [
  ["search", "POST", "/v2/search"],
  ["chat_with_scarf_ai", "POST", "/v3/organizations/{owner}/ai/chat"]
].freeze
APPROVED_STANDARD_OPERATIONS = [
  ["createInsightsFilter", "POST", "/v2/insights/{owner}/filters"],
  ["updateInsightsFilter", "PUT", "/v2/insights/{owner}/filters/{filter_id}"],
  ["requestDomainVerification", "POST", "/v2/domains/{owner}/{domain_ref}/request-verification"],
  ["createCollection", "POST", "/v2/collections/{owner}"],
  ["updateCollection", "PUT", "/v2/collections/{owner}/{collection_id}"],
  ["create_positive_endpoint_feedback", "POST", "/v3/organizations/{owner}/endpoint-feedback/matches"],
  ["create_negative_endpoint_feedback", "POST", "/v3/organizations/{owner}/endpoint-feedback/unmatches"]
].freeze
EXPECTED_PROTECTED_CONDITIONS = {
  "createInsightsFilter" => "scope=global",
  "updateInsightsFilter" => "global scope or unknown existing scope",
  "createCollection" => "membership is broad, inferred, or not fully enumerated",
  "updateCollection" => "membership removal or membership is broad, inferred, or not fully enumerated"
}.freeze

def read_source(source)
  return URI.open(source, &:read) if source.match?(%r{\Ahttps?://})

  File.read(source)
end

def duplicates(values)
  values.group_by { |value| value }.select { |_value, matches| matches.length > 1 }.keys
end

def canonical_digest(value)
  Digest::SHA256.hexdigest(JSON.generate(value))
end

def capability_digest(capabilities)
  normalized = capabilities.keys.sort.each_with_object({}) do |name, result|
    result[name] = capabilities.fetch(name).sort
  end
  canonical_digest(normalized)
end

def require_hash!(value, label)
  raise "#{label} must be an object" unless value.is_a?(Hash)

  value
end

def require_exact_keys!(value, expected_keys, label)
  require_hash!(value, label)
  actual_keys = value.keys.sort
  return if actual_keys == expected_keys.sort

  raise "#{label} keys changed: expected #{expected_keys.sort.join(", ")}; got #{actual_keys.join(", ")}"
end

def require_string_array!(value, label)
  unless value.is_a?(Array) && value.all? { |entry| entry.is_a?(String) && !entry.empty? }
    raise "#{label} must be an array of non-empty strings"
  end

  value
end

def resolve_json_pointer(document, reference)
  unless reference.is_a?(String) && reference.start_with?("#/")
    raise "unsupported external path-item reference: #{reference.inspect}"
  end

  reference.delete_prefix("#/").split("/").reduce(document) do |node, raw_token|
    token = raw_token.gsub("~1", "/").gsub("~0", "~")
    raise "unresolved path-item reference: #{reference}" unless node.is_a?(Hash) && node.key?(token)

    node.fetch(token)
  end
end

def resolve_path_item(document, path_item)
  resolved = path_item
  visited = []

  while resolved.is_a?(Hash) && resolved.key?("$ref")
    reference = resolved.fetch("$ref")
    raise "circular path-item reference: #{reference}" if visited.include?(reference)

    visited << reference
    target = resolve_json_pointer(document, reference)
    raise "path-item reference is not an object: #{reference}" unless target.is_a?(Hash)

    resolved = target.merge(resolved.reject { |key, _value| key == "$ref" })
  end

  require_hash!(resolved, "OpenAPI path item")
end

def extract_operations(spec)
  require_hash!(spec, "OpenAPI document")
  paths = require_hash!(spec["paths"], "OpenAPI paths")

  paths.each_with_object([]) do |(path, unresolved_path_item), operations|
    raise "OpenAPI path must start with /: #{path.inspect}" unless path.is_a?(String) && path.start_with?("/")

    path_item = resolve_path_item(spec, unresolved_path_item)
    path_item.each do |method, operation|
      next unless HTTP_METHODS.include?(method)

      require_hash!(operation, "OpenAPI operation #{method.upcase} #{path}")
      operation_id = operation["operationId"]
      unless operation_id.is_a?(String) && !operation_id.empty?
        raise "OpenAPI operation #{method.upcase} #{path} has no non-empty operationId"
      end

      operations << [operation_id, method.upcase, path]
    end
  end
end

def extract_manifest(map)
  manifest = map.fetch("publicOperationManifest")
  raise "publicOperationManifest must be an array" unless manifest.is_a?(Array)

  manifest.map.with_index do |entry, index|
    label = "publicOperationManifest[#{index}]"
    require_exact_keys!(entry, %w[method operationId path], label)
    operation_id = entry.fetch("operationId")
    method = entry.fetch("method")
    path = entry.fetch("path")
    raise "#{label}.operationId must be a non-empty string" unless operation_id.is_a?(String) && !operation_id.empty?
    raise "#{label}.method is not an HTTP operation method" unless HTTP_METHODS_UPPER.include?(method)
    raise "#{label}.path must start with /" unless path.is_a?(String) && path.start_with?("/")

    [operation_id, method, path]
  end
end

def extract_inventory(path)
  operations = []
  sections = []
  current_section = nil
  declared_total = nil
  operation_pattern = /^\| `([^`]+)` \| `(#{HTTP_METHODS_UPPER.join("|")})` \| `([^`]+)` \|/

  File.readlines(path).each do |line|
    total_match = line.match(/^Total operations: (\d+)$/)
    declared_total = total_match[1].to_i if total_match

    if (section_match = line.match(/^## (.+) \((\d+)\)$/))
      current_section = { name: section_match[1], expected: section_match[2].to_i, actual: 0 }
      sections << current_section
      next
    elsif line.start_with?("## ")
      current_section = nil
    end

    next unless (operation_match = line.match(operation_pattern))

    operations << [operation_match[1], operation_match[2], operation_match[3]]
    current_section[:actual] += 1 if current_section
  end

  [operations, declared_total, sections]
end

map_path = ARGV[0] || DEFAULT_MAP
spec_source = ARGV[1] || DEFAULT_SPEC
inventory_path = ARGV[2] || DEFAULT_INVENTORY

begin
  map = JSON.parse(File.read(map_path))
  require_exact_keys!(map, EXPECTED_TOP_LEVEL_KEYS, "API map")
  raise "version must be v2-public-api" unless map["version"] == "v2-public-api"

  source = map.fetch("source")
  require_exact_keys!(source, EXPECTED_SOURCE_KEYS, "source")
  raise "source.url must remain #{DEFAULT_SPEC}" unless source["url"] == DEFAULT_SPEC
  raise "source.asOf must use YYYY-MM-DD" unless source["asOf"].is_a?(String) && source["asOf"].match?(/\A\d{4}-\d{2}-\d{2}\z/)
  raise "source.operationCount must be a positive integer" unless source["operationCount"].is_a?(Integer) && source["operationCount"].positive?

  policy = map.fetch("policy")
  require_exact_keys!(policy, EXPECTED_POLICY_KEYS, "policy")
  read_like_posts = require_string_array!(policy.fetch("readLikePost"), "policy.readLikePost")
  standard_mutations = require_string_array!(policy.fetch("standardMutations"), "policy.standardMutations")
  protected_mutations = require_string_array!(policy.fetch("protectedMutations"), "policy.protectedMutations")
  protected_conditions = require_hash!(policy.fetch("protectedConditions"), "policy.protectedConditions")
  unless protected_conditions.all? { |key, value| key.is_a?(String) && value.is_a?(String) && !value.empty? }
    raise "policy.protectedConditions must map operation IDs to non-empty strings"
  end

  deployment_profiles = map.fetch("deploymentProfiles")
  require_exact_keys!(deployment_profiles, EXPECTED_DEPLOYMENT_PROFILES, "deploymentProfiles")
  read_profile = require_string_array!(deployment_profiles.fetch("read"), "deploymentProfiles.read")
  admin_profile = require_string_array!(deployment_profiles.fetch("admin"), "deploymentProfiles.admin")

  capabilities = require_hash!(map.fetch("capabilities"), "capabilities")
  raise "capabilities must not be empty" if capabilities.empty?
  capabilities.each do |name, operation_list|
    raise "capability names must be non-empty strings" unless name.is_a?(String) && !name.empty?
    require_string_array!(operation_list, "capabilities.#{name}")
  end

  spec = YAML.safe_load(read_source(spec_source), aliases: true)
  operations = extract_operations(spec)
  operation_ids = operations.map(&:first)
  manifest_operations = extract_manifest(map)
  manifest_ids = manifest_operations.map(&:first)
  inventory_operations, inventory_declared_total, inventory_sections = extract_inventory(inventory_path)
  inventory_ids = inventory_operations.map(&:first)
  capability_operations = capabilities.values.flatten

  operation_by_id = operations.each_with_object({}) do |operation, result|
    result[operation.first] = operation
  end
  approved_read_like_ids = APPROVED_READ_LIKE_OPERATIONS.map(&:first)
  approved_standard_ids = APPROVED_STANDARD_OPERATIONS.map(&:first)
  non_get_ids = operations.reject { |_id, method, _path| method == "GET" }.map(&:first)
  expected_read_profile = operations.select { |_id, method, _path| method == "GET" }.map(&:first) + approved_read_like_ids
  expected_protected_mutations = non_get_ids - approved_read_like_ids - approved_standard_ids
  expected_admin_profile = approved_standard_ids + expected_protected_mutations
  classified_writes = read_like_posts + standard_mutations + protected_mutations

  errors = []
  errors << "OpenAPI operation IDs have duplicates: #{duplicates(operation_ids).join(", ")}" unless duplicates(operation_ids).empty?
  errors << "OpenAPI operation tuples have duplicates" unless duplicates(operations).empty?
  errors << "source count is #{operations.length}, map declares #{source["operationCount"]}" unless operations.length == source["operationCount"]
  errors << "manifest count is #{manifest_operations.length}, map declares #{source["operationCount"]}" unless manifest_operations.length == source["operationCount"]
  errors << "manifest operation IDs have duplicates: #{duplicates(manifest_ids).join(", ")}" unless duplicates(manifest_ids).empty?
  errors << "manifest operation tuples have duplicates" unless duplicates(manifest_operations).empty?
  manifest_digest = canonical_digest(manifest_operations.sort)
  unless manifest_digest == EXPECTED_PUBLIC_OPERATION_DIGEST
    errors << "published operation routes changed; review and update the release pin (expected #{EXPECTED_PUBLIC_OPERATION_DIGEST.inspect}, got #{manifest_digest.inspect})"
  end
  errors << "manifest is missing or stale: #{(operations - manifest_operations).map { |entry| entry.join(" ") }.join(", ")}" unless (operations - manifest_operations).empty?
  errors << "manifest has unknown or stale routes: #{(manifest_operations - operations).map { |entry| entry.join(" ") }.join(", ")}" unless (manifest_operations - operations).empty?

  errors << "inventory must declare Total operations" if inventory_declared_total.nil?
  errors << "inventory declares #{inventory_declared_total}, contains #{inventory_operations.length}" if inventory_declared_total && inventory_declared_total != inventory_operations.length
  errors << "inventory section counts do not total #{inventory_operations.length}" unless inventory_sections.sum { |section| section[:expected] } == inventory_operations.length
  inventory_sections.each do |section|
    next if section[:expected] == section[:actual]

    errors << "inventory section #{section[:name]} declares #{section[:expected]}, contains #{section[:actual]}"
  end
  errors << "inventory operation IDs have duplicates: #{duplicates(inventory_ids).join(", ")}" unless duplicates(inventory_ids).empty?
  errors << "inventory operation tuples have duplicates" unless duplicates(inventory_operations).empty?
  errors << "inventory is missing or stale: #{(operations - inventory_operations).map { |entry| entry.join(" ") }.join(", ")}" unless (operations - inventory_operations).empty?
  errors << "inventory has unknown or stale entries: #{(inventory_operations - operations).map { |entry| entry.join(" ") }.join(", ")}" unless (inventory_operations - operations).empty?

  errors << "read profile has duplicates: #{duplicates(read_profile).join(", ")}" unless duplicates(read_profile).empty?
  errors << "read profile is missing: #{(expected_read_profile - read_profile).join(", ")}" unless (expected_read_profile - read_profile).empty?
  errors << "read profile has non-read operations: #{(read_profile - expected_read_profile).join(", ")}" unless (read_profile - expected_read_profile).empty?
  errors << "admin profile has duplicates: #{duplicates(admin_profile).join(", ")}" unless duplicates(admin_profile).empty?
  errors << "admin profile is missing: #{(expected_admin_profile - admin_profile).join(", ")}" unless (expected_admin_profile - admin_profile).empty?
  errors << "admin profile has non-admin operations: #{(admin_profile - expected_admin_profile).join(", ")}" unless (admin_profile - expected_admin_profile).empty?
  errors << "deployment profiles overlap: #{(read_profile & admin_profile).join(", ")}" unless (read_profile & admin_profile).empty?
  errors << "deployment profiles do not cover the manifest exactly once" unless (read_profile + admin_profile).sort == manifest_ids.sort

  actual_read_like_operations = read_like_posts.map { |operation_id| operation_by_id[operation_id] }.compact
  errors << "read-like operations or routes changed" unless actual_read_like_operations.sort == APPROVED_READ_LIKE_OPERATIONS.sort
  errors << "read-like operation IDs must be exactly: #{approved_read_like_ids.join(", ")}" unless read_like_posts.sort == approved_read_like_ids.sort
  actual_standard_operations = standard_mutations.map { |operation_id| operation_by_id[operation_id] }.compact
  errors << "standard operations or routes changed" unless actual_standard_operations.sort == APPROVED_STANDARD_OPERATIONS.sort
  errors << "standard mutation IDs must be exactly: #{approved_standard_ids.join(", ")}" unless standard_mutations.sort == approved_standard_ids.sort
  errors << "DELETE operations cannot be standard mutations" unless actual_standard_operations.none? { |_id, method, _path| method == "DELETE" }
  errors << "protected mutations are missing: #{(expected_protected_mutations - protected_mutations).join(", ")}" unless (expected_protected_mutations - protected_mutations).empty?
  errors << "protected mutations contain non-protected operations: #{(protected_mutations - expected_protected_mutations).join(", ")}" unless (protected_mutations - expected_protected_mutations).empty?
  errors << "all DELETE operations must be protected" unless operations.select { |_id, method, _path| method == "DELETE" }.all? { |id, _method, _path| protected_mutations.include?(id) }
  errors << "conditional protection predicates changed" unless protected_conditions == EXPECTED_PROTECTED_CONDITIONS
  errors << "conditional protection keys must also be standard mutations: #{(protected_conditions.keys - standard_mutations).join(", ")}" unless (protected_conditions.keys - standard_mutations).empty?
  errors << "default profile must be read" unless policy["defaultProfile"] == "read"
  errors << "admin scope must be single-explicit-task" unless policy["adminScope"] == "single-explicit-task"
  errors << "admin profile must require explicit enablement" unless policy["adminRequiresExplicitEnablement"] == true
  errors << "deployment profiles must not combine by default" unless policy["combineDeploymentProfilesByDefault"] == false
  errors << "write classifications have duplicates: #{duplicates(classified_writes).join(", ")}" unless duplicates(classified_writes).empty?
  errors << "non-GET operations are unclassified: #{(non_get_ids - classified_writes).join(", ")}" unless (non_get_ids - classified_writes).empty?
  errors << "write classifications include GET or unknown operations: #{(classified_writes - non_get_ids).join(", ")}" unless (classified_writes - non_get_ids).empty?

  errors << "capability group names or memberships changed" unless capability_digest(capabilities) == EXPECTED_CAPABILITY_DIGEST
  errors << "capability groups contain duplicate assignments: #{duplicates(capability_operations).join(", ")}" unless duplicates(capability_operations).empty?
  errors << "capability groups are missing: #{(operation_ids - capability_operations).join(", ")}" unless (operation_ids - capability_operations).empty?
  errors << "capability groups have unknown operations: #{(capability_operations - operation_ids).join(", ")}" unless (capability_operations - operation_ids).empty?

  unless errors.empty?
    warn errors.join("\n")
    exit 1
  end

  puts "API coverage OK: #{operation_ids.length} operations; #{read_profile.length} read and #{admin_profile.length} explicitly enabled admin operations"
rescue StandardError => e
  warn "API coverage check failed: #{e.message}"
  exit 1
end
