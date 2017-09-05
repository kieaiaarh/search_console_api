require 'google/apis/webmasters_v3'
require 'json'
require 'pry'
require 'active_support/all'
require 'aws-sdk'
require "ruby-progressbar"

class SearchConsole
  attr_accessor :webmaster, :request_object

  # as service_account
  CREDENTIAL_STORE_FILE = 'search_console.json'.freeze
  SCOPE = 'https://www.googleapis.com/auth/webmasters.readonly'.freeze
  SITE_URL = ''.freeze
  ROW_LIMIT = 5000
  START_ROW = 0

  def initialize
    webmaster.authorization = credentials.fetch_access_token!({})['access_token']
  end

  def request_object
    @request_object ||= {dimensions: dimentions, rowLimit: ROW_LIMIT, startrow: START_ROW, start_date: target_date, end_date: target_date, fields: 'query'}
  end

  def dimentions
    ['query']
  end

  def dimensions_with_pages
    default_dimentions.dup.unshift('page')
  end

  def target_date(index = 0)
    target = unless 0 < index.to_i
      first_date
    else
      first_date + index.days
    end
    return if target > latest_date
    target.strftime('%Y-%m-%d')
  end

  def latest_date
    @latest_date ||= current_date - 2.days
  end

  def query
    webmaster.query_search_analytics(SITE_URL, request_object, {}) { |result, err|
      raise StandardError if err
    }
  end

  def webmaster
    @webmaster ||= Google::Apis::WebmastersV3::WebmastersService.new
  end

  private

    def credentials
      @credentials ||= Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: IO.new(IO.sysopen(CREDENTIAL_STORE_FILE)), scope: SCOPE)
    end

    def current_date
      @current_date ||= Time.now.change(hour: 0, min: 0, sec: 0)
    end

    def first_date
      @first_date ||= current_date - 3.months
    end
end

if __FILE__ == $0
  search_console = SearchConsole.new
  webmaster = search_console.webmaster
  lines = []
  pb = ProgressBar.create
  (0..100).each do |i|
  # (0..3).each do |i|
    break if search_console.latest_date < search_console.target_date(i)

    pb.increment
    search_console.request_object[:start_date] = search_console.target_date(i)
    search_console.request_object[:end_date] = search_console.target_date(i)


    result = search_console.query

    daily_keywords_analytics = result&.rows.map{|row|
      {
        date: search_console.request_object[:start_date],
        clicks: row.clicks, ctr: row.ctr,
        impressions: row.impressions,
        keyword: row.keys.first,
        position: row.position
      }.to_json
    }

    open("./log/#{search_console.request_object[:start_date]}.json", 'w') do |io|
      JSON.dump(daily_keywords_analytics, io)
    end
    sleep 0.1
  end
  pb.finish
end
