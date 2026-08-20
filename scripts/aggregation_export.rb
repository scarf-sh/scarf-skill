#!/usr/bin/env ruby

require "date"
require "json"
require "net/http"
require "optparse"
require "uri"

module ScarfAggregationExport
  API_ORIGIN = "https://api.scarf.sh"
  VALID_ROLLUPS = %w[daily weekly monthly yearly].freeze
  VALID_BREAKDOWNS = %w[
    by-country by-cloudprovider by-company by-variable by-platform by-version
    by-total by-total-do-not-track by-client by-domain by-referer by-endpoint
    by-origin by-file-extension by-educational-organization by-govermental-organization
  ].freeze
  ARTIFACT_FIELD = "artifact"

  class Error < StandardError; end

  module_function

  def default_window(now: Time.now.utc)
    end_date = now.utc.to_date + 1
    [end_date - 30, end_date]
  end

  def build_uri(owner:, rollup:, breakdowns:, start_date: nil, end_date: nil, now: Time.now.utc)
    raise Error, "owner is required" if owner.to_s.empty?
    raise Error, "explicit rollup is required" unless VALID_ROLLUPS.include?(rollup)
    unless breakdowns.is_a?(Array) && (1..2).cover?(breakdowns.length) && breakdowns.all? { |value| VALID_BREAKDOWNS.include?(value) }
      raise Error, "breakdown_set must contain one or two supported dimensions"
    end

    _default_start, default_end = default_window(now: now)
    end_date = end_date ? Date.iso8601(end_date.to_s) : default_end
    start_date = start_date ? Date.iso8601(start_date.to_s) : end_date - 30
    raise Error, "end_date must be after start_date" unless end_date > start_date
    raise Error, "date range must not exceed 366 days" if (end_date - start_date).to_i > 366

    path_owner = URI.encode_www_form_component(owner).gsub("+", "%20")
    uri = URI("#{API_ORIGIN}/v3/insights/#{path_owner}/aggregations/export")
    uri.query = URI.encode_www_form(
      start_date: start_date.iso8601,
      end_date: end_date.iso8601,
      rollup: rollup,
      breakdown_set: breakdowns.join(",")
    )
    uri
  rescue ArgumentError => error
    raise Error, "dates must use YYYY-MM-DD: #{error.message}"
  end

  def parse_ndjson(input)
    input.each_line.with_index(1).each_with_object([]) do |(line, number), rows|
      next if line.strip.empty?

      rows << JSON.parse(line)
    rescue JSON::ParserError => error
      raise Error, "invalid NDJSON on line #{number}: #{error.message}"
    end
  end

  def exact_path_rows(rows, requested_path)
    raise Error, "requested path must start with /" unless requested_path.start_with?("/")

    rows.select do |row|
      referer = row["referer"]
      next false unless referer.is_a?(String)

      URI.parse(referer).path == requested_path
    rescue URI::InvalidURIError
      false
    end
  end

  def deduplicate_cross_artifact(rows)
    rows.sort_by { |row| row.fetch(ARTIFACT_FIELD, "").to_s }.uniq do |row|
      row.reject { |key, _value| key == ARTIFACT_FIELD }
    end
  end

  def fetch(uri, http: Net::HTTP)
    token = ENV["SCARF_API_TOKEN"]
    raise Error, "SCARF_API_TOKEN is not configured" if token.to_s.empty?

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{token}"
    response = http.start(uri.hostname, uri.port, use_ssl: true) { |client| client.request(request) }
    raise Error, "Scarf API returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    parse_ndjson(response.body)
  end

  def run(argv, stdout: $stdout, stderr: $stderr, now: Time.now.utc)
    options = { rollup: nil, breakdowns: [] }
    parser = OptionParser.new do |flags|
      flags.banner = "Usage: aggregation_export.rb --owner OWNER --path PATH --rollup ROLLUP --breakdown DIM [--breakdown DIM]"
      flags.on("--owner OWNER") { |value| options[:owner] = value }
      flags.on("--path PATH") { |value| options[:path] = value }
      flags.on("--start-date DATE") { |value| options[:start_date] = value }
      flags.on("--end-date DATE") { |value| options[:end_date] = value }
      flags.on("--rollup ROLLUP") { |value| options[:rollup] = value }
      flags.on("--breakdown DIM") { |value| options[:breakdowns] << value }
    end
    parser.parse!(argv)
    raise Error, "path is required" if options[:path].to_s.empty?

    uri = build_uri(
      owner: options[:owner], rollup: options[:rollup], breakdowns: options[:breakdowns],
      start_date: options[:start_date], end_date: options[:end_date], now: now
    )
    rows = deduplicate_cross_artifact(exact_path_rows(fetch(uri), options[:path]))
    stdout.puts JSON.pretty_generate(
      "endpoint" => uri.path,
      "query" => URI.decode_www_form(uri.query).to_h,
      "requested_path" => options[:path],
      "cross_artifact_rule" => "exact rows differing only by artifact count once",
      "metric" => "aggregate events (not unique visitors)",
      "total_events" => rows.sum { |row| Integer(row.fetch("total")) },
      "rows" => rows
    )
    0
  rescue Error, OptionParser::ParseError, KeyError, ArgumentError => error
    stderr.puts "aggregation export failed: #{error.message}"
    1
  end
end

exit ScarfAggregationExport.run(ARGV) if $PROGRAM_NAME == __FILE__
