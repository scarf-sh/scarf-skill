#!/usr/bin/env ruby

require "json"
require "open-uri"
require "open3"
require "rbconfig"
require "tmpdir"
require "yaml"

ROOT = File.expand_path("..", __dir__)
CHECKER = File.join(__dir__, "check_api_coverage.rb")
MAP_PATH = File.join(ROOT, "references", "api-map.json")
INVENTORY_PATH = File.join(ROOT, "references", "api-v2-endpoint-inventory.md")
SPEC_URL = "https://api.scarf.sh/static/api-v2.yaml"

def deep_copy(value)
  Marshal.load(Marshal.dump(value))
end

def manifest_entry(map, operation_id)
  map.fetch("publicOperationManifest").find { |entry| entry.fetch("operationId") == operation_id }
end

def replace_inventory_id(inventory, old_id, new_id)
  inventory.each_line.map do |line|
    line.start_with?("| `#{old_id}` |") ? line.sub("| `#{old_id}` |", "| `#{new_id}` |") : line
  end.join
end

def swap_inventory_ids(inventory, first_id, second_id)
  inventory = replace_inventory_id(inventory, first_id, "__temporary_operation_id__")
  inventory = replace_inventory_id(inventory, second_id, first_id)
  replace_inventory_id(inventory, "__temporary_operation_id__", second_id)
end

def run_checker(map, spec, inventory)
  Dir.mktmpdir("scarf-api-coverage-test") do |directory|
    map_path = File.join(directory, "api-map.json")
    spec_path = File.join(directory, "api.yaml")
    inventory_path = File.join(directory, "inventory.md")
    File.write(map_path, JSON.pretty_generate(map))
    File.write(spec_path, YAML.dump(spec))
    File.write(inventory_path, inventory)
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, CHECKER, map_path, spec_path, inventory_path)
    [stdout + stderr, status.success?]
  end
end

base_map = JSON.parse(File.read(MAP_PATH))
base_spec = YAML.safe_load(URI.open(SPEC_URL, &:read), aliases: true)
base_inventory = File.read(INVENTORY_PATH)

baseline_output, baseline_success = run_checker(base_map, base_spec, base_inventory)
unless baseline_success
  warn "baseline coverage check failed:\n#{baseline_output}"
  exit 1
end

