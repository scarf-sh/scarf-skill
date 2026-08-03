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
README_PATH = File.join(ROOT, "README.md")
SPEC_URL = "https://api.scarf.sh/static/api-v2.yaml"

def copy(value)
  Marshal.load(Marshal.dump(value))
end

def swap_inventory_ids(inventory, first_id, second_id)
  lines = inventory.each_line.map do |line|
    if line.start_with?("| `#{first_id}` |")
      line.sub("| `#{first_id}` |", "| `__swap__` |")
    elsif line.start_with?("| `#{second_id}` |")
      line.sub("| `#{second_id}` |", "| `#{first_id}` |")
    else
      line
    end
  end.join
  lines.sub("| `__swap__` |", "| `#{second_id}` |")
end

def swap_inventory_rows(inventory, first_id, second_id)
  first = inventory.each_line.find { |line| line.start_with?("| `#{first_id}` |") }
  second = inventory.each_line.find { |line| line.start_with?("| `#{second_id}` |") }
  inventory.sub(first, "__SCARF_ROW_SWAP__\n").sub(second, first).sub("__SCARF_ROW_SWAP__\n", second)
end

def run_checker(map, spec, inventory, readme)
  Dir.mktmpdir("scarf-coverage-test") do |directory|
    map_path = File.join(directory, "map.json")
    spec_path = File.join(directory, "spec.yaml")
    inventory_path = File.join(directory, "inventory.md")
    readme_path = File.join(directory, "README.md")
    File.write(map_path, map.is_a?(String) ? map : JSON.pretty_generate(map))
    File.write(spec_path, spec.is_a?(String) ? spec : YAML.dump(spec))
    File.write(inventory_path, inventory)
    File.write(readme_path, readme)
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, CHECKER, map_path, spec_path, inventory_path, readme_path)
    [stdout + stderr, status.success?]
  end
end

base_map_text = File.read(MAP_PATH)
base_spec_text = URI.open(SPEC_URL, &:read)
base_map = JSON.parse(base_map_text)
base_spec = YAML.safe_load(base_spec_text, aliases: true)
base_inventory = File.read(INVENTORY_PATH)
base_readme = File.read(README_PATH)
baseline_output, baseline_success = run_checker(base_map_text, base_spec_text, base_inventory, base_readme)
abort "baseline coverage check failed:\n#{baseline_output}" unless baseline_success

