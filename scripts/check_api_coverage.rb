#!/usr/bin/env ruby

require "digest"
require "json"
require "open-uri"
require "yaml"

ROOT = File.expand_path("..", __dir__)
DEFAULT_MAP = File.join(ROOT, "references", "api-map.json")
DEFAULT_SPEC = "https://api.scarf.sh/static/api-v2.yaml"
DEFAULT_INVENTORY = File.join(ROOT, "references", "api-v2-endpoint-inventory.md")
DEFAULT_README = File.join(ROOT, "README.md")
EXPECTED_API_SERVER = "https://api.scarf.sh"
EXPECTED_OPENAPI_VERSION = "3.0.3"
EXPECTED_SOURCE_AS_OF = "2026-08-02"
EXPECTED_AUTH_DESCRIPTION_DIGEST = "8e396c45ea1c55c7f3734d9dd4fc989f212122259625b1efe1767aff26b6022b"
EXPECTED_SECURITY_SCHEMES = {
  "ApiToken" => {
    "type" => "http",
    "scheme" => "bearer",
    "bearerFormat" => "JWT"
  }
}.freeze
EXPECTED_SECURITY_SCHEME_ALIASES = { "ScarfBearer" => "ApiToken" }.freeze
EXPECTED_OPERATION_SECURITY = [
  ["export_entity_aggregations", "GET", "/v3/insights/{owner}/aggregations/export", [{ "ApiToken" => [] }]],
  ["chat_with_scarf_ai", "POST", "/v3/organizations/{owner}/ai/chat", [{ "ApiToken" => [] }]],
  ["create_positive_endpoint_feedback", "POST", "/v3/organizations/{owner}/endpoint-feedback/matches", [{ "ApiToken" => [] }]],
  ["create_negative_endpoint_feedback", "POST", "/v3/organizations/{owner}/endpoint-feedback/unmatches", [{ "ApiToken" => [] }]]
].freeze
HTTP_METHODS = %w[get put post delete options head patch trace].freeze
EXPECTED_TOP_LEVEL_KEYS = %w[capabilities executionProfiles policy publicOperationManifest source version].freeze
EXPECTED_SOURCE_KEYS = %w[asOf operationCount url].freeze
EXPECTED_POLICY_KEYS = %w[adminRequiresExplicitEnablement adminScope combineExecutionProfilesByDefault defaultProfile protectedConditions protectedMutations readLikePost standardMutations].freeze
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
APPROVED_READ_LIKE_IDS = APPROVED_READ_LIKE_OPERATIONS.map(&:first).freeze
APPROVED_STANDARD_IDS = APPROVED_STANDARD_OPERATIONS.map(&:first).freeze
EXPECTED_PROTECTED_CONDITIONS = {
  "createInsightsFilter" => "scope=global",
  "updateInsightsFilter" => "global scope or unknown existing scope",
  "createCollection" => "membership is broad, inferred, or not fully enumerated",
  "updateCollection" => "membership removal or membership is broad, inferred, or not fully enumerated"
}.freeze
EXPECTED_PUBLIC_OPERATION_DIGEST = "d1412c2211f9e66bca7db78377c6f3b655174fee820e63ef4a8f25c3809e6f3f"
EXPECTED_CAPABILITY_DIGEST = "58f737c52059f377bb4a3a6ce28af730686ec12f04e2b9b554577a9ce7dd54f5"
EXPECTED_INVENTORY_SECTIONS = [
  "Collections", "Company", "Domains", "External event import", "Insights Filters", "Organization",
  "Organizations", "Packages", "Search", "Tracking Pixels", "Users", "v3 Insights and AI"
].freeze
EXPECTED_INVENTORY_SECTION_DIGEST = "a4d1d1b86ed3e9f151b15f324ab8769bacbbcb6bd68caf5515ebb17b5fa75f58"
EXPECTED_REQUEST_SCHEMA_DIGEST = "3804333f948d005e642a58a69578378e427c3011e494919c107c8ee876b3dc30"

