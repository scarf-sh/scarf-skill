#!/usr/bin/env ruby

require "minitest/autorun"
require "stringio"
require_relative "aggregation_export"

class AggregationExportTest < Minitest::Test
  FIXED_NOW = Time.utc(2026, 8, 20, 15, 30)

  def test_page_recipe_builds_v3_query_with_utc_defaults
    uri = ScarfAggregationExport.build_uri(
      owner: "example owner",
      rollup: "daily",
      breakdowns: %w[by-company by-referer],
      now: FIXED_NOW
    )
    query = URI.decode_www_form(uri.query).to_h

    assert_equal "/v3/insights/example%20owner/aggregations/export", uri.path
    assert_equal "2026-07-22", query.fetch("start_date")
    assert_equal "2026-08-21", query.fetch("end_date")
    assert_equal "daily", query.fetch("rollup")
    assert_equal "by-company,by-referer", query.fetch("breakdown_set")
  end

  def test_requires_explicit_rollup_and_one_or_two_breakdowns
    assert_raises(ScarfAggregationExport::Error) do
      ScarfAggregationExport.build_uri(owner: "acme", rollup: nil, breakdowns: ["by-company"])
    end
    assert_raises(ScarfAggregationExport::Error) do
      ScarfAggregationExport.build_uri(owner: "acme", rollup: "daily", breakdowns: [])
    end
    assert_raises(ScarfAggregationExport::Error) do
      ScarfAggregationExport.build_uri(
        owner: "acme", rollup: "daily", breakdowns: %w[by-company by-referer by-domain]
      )
    end
  end

  def test_omitted_start_date_is_relative_to_explicit_end_date
    uri = ScarfAggregationExport.build_uri(
      owner: "acme", rollup: "daily", breakdowns: ["by-company"],
      end_date: "2026-02-01", now: FIXED_NOW
    )

    assert_equal "2026-01-02", URI.decode_www_form(uri.query).to_h.fetch("start_date")
  end

  def test_parses_ndjson_and_matches_exact_uri_path_with_query_variants
    rows = ScarfAggregationExport.parse_ndjson(StringIO.new(<<~NDJSON))
      {"referer":"https://example.com/ai-leaderboard?utm_source=launch","total":3,"artifact":"b"}

      {"referer":"https://example.com/ai-leaderboard","total":3,"artifact":"a"}
      {"referer":"https://example.com/ai-leaderboard/detail","total":9,"artifact":"c"}
      {"referer":"not a uri %","total":7,"artifact":"d"}
    NDJSON

    assert_equal 2, ScarfAggregationExport.exact_path_rows(rows, "/ai-leaderboard").length
  end

  def test_root_path_matches_referer_without_trailing_slash
    rows = [{ "referer" => "https://example.com", "total" => 1 }]

    assert_equal rows, ScarfAggregationExport.exact_path_rows(rows, "/")
  end

  def test_path_filtering_requires_referer_breakdown
    stdout = StringIO.new
    stderr = StringIO.new

    status = ScarfAggregationExport.run(
      %w[--owner acme --path /pricing --rollup daily --breakdown by-company],
      stdout: stdout, stderr: stderr, now: FIXED_NOW
    )

    assert_equal 1, status
    assert_empty stdout.string
    assert_includes stderr.string, "path filtering requires a by-referer breakdown"
  end

  def test_cross_artifact_rule_collapses_only_exact_analytics_rows
    base = {
      "date" => "2026-08-20", "rollup" => "daily",
      "breakdowns" => %w[by-company by-referer], "company_domain" => "fund.example",
      "referer" => "https://example.com/ai-leaderboard", "total" => 3
    }
    rows = [base.merge("artifact" => "z"), base.merge("artifact" => "a"), base.merge("artifact" => "b", "total" => 4)]

    result = ScarfAggregationExport.deduplicate_cross_artifact(rows)

    assert_equal 2, result.length
    assert_equal %w[a b], result.map { |row| row.fetch("artifact") }
    assert_equal 7, result.sum { |row| row.fetch("total") }
  end

  def test_token_is_read_from_environment_and_never_written_or_placed_in_uri
    token = "secret-sentinel-token"
    uri = ScarfAggregationExport.build_uri(
      owner: "acme", rollup: "daily", breakdowns: ["by-company"], now: FIXED_NOW
    )
    response = Struct.new(:body, :code) do
      def is_a?(klass)
        klass == Net::HTTPSuccess
      end
    end.new("{\"total\":1}\n", "200")
    captured_request = nil
    client = Object.new
    client.define_singleton_method(:request) { |request| captured_request = request; response }
    transport = Object.new
    transport.define_singleton_method(:start) do |_host, _port, use_ssl:, &block|
      raise "TLS required" unless use_ssl
      block.call(client)
    end

    previous_token = ENV["SCARF_API_TOKEN"]
    ENV["SCARF_API_TOKEN"] = token
    stdout, stderr = capture_io do
      assert_equal [{ "total" => 1 }], ScarfAggregationExport.fetch(uri, http: transport)
    end
    ENV["SCARF_API_TOKEN"] = previous_token

    assert_equal "Bearer #{token}", captured_request["Authorization"]
    refute_includes uri.to_s, token
    refute_includes stdout, token
    refute_includes stderr, token
  ensure
    ENV["SCARF_API_TOKEN"] = previous_token
  end

  def test_api_error_details_are_bounded_and_token_is_redacted
    token = "secret-sentinel-token"
    uri = ScarfAggregationExport.build_uri(
      owner: "acme", rollup: "daily", breakdowns: ["by-referer"], now: FIXED_NOW
    )
    response = Struct.new(:body, :code) do
      def is_a?(_klass)
        false
      end
    end.new("invalid date for #{token} #{"x" * 600}", "400")
    client = Object.new
    client.define_singleton_method(:request) { |_request| response }
    transport = Object.new
    transport.define_singleton_method(:start) do |_host, _port, use_ssl:, &block|
      raise "TLS required" unless use_ssl
      block.call(client)
    end

    previous_token = ENV["SCARF_API_TOKEN"]
    ENV["SCARF_API_TOKEN"] = token
    error = assert_raises(ScarfAggregationExport::Error) do
      ScarfAggregationExport.fetch(uri, http: transport)
    end

    assert_includes error.message, "invalid date"
    assert_includes error.message, "[REDACTED]"
    refute_includes error.message, token
    assert_operator error.message.length, :<=, 550
  ensure
    ENV["SCARF_API_TOKEN"] = previous_token
  end

  def test_transport_failures_are_reported_as_sanitized_helper_errors
    uri = ScarfAggregationExport.build_uri(
      owner: "acme", rollup: "daily", breakdowns: ["by-referer"], now: FIXED_NOW
    )
    transport = Object.new
    transport.define_singleton_method(:start) do |_host, _port, use_ssl:|
      raise "TLS required" unless use_ssl
      raise SocketError, "host lookup included implementation details"
    end

    previous_token = ENV["SCARF_API_TOKEN"]
    ENV["SCARF_API_TOKEN"] = "secret-sentinel-token"
    error = assert_raises(ScarfAggregationExport::Error) do
      ScarfAggregationExport.fetch(uri, http: transport)
    end

    assert_equal "Scarf API request failed", error.message
  ensure
    ENV["SCARF_API_TOKEN"] = previous_token
  end
end
