module Locomotive::Steam
  module Middlewares

    # Set the locale from the path if possible or use the default one
    #
    # Examples:
    #
    #   /fr/index   => locale = :fr
    #   /fr/        => locale = :fr
    #   /index      => locale = :en (default one)
    #
    #   /en/index?locale=fr => locale = :fr
    #   /index      => redirection to /en if the locale in cookie is :en
    #
    class Locale < ThreadSafe

      include Concerns::Helpers

      def _call
        env['steam.path']   = request.path_info

        env['steam.locale'] = services.locale = extract_locale

        set_locale_cookie

        debug_log "Locale used: #{locale.upcase}"

        I18n.with_locale(locale) do
          self.next
        end
      end

      protected

      def extract_locale
        # Regarding the index page (basically, "/"), we've to see if we could
        # guess the locale from the headers the browser sends to us.
        locale = if is_index_page? && !site.bypass_browser_locale
          locale_from_params || locale_from_cookie || locale_from_header
        else
          locale_from_path || locale_from_params
        end

        # make sure, the locale is among the ones defined in the site,
        # otherwise take the default one.
        locale && locales.include?(locale) ? locale : default_locale
      end

      def locale_from_params
        params[:locale]&.to_sym.tap do |locale|
          debug_log 'Locale extracted from the params' unless locale.blank?
        end
      end

      def locale_from_path
        path = request.path_info

        if path =~ /^\/(#{site.locales.join('|')})+(\/|$)/
          locale = $1

          # no need to keep the locale in the path used to fetch the page
          env['steam.path'] = path.gsub(/^\/#{$1 + $2}/, '/')
          env['steam.locale_in_path'] = true

          debug_log'Locale extracted from the path'

          locale.to_sym
        end
      end

      def locale_from_header
        request.accept_language.lazy
        .sort { |a, b| b[1] <=> a[1] }
        .map  { |lang, _| lang[0..1].to_sym }
        .find { |lang| locales.include?(lang) }.tap do |locale|
          debug_log 'Locale extracted from the header' unless locale.blank?
        end
      end

      def locale_from_cookie
        if locale = services.cookie.get(cookie_key_name)

          debug_log 'Locale extracted from the cookie'

          locale.to_sym
        end
      end

      def set_locale_cookie
        services.cookie.set(cookie_key_name, { 'value': locale, 'path': '/', 'max_age': 1.year })
      end

      # The preview urls for all the sites share the same domain, so cookie[:locale]
      # would be the same for all the preview urls and this is not good.
      # This is why we need to use a different key.
      def cookie_key_name
        live_editing? ? "steam-locale-#{site.handle}" : 'steam-locale'
      end

      def is_index_page?
        ['/', ''].include?(request.path_info)
      end

    end
  end
end
