#!/usr/bin/env ruby

require "date"
require "json"
require "net/http"
require "openssl"
require "optparse"
require "timeout"
require "uri"

module ScarfAggregationExport
  API_ORIGIN = "https://api.scarf.sh"
  VALID_ROLLUPS = %w[total daily weekly monthly yearly].freeze
  VALID_BREAKDOWNS = %w[
    by-country by-cloudprovider by-company by-variable by-platform by-version
    by-total by-total-do-not-track by-client by-domain by-referer by-endpoint
    by-origin by-file-extension by-user-agent by-importance
    by-company-funnel-stage by-company-size by-company-sic-code
    by-educational-organization by-govermental-organization
  ].freeze
  COMPANY_BREAKDOWNS = %w[by-company-funnel-stage by-company-size by-company-sic-code].freeze
  UNRESERVED_BYTE = /[A-Za-z0-9._~-]/.freeze
  RAW_PATH_BYTE = /[A-Za-z0-9._~!$&'()*+,;=:@\/-]/.freeze

  class Error < StandardError; end

  module_function

  def default_window(now: Time.now.utc)
    end_date = now.utc.to_date + 1
    [end_date - 30, end_date]
  end

  def build_uri(owner:, rollup:, breakdowns:, start_date: nil, end_date: nil, now: Time.now.utc,
                package_ids: [], tracking_pixel_ids: [], query: nil, filter: nil,
                tracking_pixels_for_package_id: nil, company_reference: nil,
                group_by_artifact: nil, include_low_confidence: nil, format: "ndjson")
    raise Error, "owner is required" if owner.to_s.empty?
    raise Error, "explicit rollup is required" unless VALID_ROLLUPS.include?(rollup)
    unless breakdowns.is_a?(Array) && (1..2).cover?(breakdowns.length) && breakdowns.all? { |value| VALID_BREAKDOWNS.include?(value) }
      raise Error, "breakdown_set must contain one or two supported dimensions"
    end

    raise Error, "format must be ndjson or json" unless %w[ndjson json].include?(format)
    if (breakdowns & COMPANY_BREAKDOWNS).any? && (format != "json" || rollup != "total" || breakdowns.length != 1)
      raise Error, "company segment breakdowns require format=json, rollup=total, and one breakdown"
    end
    if query && !(package_ids.empty? && tracking_pixel_ids.empty?)
      raise Error, "query cannot be combined with package_id or tracking_pixel_id selectors"
    end
    if tracking_pixels_for_package_id && (query || !package_ids.empty?)
      raise Error, "tracking_pixels_for_package_id cannot be combined with query or package_id"
    end

    _default_start, default_end = default_window(now: now)
    end_date = end_date ? Date.iso8601(end_date.to_s) : default_end
    start_date = start_date ? Date.iso8601(start_date.to_s) : end_date - 30
    raise Error, "end_date must be after start_date" unless end_date > start_date
    raise Error, "date range must not exceed 366 days" if (end_date - start_date).to_i > 366

    path_owner = URI.encode_www_form_component(owner).gsub("+", "%20")
    uri = URI("#{API_ORIGIN}/v3/insights/#{path_owner}/aggregations/export")
    parameters = {
      start_date: start_date.iso8601,
      end_date: end_date.iso8601,
      rollup: rollup,
      breakdown_set: breakdowns.join(","),
      package_id: package_ids,
      tracking_pixel_id: tracking_pixel_ids,
      query: query,
      filter: filter,
      tracking_pixels_for_package_id: tracking_pixels_for_package_id,
      company_reference: company_reference,
      group_by_artifact: group_by_artifact,
      include_low_confidence: include_low_confidence,
      format: format
    }
    uri.query = URI.encode_www_form(parameters.reject { |_key, value| value.nil? || value == [] })
    uri
  rescue ArgumentError => error
    raise Error, "dates must use YYYY-MM-DD: #{error.message}"
  end

  def parse_ndjson(input, token: "")
    input.each_line.with_index(1).each_with_object([]) do |(line, number), rows|
      next if line.strip.empty?

      row = JSON.parse(line)
      raise Error, "invalid NDJSON on line #{number}: expected an object" unless row.is_a?(Hash)

      rows << row
    rescue JSON::ParserError => error
      detail = bounded_api_error(error.message, token: token)
      raise Error, "invalid NDJSON on line #{number}: #{detail}"
    end
  end

  def exact_path_rows(rows, requested_path)
    raise Error, "requested path must start with /" unless requested_path.start_with?("/")

    requested_path = canonical_path(requested_path)
    rows.select do |row|
      referer = row["referer"]
      next false unless referer.is_a?(String)

      parsed_path = URI.parse(referer).path
      next false if parsed_path.nil?

      canonical_path(parsed_path.empty? ? "/" : parsed_path) == requested_path
    rescue URI::InvalidURIError
      false
    end
  end

  def canonical_path(path)
    bytes = path.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "�").bytes
    canonical = +""
    index = 0

    while index < bytes.length
      if bytes[index] == 0x25 && index + 2 < bytes.length
        escape = bytes.slice(index + 1, 2).pack("C*")
        if escape.match?(/\A[0-9A-Fa-f]{2}\z/)
          decoded = escape.to_i(16)
          unreserved = decoded < 0x80 && decoded.chr.match?(UNRESERVED_BYTE)
          canonical << (unreserved ? decoded.chr : format("%%%02X", decoded))
          index += 3
          next
        end
      end

      byte = bytes[index]
      raw_path_byte = byte < 0x80 && byte.chr.match?(RAW_PATH_BYTE)
      canonical << (raw_path_byte ? byte.chr : format("%%%02X", byte))
      index += 1
    end

    canonical
  end

  def parse_json(input, token: "")
    envelope = JSON.parse(input)
    unless envelope.is_a?(Hash) && envelope["data"].is_a?(Array) && envelope["data"].all? { |row| row.is_a?(Hash) }
      raise Error, "invalid JSON aggregation response: expected a data array of objects"
    end
    envelope.fetch("data")
  rescue JSON::ParserError => error
    raise Error, "invalid JSON aggregation response: #{bounded_api_error(error.message, token: token)}"
  end

  def bounded_api_error(body, token:, limit: 500)
    message = body.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "�")
    message = message.gsub(token, "[REDACTED]") unless token.empty?
    message = message.gsub(/[\p{Cc}\p{Cf}]/, " ")
    message = message.gsub(/\s+/, " ").strip
    message.length > limit ? "#{message[0, limit]}…" : message
  end

  # The server reports the window it actually queried. Report those values
  # rather than the client-side prediction, which silently drifts if the
  # route's default window changes.
  def effective_scope(response)
    {
      "start_date" => response["X-Scarf-Effective-Start-Date"],
      "end_date" => response["X-Scarf-Effective-End-Date"]
    }.reject { |_key, value| value.nil? || value.to_s.empty? }
  end

  # Returns [rows, effective_scope].
  def fetch(uri, http: Net::HTTP)
    token = ENV["SCARF_API_TOKEN"]
    raise Error, "SCARF_API_TOKEN is not configured" if token.to_s.empty?

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{token}"
    response = http.start(uri.hostname, uri.port, use_ssl: true) { |client| client.request(request) }
    unless response.is_a?(Net::HTTPSuccess)
      detail = bounded_api_error(response.body, token: token)
      suffix = detail.empty? ? "" : ": #{detail}"
      raise Error, "Scarf API returned HTTP #{response.code}#{suffix}"
    end

    parameters = URI.decode_www_form(uri.query).to_h
    rows = if parameters.fetch("format", "ndjson") == "json"
             parse_json(response.body, token: token)
           else
             parse_ndjson(response.body, token: token)
           end
    [rows, effective_scope(response)]
  rescue Error
    raise
  rescue SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError, Net::ProtocolError
    raise Error, "Scarf API request failed"
  end

  def run(argv, stdout: $stdout, stderr: $stderr, now: Time.now.utc)
    options = { rollup: nil, breakdowns: [], package_ids: [], tracking_pixel_ids: [], format: "ndjson" }
    parser = OptionParser.new do |flags|
      flags.banner = "Usage: aggregation_export.rb --owner OWNER --rollup ROLLUP --breakdown DIM [--breakdown DIM] [--path PATH]"
      flags.on("--owner OWNER") { |value| options[:owner] = value }
      flags.on("--path PATH") { |value| options[:path] = value }
      flags.on("--start-date DATE") { |value| options[:start_date] = value }
      flags.on("--end-date DATE") { |value| options[:end_date] = value }
      flags.on("--rollup ROLLUP") { |value| options[:rollup] = value }
      flags.on("--breakdown DIM") { |value| options[:breakdowns] << value }
      flags.on("--package-id ID", "Repeatable UUID, all, or none") { |value| options[:package_ids] << value }
      flags.on("--tracking-pixel-id ID", "Repeatable UUID, all, or none") { |value| options[:tracking_pixel_ids] << value }
      flags.on("--query QUERY", "Artifact-name query; cannot be combined with UUID selectors") { |value| options[:query] = value }
      flags.on("--filter REF") { |value| options[:filter] = value }
      flags.on("--tracking-pixels-for-package-id ID") { |value| options[:tracking_pixels_for_package_id] = value }
      flags.on("--company-reference REF") { |value| options[:company_reference] = value }
      flags.on("--[no-]group-by-artifact") { |value| options[:group_by_artifact] = value }
      flags.on("--[no-]include-low-confidence") { |value| options[:include_low_confidence] = value }
      flags.on("--format FORMAT", "ndjson (default) or json") { |value| options[:format] = value }
    end
    parser.parse!(argv)
    raise Error, "unexpected positional arguments" unless argv.empty?
    requested_path = options.delete(:path)
    if requested_path && !requested_path.start_with?("/")
      raise Error, "requested path must start with /"
    end
    if requested_path && options[:breakdowns].include?("by-variable")
      raise Error, "path totals cannot include by-variable: an event can appear under multiple variables"
    end
    if requested_path && !options[:breakdowns].include?("by-referer")
      raise Error, "path filtering requires a by-referer breakdown"
    end

    uri = build_uri(**options, now: now)
    rows, effective_scope = fetch(uri)
    rows = exact_path_rows(rows, requested_path) if requested_path
    # Preserve repeated selectors in the request evidence.
    parameters = URI.decode_www_form(uri.query).each_with_object({}) do |(key, value), result|
      result[key] = result.key?(key) ? Array(result[key]) + [value] : value
    end
    result = { "endpoint" => uri.path, "query" => parameters, "rows" => rows }
    result["effective_window"] = effective_scope if effective_scope && !effective_scope.empty?
    if requested_path
      result.merge!(
        "requested_path" => requested_path,
        "metric" => "aggregate events (not unique visitors)",
        "total_events" => rows.sum { |row| Integer(row.fetch("total")) }
      )
    end
    stdout.puts JSON.pretty_generate(result)
    0
  rescue Error, OptionParser::ParseError, KeyError, ArgumentError => error
    stderr.puts "aggregation export failed: #{error.message}"
    1
  end
end

exit ScarfAggregationExport.run(ARGV) if $PROGRAM_NAME == __FILE__
