JEKYLL_MIN_VERSION_3 = Gem::Version.new(Jekyll::VERSION) >= Gem::Version.new('3.0.0') unless defined? JEKYLL_MIN_VERSION_3

module Jekyll
  module Converters
    class DynocConverter < Converter

      safe true

      def initialize(config)
        @config = config
        config['dyndoc'] ||= 'dyndoc'
        dyndoc_ext = (config['dyndoc_ext'] ||= 'dyn')
        config['dyndoc_ext_re'] = Regexp.new("\.(#{dyndoc_ext.tr ',', '|'})$", Regexp::IGNORECASE)
        config['dyndoc_page_attribute_prefix'] ||= 'page'
        unless (dyndoc_config = (config['dyndoc'] ||= {})).frozen?
          # NOTE convert keys to symbols
          dyndoc_config.keys.each do |key|
            dyndoc_config[key.to_sym] = dyndoc_config.delete(key)
          end
          dyndoc_config[:safe] ||= 'safe'
          (dyndoc_config[:attributes] ||= []).tap do |attributes|
            attributes.unshift('notitle', 'hardbreaks', 'idprefix', 'idseparator=-', 'linkattrs')
            attributes.concat(IMPLICIT_ATTRIBUTES)
          end
          dyndoc_config.freeze
        end
      end

      def setup
        return if @setup
        @setup = true
        case @config['dyndoc']
        when 'dyndoc'
          begin
            require 'dyndoc-core' unless defined? ::Dyndoc
          rescue LoadError
            STDERR.puts 'You are missing a library required to convert Dyndoc files. Please run:'
            STDERR.puts '  $ [sudo] gem install dyndoc-ruby'
            raise FatalException.new('Missing dependency: dyndoc')
          end
        else
          STDERR.puts "Invalid Dyndoc processor: #{@config['dyndoc']}"
          STDERR.puts '  Valid options are [ dyndoc ]'
          raise FatalException.new("Invalid Dyndoc processor: #{@config['dyndoc']}")
        end
      end

      def matches(ext)
        ext =~ @config['dyndoc_ext_re']
      end

      def output_ext(ext)
        '.html'
      end

      def convert(content)
        setup
        case @config['dyndoc']
        when 'dyndoc'
          Dyndoc.convert(content, @config['dyndoc'])
        else
          warn 'Unknown Dyndoc converter. Passing through raw content.'
          content
        end
      end

      def load_header(content)
        setup
        case @config['dyndoc']
        when 'dyndoc'
          Dyndoc.load(content, parse_header_only: true)
        else
          warn 'Unknown Dyndoc converter. Cannot load document header.'
          nil
        end
      end
    end
  end

  module Generators
    # Promotes select Dyndoc attributes to Jekyll front matter
    class DyndocPreprocessor < Generator
      def generate(site)
        dyndoc_converter = JEKYLL_MIN_VERSION_3 ?
            site.find_converter_instance(Jekyll::Converters::DyndocConverter) :
            site.getConverterImpl(Jekyll::Converters::DyndocConverter)
        dyndoc_converter.setup
        unless (page_attr_prefix = site.config['dyndoc_page_attribute_prefix']).empty?
          page_attr_prefix = %(#{page_attr_prefix}-)
        end
        page_attr_prefix_l = page_attr_prefix.length

        site.pages.each do |page|
          if dyndoc_converter.matches(page.ext)
            next unless (doc = dyndoc_converter.load_header(page.content))

            page.data['title'] = doc.doctitle if doc.header?
            page.data['author'] = doc.author if doc.author

            unless (dyndoc_front_matter = doc.attributes
                .select {|name| name.start_with?(page_attr_prefix) }
                .map {|name, val| %(#{name[page_attr_prefix_l..-1]}: #{val}) }).empty?
              page.data.update(SafeYAML.load(dyndoc_front_matter * "\n"))
            end

            page.data['layout'] = 'default' unless page.data.key? 'layout'
          end
        end

        (JEKYLL_MIN_VERSION_3 ? site.posts.docs : site.posts).each do |post|
          if dyndoc_converter.matches(JEKYLL_MIN_VERSION_3 ? post.data['ext'] : post.ext)
            next unless (doc = dyndoc_converter.load_header(post.content))

            post.data['title'] = doc.doctitle if doc.header?
            post.data['author'] = doc.author if doc.author
            post.data['date'] = DateTime.parse(doc.revdate).to_time if doc.attr? 'revdate'

            unless (dyndoc_front_matter = doc.attributes
                .select {|name| name.start_with?(page_attr_prefix) }
                .map {|name, val| %(#{name[page_attr_prefix_l..-1]}: #{val}) }).empty?
              post.data.update(SafeYAML.load(dyndoc_front_matter * "\n"))
            end

            post.data['layout'] = 'post' unless post.data.key? 'layout'
          end
        end
      end
    end
  end

  module Filters
    # Convert an Dyndoc string into HTML output.
    #
    # input - The Dyndoc String to convert.
    #
    # Returns the HTML formatted String.
    def dyndocify(input)
      site = @context.registers[:site]
      converter = JEKYLL_MIN_VERSION_3 ?
          site.find_converter_instance(Jekyll::Converters::DyndocConverter) :
          site.getConverterImpl(Jekyll::Converters::DyndocConverter)
      converter.convert(input)
    end
  end
end