class DuplicateKeyHash < Hash
  def []=(key, value)
    raise JSON::ParserError, "duplicate JSON key: #{key}" if key?(key)

    super
  end
end

map_path = ARGV[0] || DEFAULT_MAP
spec_source = ARGV[1] || DEFAULT_SPEC
inventory_path = ARGV[2] || DEFAULT_INVENTORY
readme_path = ARGV[3] || DEFAULT_README

def read_source(source)
  return URI.open(source, &:read) if source.match?(%r{\Ahttps?://})

  File.read(source)
end

def validate_yaml_mapping_keys!(node, path = [])
  case node
  when Psych::Nodes::Mapping
    seen = {}
    node.children.each_slice(2) do |key_node, value_node|
      raise "non-scalar YAML mapping key at #{path.join(".")}" unless key_node.is_a?(Psych::Nodes::Scalar)

      key = key_node.value
      location = (path + [key]).join(".")
      raise "YAML merge keys are not allowed: #{location}" if key == "<<"
      raise "duplicate YAML key: #{location}" if seen[key]

      seen[key] = true
      validate_yaml_mapping_keys!(value_node, path + [key])
    end
  when Psych::Nodes::Sequence
    node.children.each_with_index { |child, index| validate_yaml_mapping_keys!(child, path + [index.to_s]) }
  when Psych::Nodes::Stream, Psych::Nodes::Document
    node.children.each { |child| validate_yaml_mapping_keys!(child, path) }
  end
end

def duplicates(values)
  values.group_by { |value| value }.select { |_value, matches| matches.length > 1 }.keys
end

def tuple_digest(tuples)
  Digest::SHA256.hexdigest(JSON.generate(tuples.sort))
end

def canonicalize_schema(value)
  case value
  when Hash
    value.keys.sort.each_with_object({}) do |key, result|
      result[key] = canonicalize_schema(value.fetch(key))
    end
  when Array
    value.map { |entry| canonicalize_schema(entry) }
  else
    value
  end
end

def capability_digest(capabilities)
  normalized = capabilities.keys.sort.each_with_object({}) do |name, result|
    operations = capabilities.fetch(name)
    result[name] = operations.is_a?(Array) ? operations.sort : operations
  end
  Digest::SHA256.hexdigest(JSON.generate(normalized))
end

def normalize_security_requirements(requirements, declared_schemes, aliases, unresolved)
  unless requirements.is_a?(Array) && requirements.all? { |requirement| requirement.is_a?(Hash) }
    unresolved << "<malformed>"
    return requirements
  end

  requirements.map do |requirement|
    requirement.keys.sort.each_with_object({}) do |name, normalized|
      resolved_name = declared_schemes.key?(name) ? name : aliases[name]
      unless resolved_name && declared_schemes.key?(resolved_name)
        unresolved << name.to_s
        resolved_name = name
      end
      unresolved << "duplicate normalized requirement #{resolved_name}" if normalized.key?(resolved_name)
      normalized[resolved_name] = canonicalize_schema(requirement.fetch(name))
    end
  end
end

def inventory_section_digest(sections)
  normalized = sections.sort_by { |section| section[:name] }.map do |section|
    [section[:name], section[:operations].sort]
  end
  Digest::SHA256.hexdigest(JSON.generate(normalized))
end

def resolve_json_pointer(document, reference)
  raise "unsupported external path-item reference: #{reference}" unless reference.start_with?("#/")

  reference.delete_prefix("#/").split("/").reduce(document) do |node, raw_token|
    token = raw_token.gsub("~1", "/").gsub("~0", "~")
    raise "unresolved path-item reference: #{reference}" unless node.is_a?(Hash) && node.key?(token)

    node.fetch(token)
  end
end

def collect_local_references(document, value, targets = {}, visited = {})
  case value
  when Hash
    if value.key?("$ref")
      reference = value.fetch("$ref")
      target = canonicalize_schema(resolve_json_pointer(document, reference))
      targets[reference] = target
      unless visited[reference]
        visited[reference] = true
        collect_local_references(document, target, targets, visited)
      end
    end
    value.each_value { |child| collect_local_references(document, child, targets, visited) }
  when Array
    value.each { |child| collect_local_references(document, child, targets, visited) }
  end
  targets
end

def request_schema_signature(document, path_item, operation)
  fragment = canonicalize_schema(
    "parameters" => (path_item["parameters"] || []) + (operation["parameters"] || []),
    "requestBody" => operation["requestBody"]
  )
  references = collect_local_references(document, fragment)
  [fragment, canonicalize_schema(references)]
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

    siblings = resolved.reject { |key, _value| key == "$ref" }
    conflicts = target.keys & siblings.keys
    unless conflicts.empty?
      raise "conflicting path-item reference siblings for #{reference}: #{conflicts.sort.join(", ")}"
    end

    resolved = target.merge(siblings)
  end

  resolved
end

map_text = File.read(map_path)
spec_text = read_source(spec_source)
begin
  map = JSON.parse(map_text, object_class: DuplicateKeyHash)
  yaml_stream = Psych.parse_stream(spec_text)
  raise "OpenAPI YAML must contain exactly one document" unless yaml_stream.children.length == 1
  unless yaml_stream.children.first.root.is_a?(Psych::Nodes::Mapping)
    raise "OpenAPI YAML document must be a mapping"
  end
  validate_yaml_mapping_keys!(yaml_stream)
  spec = YAML.safe_load(spec_text, aliases: true)
rescue JSON::ParserError, Psych::SyntaxError, RuntimeError => error
  warn error.message
  exit 1
end

operations = []
request_schemas = []
security_schemes = spec.dig("components", "securitySchemes") || {}
unresolved_security_schemes = []
path_server_overrides = []
operation_server_overrides = []
path_security_metadata = []
operation_security_requirements = []
normalize_security_requirements(spec["security"], security_schemes, EXPECTED_SECURITY_SCHEME_ALIASES, unresolved_security_schemes) if spec.key?("security")
(spec["paths"] || {}).each do |path, path_item|
  path_item = resolve_path_item(spec, path_item)
  path_server_overrides << path if path_item.key?("servers")
  if path_item.key?("security")
    path_security_metadata << path
    normalize_security_requirements(path_item["security"], security_schemes, EXPECTED_SECURITY_SCHEME_ALIASES, unresolved_security_schemes)
  end
  path_item.each do |method, operation|
    next unless HTTP_METHODS.include?(method)

    operations << [operation.fetch("operationId"), method.upcase, path]
    request_schemas << [operation.fetch("operationId"), method.upcase, path, *request_schema_signature(spec, path_item, operation)]
    operation_server_overrides << [operation.fetch("operationId"), method.upcase, path] if operation.key?("servers")
    if operation.key?("security")
      normalized_security = normalize_security_requirements(
        operation.fetch("security"), security_schemes, EXPECTED_SECURITY_SCHEME_ALIASES, unresolved_security_schemes
      )
      operation_security_requirements << [operation.fetch("operationId"), method.upcase, path, normalized_security]
    end
  end
end

operation_ids = operations.map(&:first)
operation_by_id = operations.each_with_object({}) { |operation, result| result[operation.first] = operation }
inventory_text = File.read(inventory_path)
readme_text = File.read(readme_path)
inventory_snapshot_dates = inventory_text.scan(/^- Snapshot checked on (\d{4}-\d{2}-\d{2})\.$/).flatten
readme_snapshot_declarations = readme_text.scan(/^The current capability map covers all (\d+) operations .* as of (\d{4}-\d{2}-\d{2})\./)
readme_operation_count, readme_snapshot_date = readme_snapshot_declarations.one? ? readme_snapshot_declarations.first : [nil, nil]
inventory_sections = []
current_inventory_section = nil
inventory_operations = inventory_text.each_line.each_with_object([]) do |line, entries|
  if (section_match = line.match(/^## (.+) \((\d+)\)$/))
    current_inventory_section = { name: section_match[1], expected: section_match[2].to_i, actual: 0, operations: [] }
    inventory_sections << current_inventory_section
  elsif line.start_with?("## ")
    current_inventory_section = nil
  end

  match = line.match(/^\| `([^`]+)` \| `(#{HTTP_METHODS.map(&:upcase).join("|")})` \| `([^`]+)` \|/)
  if match
    entries << [match[1], match[2], match[3]]
    if current_inventory_section
      current_inventory_section[:actual] += 1
      current_inventory_section[:operations] << match[1]
    end
  end
end
inventory_operation_ids = inventory_operations.map(&:first)
inventory_total = inventory_text[/^Total operations: (\d+)$/, 1]&.to_i
manifest_ids = map.fetch("publicOperationManifest")
read_profile = map.dig("executionProfiles", "read")
admin_profile = map.dig("executionProfiles", "admin")
policy = map.fetch("policy")
read_like_posts = policy.fetch("readLikePost")
standard_mutations = policy.fetch("standardMutations")
protected_mutations = policy.fetch("protectedMutations")
protected_conditions = policy.fetch("protectedConditions")
classified_writes = read_like_posts + standard_mutations + protected_mutations
non_get_operations = operations.reject { |_id, method, _path| method == "GET" }.map(&:first)
expected_read_profile = operations.select { |_id, method, _path| method == "GET" }.map(&:first) + APPROVED_READ_LIKE_IDS
expected_protected_mutations = non_get_operations - APPROVED_READ_LIKE_IDS - APPROVED_STANDARD_IDS
expected_admin_profile = APPROVED_STANDARD_IDS + expected_protected_mutations
actual_read_like_operations = read_like_posts.map { |id| operation_by_id[id] }.compact
actual_standard_operations = standard_mutations.map { |id| operation_by_id[id] }.compact
capabilities = map.fetch("capabilities")
invalid_capability_groups = capabilities.select do |_name, operation_list|
  !operation_list.is_a?(Array) || !operation_list.all? { |operation_id| operation_id.is_a?(String) }
end
capability_operations = capabilities.values.select { |value| value.is_a?(Array) }.flatten

errors = []
errors << "OpenAPI version changed" unless spec["openapi"] == EXPECTED_OPENAPI_VERSION
errors << "top-level API map keys changed" unless map.keys.sort == EXPECTED_TOP_LEVEL_KEYS.sort
errors << "API map version changed" unless map["version"] == "v2-public-api"
errors << "source keys changed" unless map.fetch("source").keys.sort == EXPECTED_SOURCE_KEYS.sort
errors << "source URL changed" unless map.dig("source", "url") == DEFAULT_SPEC
errors << "source snapshot date changed" unless map.dig("source", "asOf") == EXPECTED_SOURCE_AS_OF
errors << "inventory must contain exactly one snapshot date" unless inventory_snapshot_dates.length == 1
errors << "README must contain exactly one snapshot declaration" unless readme_snapshot_declarations.length == 1
errors << "inventory snapshot date does not match source" unless inventory_snapshot_dates == [map.dig("source", "asOf")]
errors << "README snapshot date does not match source" unless readme_snapshot_date == map.dig("source", "asOf")
errors << "README operation count does not match source" unless readme_operation_count&.to_i == map.dig("source", "operationCount")
errors << "public API server changed" unless spec.fetch("servers", []).map { |server| server["url"] } == [EXPECTED_API_SERVER]
errors << "path-level server overrides are not allowed: #{path_server_overrides.join(", ")}" unless path_server_overrides.empty?
unless operation_server_overrides.empty?
  errors << "operation-level server overrides are not allowed: #{operation_server_overrides.map { |entry| entry.join(" ") }.join(", ")}"
end
auth_description_digest = Digest::SHA256.hexdigest(spec.dig("info", "description").to_s)
errors << "API authentication description changed" unless auth_description_digest == EXPECTED_AUTH_DESCRIPTION_DIGEST
errors << "API security schemes changed" unless security_schemes == EXPECTED_SECURITY_SCHEMES
unless unresolved_security_schemes.empty?
  errors << "undefined security schemes referenced: #{unresolved_security_schemes.uniq.sort.join(", ")}"
end
errors << "global security requirements changed" if spec.key?("security")
errors << "path-level security metadata is not allowed: #{path_security_metadata.join(", ")}" unless path_security_metadata.empty?
unless operation_security_requirements.sort_by { |entry| entry.first(3) } == EXPECTED_OPERATION_SECURITY.sort_by { |entry| entry.first(3) }
  errors << "operation security requirements changed"
end
errors << "policy keys changed" unless policy.keys.sort == EXPECTED_POLICY_KEYS.sort
errors << "execution profile keys changed" unless map.fetch("executionProfiles").keys.sort == %w[admin read]
errors << "source count is #{operation_ids.length}, map declares #{map.dig("source", "operationCount")}" unless operation_ids.length == map.dig("source", "operationCount")
errors << "OpenAPI operation IDs have duplicates: #{duplicates(operation_ids).join(", ")}" unless duplicates(operation_ids).empty?
errors << "manifest has duplicate operation IDs: #{duplicates(manifest_ids).join(", ")}" unless duplicates(manifest_ids).empty?
errors << "published operation routes changed" unless tuple_digest(operations) == EXPECTED_PUBLIC_OPERATION_DIGEST
request_schema_digest = Digest::SHA256.hexdigest(JSON.generate(request_schemas.sort_by { |entry| entry.first(3) }))
unless request_schema_digest == EXPECTED_REQUEST_SCHEMA_DIGEST
  errors << "request schemas changed (#{request_schema_digest})"
end
errors << "manifest is missing: #{(operation_ids - manifest_ids).join(", ")}" unless (operation_ids - manifest_ids).empty?
errors << "manifest has unknown operations: #{(manifest_ids - operation_ids).join(", ")}" unless (manifest_ids - operation_ids).empty?
errors << "inventory declares #{inventory_total.inspect}, contains #{inventory_operations.length}" unless inventory_total == inventory_operations.length
errors << "inventory section names changed" unless inventory_sections.map { |section| section[:name] }.sort == EXPECTED_INVENTORY_SECTIONS.sort
errors << "inventory section membership changed" unless inventory_section_digest(inventory_sections) == EXPECTED_INVENTORY_SECTION_DIGEST
inventory_sections.each do |section|
  next if section[:expected] == section[:actual]

  errors << "inventory section #{section[:name]} declares #{section[:expected]}, contains #{section[:actual]}"
end
errors << "inventory has duplicate operation IDs: #{duplicates(inventory_operation_ids).join(", ")}" unless duplicates(inventory_operation_ids).empty?
errors << "inventory has duplicate tuples" unless duplicates(inventory_operations).empty?
errors << "inventory is missing or stale: #{(operations - inventory_operations).map { |entry| entry.join(" ") }.join(", ")}" unless (operations - inventory_operations).empty?
errors << "inventory has unknown or stale entries: #{(inventory_operations - operations).map { |entry| entry.join(" ") }.join(", ")}" unless (inventory_operations - operations).empty?
errors << "read profile has duplicates: #{duplicates(read_profile).join(", ")}" unless duplicates(read_profile).empty?
errors << "read profile is missing: #{(expected_read_profile - read_profile).join(", ")}" unless (expected_read_profile - read_profile).empty?
errors << "read profile has non-read operations: #{(read_profile - expected_read_profile).join(", ")}" unless (read_profile - expected_read_profile).empty?
errors << "admin profile has duplicates: #{duplicates(admin_profile).join(", ")}" unless duplicates(admin_profile).empty?
errors << "admin profile is missing: #{(expected_admin_profile - admin_profile).join(", ")}" unless (expected_admin_profile - admin_profile).empty?
errors << "admin profile has non-admin operations: #{(admin_profile - expected_admin_profile).join(", ")}" unless (admin_profile - expected_admin_profile).empty?
errors << "execution profiles overlap: #{(read_profile & admin_profile).join(", ")}" unless (read_profile & admin_profile).empty?
errors << "execution profiles do not cover the manifest" unless (read_profile + admin_profile).sort == manifest_ids.sort
errors << "read-like operation IDs changed" unless read_like_posts.sort == APPROVED_READ_LIKE_IDS.sort
errors << "read-like operations or routes changed" unless actual_read_like_operations.sort == APPROVED_READ_LIKE_OPERATIONS.sort
errors << "standard mutation IDs changed" unless standard_mutations.sort == APPROVED_STANDARD_IDS.sort
errors << "standard operations or routes changed" unless actual_standard_operations.sort == APPROVED_STANDARD_OPERATIONS.sort
errors << "DELETE operations cannot be standard mutations" unless actual_standard_operations.none? { |_id, method, _path| method == "DELETE" }
errors << "protected mutations are missing: #{(expected_protected_mutations - protected_mutations).join(", ")}" unless (expected_protected_mutations - protected_mutations).empty?
errors << "protected mutations contain non-protected operations: #{(protected_mutations - expected_protected_mutations).join(", ")}" unless (protected_mutations - expected_protected_mutations).empty?
errors << "all DELETE operations must be protected" unless operations.select { |_id, method, _path| method == "DELETE" }.all? { |id, _method, _path| protected_mutations.include?(id) }
errors << "conditional protection predicates changed" unless protected_conditions == EXPECTED_PROTECTED_CONDITIONS
errors << "conditional protection keys must also be standard mutations" unless (protected_conditions.keys - standard_mutations).empty?
errors << "default profile must be read" unless policy["defaultProfile"] == "read"
errors << "admin scope must be single-explicit-task" unless policy["adminScope"] == "single-explicit-task"
errors << "admin profile must require explicit enablement" unless policy["adminRequiresExplicitEnablement"] == true
errors << "execution profiles must not combine by default" unless policy["combineExecutionProfilesByDefault"] == false
errors << "write classifications have duplicates: #{duplicates(classified_writes).join(", ")}" unless duplicates(classified_writes).empty?
errors << "non-GET operations are unclassified: #{(non_get_operations - classified_writes).join(", ")}" unless (non_get_operations - classified_writes).empty?
errors << "write classifications include GET or unknown operations: #{(classified_writes - non_get_operations).join(", ")}" unless (classified_writes - non_get_operations).empty?
errors << "capability groups must be arrays of operation IDs: #{invalid_capability_groups.keys.join(", ")}" unless invalid_capability_groups.empty?
errors << "capability group names or memberships changed" unless capability_digest(capabilities) == EXPECTED_CAPABILITY_DIGEST
errors << "capability groups contain duplicate assignments: #{duplicates(capability_operations).join(", ")}" unless duplicates(capability_operations).empty?
errors << "capability groups are missing: #{(operation_ids - capability_operations).join(", ")}" unless (operation_ids - capability_operations).empty?
errors << "capability groups have unknown operations: #{(capability_operations - operation_ids).join(", ")}" unless (capability_operations - operation_ids).empty?

unless errors.empty?
  warn errors.join("\n")
  exit 1
end

puts "API coverage OK: #{operation_ids.length} operations; #{read_profile.length} read and #{admin_profile.length} explicitly enabled admin operations"
