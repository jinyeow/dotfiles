module Scraper
  class ImageScraper
    # fill this in
  end

  # TumblrScraper - Retrieves information relevant for scraping images from the
  # tumblr.com domain.
  class TumblrScraper < ImageScraper
    attr_reader :url, :name, :ext

    def initialize(url)
      @url = url
      @name = URI.parse(url).path.split('/').last
      @ext = File.extname @name
    end
  end

  # ChiveScraper - Scrapes all images from a single page from thechive.com.
  class ChiveScraper < ImageScraper
    require 'nokogiri'
    attr_reader :url, :name

    def initialize(url)
      @url = url
      @name = URI.parse(url).path.split('/').last
    end

    def gallery
      page = Nokogiri::HTML(open(url))
      gallery = page.xpath('//figure/*/img').map do |i|
        i['src']
      end
      gallery
    end

    def img_name(link)
      URI.parse(link).path.split('/').last
    end

    def data
      data = {}
      data[:images] = []
      gallery.each do |img_link|
        data[:images].push(
          link: img_link,
          title: img_name(img_link).split('.').first,
          ext: File.extname(img_name(img_link))
        )
      end
      data
    end
  end
end