cases = [
  ["read-like route swap, including synchronized manifest and inventory", "read-like operations or routes changed", lambda do |map, spec, inventory|
    search = spec.fetch("paths").fetch("/v2/search").fetch("post")
    import = spec.fetch("paths").fetch("/v2/{owner}/import").fetch("post")
    search["operationId"], import["operationId"] = import.fetch("operationId"), search.fetch("operationId")
    search_manifest = manifest_entry(map, "search")
    import_manifest = manifest_entry(map, "importEvents")
    search_manifest["path"], import_manifest["path"] = import_manifest.fetch("path"), search_manifest.fetch("path")
    inventory = swap_inventory_ids(inventory, "search", "importEvents")
    inventory
  end],
  ["standard mutation method drift", "standard operations or routes changed", lambda do |map, spec, inventory|
    collection_path = spec.fetch("paths").fetch("/v2/collections/{owner}")
    collection_path["delete"] = collection_path.delete("post")
    manifest_entry(map, "createCollection")["method"] = "DELETE"
    inventory.sub("| `createCollection` | `POST` |", "| `createCollection` | `DELETE` |")
  end],
  ["new HEAD operation", "source count is", lambda do |_map, spec, inventory|
    spec.fetch("paths").fetch("/v2/search")["head"] = { "operationId" => "searchHead" }
    inventory
  end],
  ["new operation behind a path-item reference", "source count is", lambda do |_map, spec, inventory|
    spec["components"] ||= {}
    spec["components"]["pathItems"] ||= {}
    spec["components"]["pathItems"]["Synthetic"] = { "head" => { "operationId" => "syntheticHead" } }
    spec.fetch("paths")["/v2/synthetic"] = { "$ref" => "#/components/pathItems/Synthetic" }
    inventory
  end],
  ["external path-item reference", "unsupported external path-item reference", lambda do |_map, spec, inventory|
    spec.fetch("paths")["/v2/external"] = { "$ref" => "external.yaml#/paths/~1external" }
    inventory
  end],
  ["duplicate OpenAPI operation ID", "OpenAPI operation IDs have duplicates", lambda do |_map, spec, inventory|
    spec.fetch("paths").fetch("/v2/packages/{owner}/{package_id}").fetch("get")["operationId"] = "getPackages"
    inventory
  end],
  ["protected mutation reclassified as standard", "standard mutation IDs must be exactly", lambda do |map, _spec, inventory|
    policy = map.fetch("policy")
    policy.fetch("protectedMutations").delete("deletePackage")
    policy.fetch("standardMutations") << "deletePackage"
    inventory
  end],
  ["protected DELETE moved into read profile", "read-like operation IDs must be exactly", lambda do |map, _spec, inventory|
    policy = map.fetch("policy")
    policy.fetch("protectedMutations").delete("deletePackage")
    policy.fetch("readLikePost") << "deletePackage"
    map.dig("deploymentProfiles", "admin").delete("deletePackage")
    map.dig("deploymentProfiles", "read") << "deletePackage"
    inventory
  end],
  ["default profile escalation", "default profile must be read", lambda do |map, _spec, inventory|
    map.dig("policy", "defaultProfile").replace("admin")
    inventory
  end],
  ["session-wide admin scope", "admin scope must be single-explicit-task", lambda do |map, _spec, inventory|
    map.dig("policy", "adminScope").replace("session")
    inventory
  end],
  ["automatic profile combination", "deployment profiles must not combine by default", lambda do |map, _spec, inventory|
    map.fetch("policy")["combineDeploymentProfilesByDefault"] = true
    inventory
  end],
  ["admin operation added to the read profile", "deployment profiles overlap", lambda do |map, _spec, inventory|
    map.dig("deploymentProfiles", "read") << "deletePackage"
    inventory
  end],
  ["conditional predicate reversal", "conditional protection predicates changed", lambda do |map, _spec, inventory|
    map.dig("policy", "protectedConditions")["createInsightsFilter"] = "scope=adhoc"
    inventory
  end],
  ["capability reassignment", "capability group names or memberships changed", lambda do |map, _spec, inventory|
    map.dig("capabilities", "packages_and_gateway").delete("deletePackage")
    map.dig("capabilities", "insights_and_filters") << "deletePackage"
    inventory
  end],
  ["scalar capability group", "must be an array of non-empty strings", lambda do |map, _spec, inventory|
    map.fetch("capabilities")["discovery_and_ai"] = "search"
    inventory
  end],
  ["duplicate manifest entry", "manifest count is", lambda do |map, _spec, inventory|
    map.fetch("publicOperationManifest") << deep_copy(map.fetch("publicOperationManifest").first)
    inventory
  end],
  ["malformed manifest entry", "keys changed", lambda do |map, _spec, inventory|
    manifest_entry(map, "search").delete("path")
    inventory
  end],
  ["stale inventory total", "inventory declares 84, contains 83", lambda do |_map, _spec, inventory|
    inventory.sub("Total operations: 83", "Total operations: 84")
  end],
  ["stale inventory section count", "inventory section Collections declares 6, contains 5", lambda do |_map, _spec, inventory|
    inventory.sub("## Collections (5)", "## Collections (6)")
  end],
  ["policy schema drift", "policy keys changed", lambda do |map, _spec, inventory|
    map.fetch("policy")["retainAdminForSession"] = true
    inventory
  end],
  ["source URL drift", "source.url must remain", lambda do |map, _spec, inventory|
    map.dig("source", "url").replace("https://example.com/spec.yaml")
    inventory
  end]
]

failures = []
cases.each do |label, expected_message, mutation|
  map = deep_copy(base_map)
  spec = deep_copy(base_spec)
  inventory = base_inventory.dup
  inventory = mutation.call(map, spec, inventory)
  output, success = run_checker(map, spec, inventory)
  next if !success && output.include?(expected_message)

  failures << "#{label}: expected rejection containing #{expected_message.inspect}; got success=#{success}\n#{output}"
end

unless failures.empty?
  warn failures.join("\n\n")
  exit 1
end

puts "API coverage mutation tests OK: baseline plus #{cases.length} fail-closed scenarios"
