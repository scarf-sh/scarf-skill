#!/usr/bin/env ruby

require "minitest/autorun"
require "minitest/mock"
require "stringio"
require_relative "aggregation_export"

class AggregationExportTest < Minitest::Test
  FIXED_NOW = Time.utc(2026, 8, 20, 15, 30)

  def test_aggregation_helper_is_executable
    assert File.executable?(File.expand_path("aggregation_export.rb", __dir__))
  end

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

  def test_rejects_non_object_ndjson_rows
    ["null\n", "[]\n", "\"row\"\n"].each do |input|
      error = assert_raises(ScarfAggregationExport::Error) do
        ScarfAggregationExport.parse_ndjson(StringIO.new(input))
      end

      assert_includes error.message, "expected an object"
    end
  end

  def test_root_path_matches_referer_without_trailing_slash
    rows = [{ "referer" => "https://example.com", "total" => 1 }]

    assert_equal rows, ScarfAggregationExport.exact_path_rows(rows, "/")
  end

  def test_path_matching_normalizes_percent_encoding_without_decoding_separators
    cafe = { "referer" => "https://example.com/caf%C3%A9", "total" => 1 }
    tilde = { "referer" => "https://example.com/%7Euser", "total" => 1 }
    spaced = { "referer" => "https://example.com/research%20reports", "total" => 1 }
    encoded_separator = { "referer" => "https://example.com/a%2fb", "total" => 1 }

    assert_equal [cafe], ScarfAggregationExport.exact_path_rows([cafe], "/café")
    assert_equal [tilde], ScarfAggregationExport.exact_path_rows([tilde], "/~user")
    assert_equal [spaced], ScarfAggregationExport.exact_path_rows([spaced], "/research reports")
    assert_equal [encoded_separator], ScarfAggregationExport.exact_path_rows([encoded_separator], "/a%2Fb")
    assert_empty ScarfAggregationExport.exact_path_rows([encoded_separator], "/a/b")
  end

  def test_path_matching_skips_opaque_referers_without_a_path
    rows = [
      { "referer" => "mailto:user@example.com", "total" => 1 },
      { "referer" => "https://example.com/pricing", "total" => 2 }
    ]

    assert_equal [rows.last], ScarfAggregationExport.exact_path_rows(rows, "/pricing")
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

  def test_rejects_unconsumed_positional_arguments
    stdout = StringIO.new
    stderr = StringIO.new

    status = ScarfAggregationExport.run(
      %w[--owner acme --path /pricing --rollup daily --breakdown by-referer by-company],
      stdout: stdout, stderr: stderr, now: FIXED_NOW
    )

    assert_equal 1, status
    assert_empty stdout.string
    assert_includes stderr.string, "unexpected positional arguments"
  end

  def test_page_totals_preserve_equal_rows_from_distinct_artifacts
    base = {
      "date" => "2026-08-20", "rollup" => "daily",
      "company_domain" => "fund.example", "referer" => "https://example.com/pricing", "total" => 3,
      "artifact_type" => "tracking-pixel", "unique_origins" => 2
    }
    # Equal aggregate values do not establish event identity. Modern rows also
    # include artifact names; neither those nor IDs are deduplication keys.
    rows = [base.merge("artifact" => "a", "artifact_name" => "first"),
            base.merge("artifact" => "b", "artifact_name" => "second"),
            base.merge("artifact" => "c", "artifact_name" => "third", "total" => 4)]
    stdout = StringIO.new
    ScarfAggregationExport.stub(:fetch, [rows, {}]) do
      status = ScarfAggregationExport.run(
        %w[--owner acme --path /pricing --rollup daily --breakdown by-company --breakdown by-referer --no-group-by-artifact],
        stdout: stdout, now: FIXED_NOW
      )
      assert_equal 0, status
    end
    result = JSON.parse(stdout.string)
    assert_equal 10, result.fetch("total_events")
    assert_equal rows, result.fetch("rows")
    assert_equal "false", result.fetch("query").fetch("group_by_artifact")
    refute result.key?("cross_artifact_rule")
    refute result.key?("unique_origins")
  end

  def test_invalid_or_nonadditive_path_queries_fail_before_fetching
    [
      %w[--path pricing --breakdown by-referer],
      %w[--path /pricing --breakdown by-referer --breakdown by-variable]
    ].each do |arguments|
      stdout, stderr = StringIO.new, StringIO.new
      ScarfAggregationExport.stub(:fetch, ->(_uri) { flunk "invalid query must not make an API request" }) do
        assert_equal 1, ScarfAggregationExport.run(
          %w[--owner acme --rollup daily] + arguments,
          stdout: stdout, stderr: stderr, now: FIXED_NOW
        )
      end
      assert_empty stdout.string
      refute_empty stderr.string
    end
  end

  def test_general_queries_preserve_repeated_selectors_and_do_not_invent_a_summary
    stdout = StringIO.new
    received_uri = nil
    rows = [{ "total" => 20, "unique_origins" => 7, "artifact_type" => "package" }]
    fetch = lambda do |uri|
      received_uri = uri
      [rows, { "start_date" => "2026-08-01", "end_date" => "2026-09-01" }]
    end
    ScarfAggregationExport.stub(:fetch, fetch) do
      assert_equal 0, ScarfAggregationExport.run(
        %w[--owner acme --rollup total --breakdown by-total --format json
           --package-id pkg-one --package-id pkg-two --tracking-pixel-id pixel-one
           --filter saved-filter --no-group-by-artifact --no-include-low-confidence
           --company-reference example.com --start-date 2026-08-01 --end-date 2026-09-01],
        stdout: stdout, now: FIXED_NOW
      )
    end
    wire = URI.decode_www_form(received_uri.query)
    assert_equal %w[pkg-one pkg-two], wire.select { |key, _| key == "package_id" }.map(&:last)
    assert_includes wire, ["tracking_pixel_id", "pixel-one"]
    assert_includes wire, ["filter", "saved-filter"]
    assert_includes wire, ["format", "json"]
    assert_includes wire, ["rollup", "total"]
    assert_includes wire, ["include_low_confidence", "false"]
    assert_includes wire, ["company_reference", "example.com"]
    assert_includes wire, ["end_date", "2026-09-01"]
    refute wire.any? { |key, _| key == "_ui" || key == "group_by_artifact_type" }
    result = JSON.parse(stdout.string)
    assert_equal %w[pkg-one pkg-two], result.fetch("query").fetch("package_id")
    assert_equal rows, result.fetch("rows")
    refute result.key?("total_events")
    assert_equal({ "start_date" => "2026-08-01", "end_date" => "2026-09-01" }, result.fetch("effective_window"))
  end

  def test_selector_combinations_the_server_rejects_fail_before_fetching
    [
      { query: "proj/*", package_ids: ["pkg-one"] },
      { query: "proj/*", tracking_pixel_ids: ["all"] },
      { tracking_pixels_for_package_id: "pkg-one", query: "proj/*" },
      { tracking_pixels_for_package_id: "pkg-one", package_ids: ["pkg-two"] }
    ].each do |options|
      assert_raises(ScarfAggregationExport::Error) do
        ScarfAggregationExport.build_uri(owner: "acme", rollup: "total", breakdowns: ["by-total"], **options)
      end
    end
  end

  def test_artifact_name_queries_and_attached_pixel_selectors
    uri = ScarfAggregationExport.build_uri(owner: "acme", rollup: "total", breakdowns: ["by-total"], query: "project/*")
    assert_equal "project/*", URI.decode_www_form(uri.query).to_h.fetch("query")
    uri = ScarfAggregationExport.build_uri(owner: "acme", rollup: "daily", breakdowns: ["by-total"],
                                           tracking_pixels_for_package_id: "pkg-one", tracking_pixel_ids: ["all"])
    assert_equal "pkg-one", URI.decode_www_form(uri.query).to_h.fetch("tracking_pixels_for_package_id")
    assert_equal "all", URI.decode_www_form(uri.query).to_h.fetch("tracking_pixel_id")
  end

  def test_new_event_dimensions_and_company_segment_contract
    %w[by-user-agent by-importance].each do |dimension|
      uri = ScarfAggregationExport.build_uri(owner: "acme", rollup: "total", breakdowns: [dimension])
      assert_equal dimension, URI.decode_www_form(uri.query).to_h.fetch("breakdown_set")
    end
    %w[by-company-funnel-stage by-company-size by-company-sic-code].each do |dimension|
      uri = ScarfAggregationExport.build_uri(owner: "acme", rollup: "total", breakdowns: [dimension], format: "json")
      assert_equal dimension, URI.decode_www_form(uri.query).to_h.fetch("breakdown_set")
      [{ rollup: "daily", format: "json" }, { rollup: "total", format: "ndjson" }].each do |options|
        assert_raises(ScarfAggregationExport::Error) do
          ScarfAggregationExport.build_uri(owner: "acme", breakdowns: [dimension], **options)
        end
      end
    end
    assert_raises(ScarfAggregationExport::Error) do
      ScarfAggregationExport.build_uri(owner: "acme", rollup: "total", breakdowns: %w[by-company-size by-country], format: "json")
    end
  end

  def test_json_envelope_and_malformed_responses
    assert_equal [{ "total" => 4 }], ScarfAggregationExport.parse_json('{"data":[{"total":4}]}')
    assert_equal [], ScarfAggregationExport.parse_json('{"data":[]}')
    %w[null [] {}].concat(['{"data":null}', '{"data":[null]}']).each do |body|
      assert_raises(ScarfAggregationExport::Error) { ScarfAggregationExport.parse_json(body) }
    end
    error = assert_raises(ScarfAggregationExport::Error) do
      ScarfAggregationExport.parse_json('secret-sentinel-token {', token: 'secret-sentinel-token')
    end
    refute_includes error.message, 'secret-sentinel-token'
  end

  # Returns the rows; the reported window is left in @effective_scope.
  def fetch_response(body, headers: {}, **options)
    uri = ScarfAggregationExport.build_uri(owner: "acme", rollup: "total", breakdowns: ["by-total"], **options)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:body) { body }
    headers.each { |name, value| response[name] = value }
    client = Object.new
    client.define_singleton_method(:request) { |_request| response }
    transport = Object.new
    transport.define_singleton_method(:start) { |_host, _port, use_ssl:, &block| block.call(client) }
    previous = ENV["SCARF_API_TOKEN"]
    ENV["SCARF_API_TOKEN"] = "test-token"
    rows, @effective_scope = ScarfAggregationExport.fetch(uri, http: transport)
    rows
  ensure
    ENV["SCARF_API_TOKEN"] = previous
  end

  def test_fetch_reports_the_server_window_and_omits_absent_headers
    fetch_response('{"data":[]}', format: "json")
    assert_empty @effective_scope
    fetch_response(
      '{"data":[]}', format: "json",
      headers: { "X-Scarf-Effective-Start-Date" => "2026-07-31", "X-Scarf-Effective-End-Date" => "2026-08-30" }
    )
    assert_equal({ "start_date" => "2026-07-31", "end_date" => "2026-08-30" }, @effective_scope)
  end

  def test_fetch_parses_the_requested_response_format
    assert_equal [{ "total" => 4 }], fetch_response('{"data":[{"total":4}]}', format: "json")
    assert_equal [{ "total" => 4 }], fetch_response("{\"total\":4}\n", format: "ndjson")
  end

  def test_cross_type_grouping_is_not_offered_while_it_is_unpublished
    assert_raises(ArgumentError) do
      ScarfAggregationExport.build_uri(
        owner: "acme", rollup: "total", breakdowns: ["by-total"], group_by_artifact_type: false
      )
    end
    uri = ScarfAggregationExport.build_uri(
      owner: "acme", rollup: "total", breakdowns: ["by-total"], group_by_artifact: false
    )
    refute URI.decode_www_form(uri.query).any? { |key, _| key == "group_by_artifact_type" }
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

      def [](_name)
        nil
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
      assert_equal [[{ "total" => 1 }], {}], ScarfAggregationExport.fetch(uri, http: transport)
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

  def test_api_error_details_strip_terminal_control_characters
    detail = ScarfAggregationExport.bounded_api_error(
      "invalid\e[31m red\a\nnext\u202Espoof", token: ""
    )

    assert_equal "invalid [31m red next spoof", detail
    refute_match(/[\p{Cc}\p{Cf}]/, detail)
  end

  def test_malformed_ndjson_errors_are_bounded_sanitized_and_token_redacted
    token = "secret-sentinel-token"
    uri = ScarfAggregationExport.build_uri(
      owner: "acme", rollup: "daily", breakdowns: ["by-referer"], now: FIXED_NOW
    )
    response = Struct.new(:body, :code) do
      def is_a?(klass)
        klass == Net::HTTPSuccess
      end
    end.new("{\"error\":\"#{token}\e[31m\"\n", "200")
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

    assert_includes error.message, "invalid NDJSON"
    assert_includes error.message, "[REDACTED]"
    refute_includes error.message, token
    refute_match(/[\p{Cc}\p{Cf}]/, error.message)
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