cases = [
  ["synchronized read-like route swap", "read-like operations or routes changed", lambda do |_map, spec, inventory|
    search = spec.dig("paths", "/v2/search", "post")
    import = spec.dig("paths", "/v2/{owner}/import", "post")
    search["operationId"], import["operationId"] = import["operationId"], search["operationId"]
    swap_inventory_ids(inventory, "search", "importEvents")
  end],
  ["standard mutation method drift", "standard operations or routes changed", lambda do |_map, spec, inventory|
    collection = spec.dig("paths", "/v2/collections/{owner}")
    collection["delete"] = collection.delete("post")
    inventory.sub("| `createCollection` | `POST` |", "| `createCollection` | `DELETE` |")
  end],
  ["new HEAD operation", "source count is", lambda do |_map, spec, inventory|
    spec.dig("paths", "/v2/search")["head"] = { "operationId" => "searchHead" }
    inventory
  end],
  ["OpenAPI version drift", "OpenAPI version changed", lambda do |_map, spec, inventory|
    spec["openapi"] = "3.1.0"
    inventory
  end],
  ["referenced new operation", "source count is", lambda do |_map, spec, inventory|
    spec["components"] ||= {}
    spec["components"]["pathItems"] = { "Synthetic" => { "head" => { "operationId" => "syntheticHead" } } }
    spec["paths"]["/v2/synthetic"] = { "$ref" => "#/components/pathItems/Synthetic" }
    inventory
  end],
  ["referenced path-item method conflict", "conflicting path-item reference siblings", lambda do |_map, spec, inventory|
    spec["components"] ||= {}
    spec["components"]["pathItems"] = { "Conflict" => { "get" => { "operationId" => "targetGet" } } }
    spec["paths"]["/v2/conflict"] = {
      "$ref" => "#/components/pathItems/Conflict",
      "get" => { "operationId" => "siblingGet" }
    }
    inventory
  end],
  ["referenced path-item parameter conflict", "conflicting path-item reference siblings", lambda do |_map, spec, inventory|
    spec["components"] ||= {}
    spec["components"]["pathItems"] = { "Conflict" => { "parameters" => [] } }
    spec["paths"]["/v2/conflict"] = { "$ref" => "#/components/pathItems/Conflict", "parameters" => [] }
    inventory
  end],
  ["external path-item reference", "unsupported external path-item reference", lambda do |_map, spec, inventory|
    spec["paths"]["/v2/external"] = { "$ref" => "external.yaml#/paths/~1external" }
    inventory
  end],
  ["duplicate OpenAPI operation ID", "OpenAPI operation IDs have duplicates", lambda do |_map, spec, inventory|
    spec.dig("paths", "/v2/packages/{owner}/{package_id}", "get")["operationId"] = "getPackages"
    inventory
  end],
  ["protected mutation reclassified as standard", "standard mutation IDs changed", lambda do |map, _spec, inventory|
    map.dig("policy", "protectedMutations").delete("deletePackage")
    map.dig("policy", "standardMutations") << "deletePackage"
    inventory
  end],
  ["protected DELETE moved to read", "read-like operation IDs changed", lambda do |map, _spec, inventory|
    map.dig("policy", "protectedMutations").delete("deletePackage")
    map.dig("policy", "readLikePost") << "deletePackage"
    map.dig("executionProfiles", "admin").delete("deletePackage")
    map.dig("executionProfiles", "read") << "deletePackage"
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
  ["automatic profile combination", "execution profiles must not combine by default", lambda do |map, _spec, inventory|
    map["policy"]["combineExecutionProfilesByDefault"] = true
    inventory
  end],
  ["undeclared superadmin profile", "execution profile keys changed", lambda do |map, _spec, inventory|
    map["executionProfiles"]["superadmin"] = copy(map.dig("executionProfiles", "admin"))
    inventory
  end],
  ["admin operation added to read", "execution profiles overlap", lambda do |map, _spec, inventory|
    map.dig("executionProfiles", "read") << "deletePackage"
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
  ["scalar capability group", "capability groups must be arrays", lambda do |map, _spec, inventory|
    map["capabilities"]["discovery_and_ai"] = "search"
    inventory
  end],
  ["duplicate manifest entry", "manifest has duplicate operation IDs", lambda do |map, _spec, inventory|
    map["publicOperationManifest"] << map["publicOperationManifest"].first
    inventory
  end],
  ["malformed manifest entry", "comparison of", lambda do |map, _spec, inventory|
    map["publicOperationManifest"][0] = 123
    inventory
  end],
  ["stale inventory total", "inventory declares 84, contains 83", lambda do |_map, _spec, inventory|
    inventory.sub("Total operations: 83", "Total operations: 84")
  end],
  ["offsetting inventory section drift", "inventory section Collections declares 6, contains 5", lambda do |_map, _spec, inventory|
    inventory.sub("## Collections (5)", "## Collections (6)").sub("## Company (5)", "## Company (4)")
  end],
  ["missing inventory section declarations", "inventory section names changed", lambda do |_map, _spec, inventory|
    inventory.gsub(/^(## .+) \(\d+\)$/, '\\1')
  end],
  ["incomplete inventory section declarations", "inventory section names changed", lambda do |_map, _spec, inventory|
    inventory.sub("## Collections (5)", "## Collections")
  end],
  ["inventory section membership drift", "inventory section membership changed", lambda do |_map, _spec, inventory|
    swap_inventory_rows(inventory, "getCollections", "exportCompanyRollup")
  end],
  ["policy schema drift", "policy keys changed", lambda do |map, _spec, inventory|
    map["policy"]["retainAdminForSession"] = true
    inventory
  end],
  ["unexpected transport configuration", "top-level API map keys changed", lambda do |map, _spec, inventory|
    map["transportProfiles"] = copy(map["executionProfiles"])
    inventory
  end],
  ["map version drift", "API map version changed", lambda do |map, _spec, inventory|
    map["version"] = "v3-public-api"
    inventory
  end],
  ["source schema drift", "source keys changed", lambda do |map, _spec, inventory|
    map["source"]["legacyUrl"] = "https://example.com/legacy.yaml"
    inventory
  end],
  ["source snapshot drift", "source snapshot date changed", lambda do |map, _spec, inventory|
    map["source"]["asOf"] = "2099-01-01"
    inventory
  end],
  ["inventory snapshot drift", "inventory snapshot date does not match source", lambda do |_map, _spec, inventory|
    inventory.sub("Snapshot checked on 2026-08-02", "Snapshot checked on 2099-01-01")
  end],
  ["duplicate inventory snapshot", "inventory must contain exactly one snapshot date", lambda do |_map, _spec, inventory|
    "#{inventory}\n- Snapshot checked on 2099-01-01.\n"
  end],
  ["policy parameter rename", "request schemas changed", lambda do |_map, spec, inventory|
    spec.dig("components", "parameters", "insights_filter_scope")["name"] = "visibility"
    inventory
  end],
  ["policy parameter schema drift", "request schemas changed", lambda do |_map, spec, inventory|
    spec.dig("components", "schemas", "FilterScope")["default"] = "global"
    inventory
  end],
  ["referenced request-body drift", "request schemas changed", lambda do |_map, spec, inventory|
    spec.dig("components", "schemas", "CreateCollection", "required").delete("pattern")
    inventory
  end],
  ["Dependency Radar parameter drift", "request schemas changed", lambda do |_map, spec, inventory|
    spec.dig("paths", "/v2/organizations/{organization_name}/download-feed", "get", "parameters").find { |parameter| parameter["name"] == "domain" }["name"] = "hostname"
    inventory
  end],
  ["pagination parameter drift", "request schemas changed", lambda do |_map, spec, inventory|
    spec.dig("components", "parameters", "per_page", "schema")["maximum"] = 10
    inventory
  end],
  ["annotation-named request property drift", "request schemas changed", lambda do |_map, spec, inventory|
    spec.dig("components", "schemas", "UpdateOrganization", "properties", "description")["maxLength"] = 1
    inventory
  end],
  ["source URL drift", "source URL changed", lambda do |map, _spec, inventory|
    map.dig("source", "url").replace("https://example.com/spec.yaml")
    inventory
  end],
  ["public API server drift", "public API server changed", lambda do |_map, spec, inventory|
    spec.fetch("servers").first["url"] = "https://example.com"
    inventory
  end],
  ["path-level server override", "path-level server overrides are not allowed", lambda do |_map, spec, inventory|
    spec.dig("paths", "/v2/search")["servers"] = [{ "url" => "https://example.com" }]
    inventory
  end],
  ["operation-level server override", "operation-level server overrides are not allowed", lambda do |_map, spec, inventory|
    spec.dig("paths", "/v2/search", "post")["servers"] = [{ "url" => "https://example.com" }]
    inventory
  end],
  ["authentication description drift", "API authentication description changed", lambda do |_map, spec, inventory|
    spec.dig("info")["description"] = spec.dig("info", "description").sub("Bearer", "Basic")
    inventory
  end],
  ["security scheme drift", "API security schemes changed", lambda do |_map, spec, inventory|
    spec.dig("components", "securitySchemes", "ApiToken")["scheme"] = "basic"
    inventory
  end],
  ["global security requirement drift", "global security requirements changed", lambda do |_map, spec, inventory|
    spec["security"] = [{ "ApiToken" => [] }]
    inventory
  end],
  ["operation security override", "operation security requirements changed", lambda do |_map, spec, inventory|
    spec.dig("paths", "/v2/search", "post")["security"] = []
    inventory
  end],
  ["undefined referenced operation security scheme", "undefined security schemes referenced: OtherToken", lambda do |_map, spec, inventory|
    spec.dig("paths", "/v3/organizations/{owner}/ai/chat", "post", "security").first["OtherToken"] =
      spec.dig("paths", "/v3/organizations/{owner}/ai/chat", "post", "security").first.delete("ScarfBearer")
    inventory
  end],
  ["duplicate alias and declared security requirement", "duplicate normalized requirement ApiToken", lambda do |_map, spec, inventory|
    spec.dig("paths", "/v3/organizations/{owner}/ai/chat", "post", "security").first["ApiToken"] = []
    inventory
  end]
]

failures = []
cases.each do |label, expected, mutation|
  map = copy(base_map)
  spec = copy(base_spec)
  inventory = mutation.call(map, spec, base_inventory.dup)
  output, success = run_checker(map, spec, inventory, base_readme)
  failures << "#{label}: expected #{expected.inspect}; success=#{success}\n#{output}" unless !success && output.include?(expected)
end

raw_cases = [
  [
    "duplicate top-level API map key",
    "duplicate JSON key: executionProfiles",
    base_map_text.sub(
      "  \"executionProfiles\": {",
      "  \"executionProfiles\": {},\n  \"executionProfiles\": {"
    ),
    base_spec_text
  ],
  [
    "duplicate nested API map key",
    "duplicate JSON key: defaultProfile",
    base_map_text.sub(
      "    \"defaultProfile\": \"read\",",
      "    \"defaultProfile\": \"admin\",\n    \"defaultProfile\": \"read\","
    ),
    base_spec_text
  ],
  [
    "duplicate OpenAPI YAML key",
    "duplicate YAML key:",
    base_map_text,
    base_spec_text.sub(
      "      operationId: listInsightsFilters",
      "      operationId: shadowListInsightsFilters\n      operationId: listInsightsFilters"
    )
  ],
  [
    "ambiguous OpenAPI YAML merge key",
    "YAML merge keys are not allowed:",
    base_map_text,
    base_spec_text
      .sub(
        "openapi: 3.0.3",
        "openapi: 3.0.3\nx-shared-operation: &shared_operation\n  operationId: shadowListInsightsFilters"
      )
      .sub(
        "      operationId: listInsightsFilters",
        "      <<: *shared_operation\n      operationId: listInsightsFilters"
      )
  ],
  [
    "multiple OpenAPI YAML documents",
    "OpenAPI YAML must contain exactly one document",
    base_map_text,
    "#{base_spec_text}\n---\nopenapi: 3.1.0\npaths: {}\n"
  ]
]

raw_cases.each do |label, expected, map, spec|
  output, success = run_checker(map, spec, base_inventory, base_readme)
  failures << "#{label}: expected #{expected.inspect}; success=#{success}\n#{output}" unless !success && output.include?(expected)
end

readme_output, readme_success = run_checker(
  base_map_text,
  base_spec_text,
  base_inventory,
  base_readme.sub("as of 2026-08-02", "as of 2099-01-01")
)
unless !readme_success && readme_output.include?("README snapshot date does not match source")
  failures << "README snapshot drift: expected README snapshot mismatch; success=#{readme_success}\n#{readme_output}"
end

duplicate_readme_output, duplicate_readme_success = run_checker(
  base_map_text,
  base_spec_text,
  base_inventory,
  "#{base_readme}\nThe current capability map covers all 83 operations in the published API as of 2099-01-01.\n"
)
unless !duplicate_readme_success && duplicate_readme_output.include?("README must contain exactly one snapshot date")
  failures << "duplicate README snapshot: expected duplicate snapshot rejection; success=#{duplicate_readme_success}\n#{duplicate_readme_output}"
end

abort failures.join("\n\n") unless failures.empty?
puts "API coverage mutation tests OK: baseline plus #{cases.length + raw_cases.length + 2} fail-closed scenarios"
