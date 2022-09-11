require 'rest-client'
require 'json'

# Client for interacting with 'artworks' and 'artist' APIs
class Client
  ARTWORKS_URL = 'http://localhost:4567/artworks'.freeze
  ARTIST_URL = 'http://localhost:4567/artist'.freeze
  
  ARTWORKS_LIMIT = 10
  PRIMARY_COLORS = %w[red blue yellow].freeze

  KEY_ARTIST_ID = 'artist_id'.freeze
  KEY_AVAILABILITY = 'availability'.freeze
  KEY_DOMINANT_COLOR = 'dominant_color'.freeze
  KEY_NAME = 'name'.freeze

  STATE_FOR_SALE = 'for_sale'.freeze
  STATE_SOLD = 'sold'.freeze

  # 'Artworks' API doesn't expose a way to get the total items or remaining pages
  # that match the query, so this is hardcoded for now...
  ARTWORKS_MAX_PAGE = 50

  def retrieve(options = {})
    return unless options.respond_to?(:each)

    current_page = get_current_page(options)

    artworks = get_artworks(options, current_page)

    return unless artworks.respond_to?(:each)

    build_response(artworks, current_page)
  end

  private

  def build_response(artworks, current_page)
    response = {}
    response[:ids] = get_artwork_ids(artworks)
    response[:for_sale] = get_artwork_for_sale(artworks)
    response[:soldPrimaryCount] = get_sold_primary_count(artworks)
    response[:artistNames] = get_artist_names(artworks)
    response[:previousPage] = get_previous_page(current_page)
    response[:nextPage] = get_next_page(artworks, current_page)
    response
  end

  def get_current_page(options)
    options[:page].nil? ? 1 : [1, options[:page]].max
  end

  def get_previous_page(current_page)
    current_page == 1 ? nil : current_page - 1
  end

  def get_next_page(artworks, current_page)
    artworks.empty? || current_page >= ARTWORKS_MAX_PAGE ? nil : current_page + 1
  end

  def get_artwork_ids(artworks)
    artworks.map { |a| a['id'] }.uniq
  end

  def get_sold_primary_count(artworks)
    artworks
      .select { |a| a[KEY_AVAILABILITY] == STATE_SOLD && PRIMARY_COLORS.include?(a[KEY_DOMINANT_COLOR]) }
      .count
  end

  def get_artist_names(artworks)
    artist_ids = artworks.map { |a| a[KEY_ARTIST_ID] }.uniq

    artist_ids
      .map { |id| get_artist(id) }
      .select { |a| a.key?(KEY_NAME) }
      .map { |a| a[KEY_NAME] }
      .sort
  end

  def get_artwork_for_sale(artworks)
    for_sale_primary = get_for_sale_primary(artworks)
    for_sale_not_primary = get_for_sale_nonprimary(artworks)
    for_sale = for_sale_primary + for_sale_not_primary
    for_sale.sort { |a, b| a[:id] <=> b[:id] }
  end

  def get_for_sale_primary(artworks)
    artworks
      .select { |a| a[KEY_AVAILABILITY] == STATE_FOR_SALE && PRIMARY_COLORS.include?(a[KEY_DOMINANT_COLOR]) }
      .map { |a| a.merge({ isPrimary: true }) }
      .map { |a| a.transform_keys(&:to_sym) }
  end

  def get_for_sale_nonprimary(artworks)
    artworks
      .select { |a| a[KEY_AVAILABILITY] == STATE_FOR_SALE && !PRIMARY_COLORS.include?(a[KEY_DOMINANT_COLOR]) }
      .map { |a| a.transform_keys(&:to_sym) }
  end

  def get_artist(artist_id)
    response = RestClient.get ARTIST_URL, params: { id: artist_id }
    json = JSON.parse(response)
    json.first if json.is_a?(Array)
  rescue StandardError => e
    puts e
  end

  def get_artworks(options, current_page)
    offset = (current_page - 1) * ARTWORKS_LIMIT

    params = { limit: ARTWORKS_LIMIT, offset: offset }

    params[:dominant_color] = options[:dominant_color] if options.key?(:dominant_color)

    begin
      response = RestClient.get ARTWORKS_URL, { params: params }
      JSON.parse(response)
    rescue StandardError => e
      puts e
    end
  end
end
