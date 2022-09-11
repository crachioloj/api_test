require 'rest-client'
require 'json'

class Client

  # /artworks endpoint
  ARTWORKS_URL = "http://localhost:4567/artworks"
  ARTIST_URL = "http://localhost:4567/artist"

  # Constants
  ARTWORKS_LIMIT = 10
  PRIMARY_COLORS = ["red", "blue", "yellow"]

  # There isn't an easy way to get the total number of artworks or remaining pages
  # from the API, so this is hardcoded for now...
  ARTWORKS_MAX_PAGE = 50

  def retrieve(options = {})
    return unless options.respond_to?(:each)

    # Page number should be at least 1
    currentPage = options[:page].nil? ? 1 : [1, options[:page]].max

    artworks = get_artworks(options, currentPage)

    return unless artworks.respond_to?(:each)

    ids = artworks.map {|a| a["id"]}.uniq

    for_sale = get_artwork_for_sale(artworks)

    sold_primary_count = artworks
      .select { |a| a["availability"] == "sold" && PRIMARY_COLORS.include?(a["dominant_color"])}
      .count

    artist_ids = artworks.map {|a| a["artist_id"]}.uniq

    artist_names = artist_ids
      .map {|id| get_artist(id)}
      .select {|a| a.has_key?("name")} # ensure each item is valid and has name key
      .map {|a| a["name"]}
      .sort
    
    response = {}

    response[:ids] = ids
    response[:for_sale] = for_sale.sort { |a, b| a[:id] <=> b[:id]}
    response[:soldPrimaryCount] = sold_primary_count
    response[:artistNames] = artist_names
    response[:previousPage] = currentPage == 1 ? nil : currentPage - 1
    response[:nextPage] = artworks.empty? || currentPage >= ARTWORKS_MAX_PAGE ? nil : currentPage + 1

    response
  end

  private

  def get_artwork_for_sale(artworks)
    # Task description sounded like isPrimary should be on every for_sale item
    # and set to true or false accordingly,
    # but the test suite requires isPrimary only being on items where it is set to true
    # for_sale = artworks
    #   .select {|a| a["availability"] == "for_sale"}
    #   .map {|a| a.merge({"isPrimary" => PRIMARY_COLORS.include?(a["dominant_color"])})}
    #   .map { |a| a.transform_keys { |k| k.to_sym}}
    
    for_sale_primary = artworks
      .select {|a| a["availability"] == "for_sale" && PRIMARY_COLORS.include?(a["dominant_color"])}
      .map {|a| a.merge({"isPrimary" => true})}
      .map { |a| a.transform_keys { |k| k.to_sym}}

    for_sale_not_primary = artworks
      .select {|a| a["availability"] == "for_sale" && !PRIMARY_COLORS.include?(a["dominant_color"])}
      .map { |a| a.transform_keys { |k| k.to_sym}}

    for_sale = for_sale_primary + for_sale_not_primary
  end

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

  def get_artworks(options = {}, currentPage)
    offset = (currentPage - 1) * ARTWORKS_LIMIT

    params = {limit: ARTWORKS_LIMIT, offset: offset}

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