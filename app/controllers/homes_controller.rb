class HomesController < ApplicationController
  def index
    location = find_user
    @lat = location.latitude
    @lng = location.longitude

    sample_tweet = Tweet.first
    if sample_tweet.nil? || (!sample_tweet.nil? && ((sample_tweet.created_at + 3.minutes) < DateTime.now.utc))
      q = "geocode:39.5,-98.35,1500mi"
      tweets = CLIENT.search(q).take(50)
      if !tweets.nil?
        tweets.delete_if { |t| /(#|)(job|hiring|work)/i.match(t.text) }
        tweets.delete_if { |t| t.place.class == Twitter::NullObject }
        Tweet.destroy_all
        tweets.each do |tweet|
          Tweet.create(
            text: tweet.text,
            latitude: tweet.geo.coordinates[0],
            longitude: tweet.geo.coordinates[1]
          )
        end
      end
    end

    @tweets = Tweet.all

    raw = []
    @local_trends = []
    @tweets.each do |t|
      words = t.text.split
      words.each { |w| raw << w }
    end
    common_words = raw.select { |e| raw.count(e) > 2 && e.length > 3 }.uniq!
    if !common_words.nil?
      common_words.delete_if do |w|
        /(have|this|with|just|your|when|&amp;|from|that|-&gt;|were|much)/i.match(w)
      end
      @local_trends = common_words
    end

    sample_trend = Trend.first
    if sample_trend.nil? || (!sample_trend.nil? && ((sample_trend.created_at + 20.minutes) < DateTime.now.utc))

      trend_locations = []
      available_trends_response = api_get("https://api.twitter.com/1.1/trends/available.json")
      if available_trends_response.code == '200'
        available_trends_info = JSON.parse(available_trends_response.body)
        us_trends = available_trends_info.select { |i| i["countryCode"] == "US" }[0..5]
        us_trends.each do |trend|
          trend_locations << trend["woeid"]
        end
      end

      us_trend_markers = Hash.new { |h, k| h[k] = '' }
      trend_locations.each do |place|
        trend_location_response = api_get("https://api.twitter.com/1.1/trends/place.json?id=#{place}")
        if trend_location_response.code == '200'
          trend_location_info = JSON.parse(trend_location_response.body)
          trend_name = trend_location_info.first["trends"][0]["name"]
          us_trend_markers.store(trend_name, place)
          Trend.destroy_all
        end
      end

      us_trend_markers.each do |trend, place|
        location = HTTParty.get("http://where.yahooapis.com/v1/place/#{place}?format=json&appid=#{ENV["YAHOO"]}")
        lat = location["place"]["centroid"]["latitude"]
        lng = location["place"]["centroid"]["longitude"]
        Trend.create(name: trend, latitude: lat, longitude: lng)
      end
    end

    @remote_trends = Trend.all

    respond_to do |format|
      format.html
      format.json { render json: [@lat, @lng, @tweets, @remote_trends] }
    end
  end
end
