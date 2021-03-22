module Locomotive::Steam
  module Middlewares

    class Cache < ThreadSafe

      include Concerns::Helpers

      CACHEABLE_RESPONSE_CODES  = [200, 301, 404, 410].freeze

      CACHEABLE_REQUEST_METHODS = %w(GET HEAD).freeze

      DEFAULT_CACHE_CONTROL     = 'max-age=0, s-maxage=3600, public, must-revalidate'.freeze

      DEFAULT_CACHE_VARY        = 'Accept-Language'.freeze

      NO_CACHE_CONTROL          = 'max-age=0, private, must-revalidate'.freeze

      def _call
        if cacheable?
          key = cache_key

          # TODO: only for debugging
          # log("HTTP keys: #{env.select { |key, _| key.starts_with?('HTTP_') }}".light_blue)

          # Test if the ETag or Last Modified has been modified. If not, return a 304 response
          if stale?(key)
            render_response(nil, 304, nil)
            return
          end

          # we have to tell the CDN (or any proxy) what the expiration & validation strategy are
          env['steam.cache_control']        = cache_control
          env['steam.cache_vary']           = cache_vary
          env['steam.cache_etag']           = key
          env['steam.cache_last_modified']  = get_updated_at.httpdate
          env['steam.cache_status']  = "HIT"
          # retrieve the response from the cache.
          # This is useful if no CDN is being used.

          code, headers, _ = response = fetch_cached_response(key)

          unless CACHEABLE_RESPONSE_CODES.include?(code.to_i)
            env['steam.cache_control'] = headers['Cache-Control'] = NO_CACHE_CONTROL
            env['steam.cache_vary'] = headers['Vary'] = nil
          end

          # we don't want to render twice the page
          @next_response = response
        else
          env['steam.cache_control']  = NO_CACHE_CONTROL
        end
      end

      private

      def fetch_cached_response(key)
        log("Cache key = #{key.inspect}")
        if marshaled = cache.read(key)
          log('Cache HIT')
          env['steam.cache_status']  = "HIT"
          Marshal.load(marshaled)
        else
          log('Cache MISS')
          env['steam.cache_status']  = "MISS"
          self.next.tap do |response|
            cache.write(key, marshal(response))
          end
        end
      end

      def cacheable?
        CACHEABLE_REQUEST_METHODS.include?(env['REQUEST_METHOD']) &&
        !live_editing? &&
        site.try(:cache_enabled) &&
        page.try(:cache_enabled) &&
        is_redirect_url?
      end

      def cache_key
        site, path, query = env['steam.site'], env['PATH_INFO'], env['QUERY_STRING']
        slug = path.split('/').last
        if page.templatized?
          if entry = fetch_content_entry(slug)
            ['content_entry', 'entry', entry.content_type.slug.singularize].each do |key|
               env['steam.content_entry'] = page.content_entry = entry
            end
          end
        end
        key = "#{Locomotive::Steam::VERSION}/site/#{site._id}/#{get_updated_at.to_i}/page/#{path}/#{query}"
        puts "xxxxx #{path} #{query}"
        #Digest::MD5.hexdigest(key)
      end

      def get_updated_at
        page.content_entry.try(:updated_at).presence || page.try(:updated_at).presence || site.last_modified_at
      end

      def fetch_content_entry(slug)
        if type = content_type_repository.find(page.content_type_id)
          # don't accept a non localized entry in a locale other than the default one
          return nil if type.localized_names.count == 0 && locale.to_s != default_locale.to_s

          decorate_entry(content_entry_repository.with(type).by_slug(slug))
        else
          nil
        end
      end
      def content_type_repository
       services.repositories.content_type
      end
      def content_entry_repository
       services.repositories.content_entry
     end
      def cache_control
        page.try(:cache_control).presence || site.try(:cache_control).presence || DEFAULT_CACHE_CONTROL
      end

      def cache_vary
        page.try(:cache_vary).presence || site.try(:cache_vary).presence || DEFAULT_CACHE_VARY
      end

      def is_redirect_url?
        return false if page.nil?
        page.try(:redirect_url).blank?
      end

      def marshal(response)
        code, headers, body = response

        # only keep string value headers
        _headers = headers.reject { |key, val| !val.respond_to?(:to_str) }

        Marshal.dump([code, _headers, body])
      end

      def stale?(key)
        env['HTTP_IF_NONE_MATCH'] == key ||
        env['HTTP_IF_MODIFIED_SINCE'] == get_updated_at.httpdate
      end

      def cache
        services.cache
      end

    end

  end
end
