require 'rest-client'
require 'json'

class Client

  # /artworks endpoint
  ARTWORKS_URL = "http://localhost:4567/artworks"
  ARTIST_URL = "http://localhost:4567/artist"

  ARTWORKS_LIMIT = 10

  PRIMARY_COLORS = ["red", "blue", "yellow"]

  # Your retrieve function plus any additional functions go here ...
  def retrieve(options = {})
    response = {}

    artworks = get_artworks(options)

    # puts "----------"
    # puts artworks
    # puts "----------"

    return unless artworks.respond_to?(:each)

    ids = artworks.map {|a| a["id"]}.uniq

    for_sale = artworks
      .select {|a| a["availability"] == "for_sale"}
      .map {|a| a.merge({"isPrimary" => PRIMARY_COLORS.include?(a["dominant_color"])})}

    sold_primary_count = artworks
      .select { |a| a["availability"] == "sold" && PRIMARY_COLORS.include?(a["dominant_color"])}
      .count

    artist_ids = artworks.map {|a| a["artist_id"]}.uniq

    artist_names = artist_ids
      .map {|id| get_artist(id)}
      .select {|a| a.respond_to?(:each)}
      .map {|a| a["name"]}
      .sort

    response["ids"] = ids
    response["for_sale"] = for_sale
    response["artist_names"] = artist_names
    response["sold_primary_count"] = sold_primary_count
    response
  end

  private
  def get_artist(artist_id)
    begin
      response = RestClient.get ARTIST_URL, params: {id: artist_id}
      json = JSON.parse(response)
      if json.kind_of?(Array)
        json.first
      end
    rescue => error
      puts error
    end
  end

  def get_artworks(options = {})
    offset = options.key?(:page) ? options[:page] : 0

    params = {limit: ARTWORKS_LIMIT, offset: offset }

    if (options.key?(:dominant_color))
      params[:dominant_color]= options[:dominant_color]
    end

    begin
      response = RestClient.get ARTWORKS_URL, {params: params}
      artworks = JSON.parse(response)
    rescue => error
      puts error
    end
    
  end

end


client = Client.new
puts client.retrieve()

# result = client.retrieve({page: 15, dominant_color: ["red", "blue", "brown"]})
# puts result
# # result = client.retrieve({dominant_color: ["red"]})

# result = client.retrieve({page: 15 })
# puts result

# result2 = client.retrieve({ dominant_color: ["red", "blue", "brown"]})


# result = client.retrieve({page: 15 })

# thing = {}

# puts thing

# thing = { ids: [], for_sale: []}
# puts thing

# thing[:ids] = [1,2,3]

# puts thing

# thing[:asdf]= 1

# puts thing
