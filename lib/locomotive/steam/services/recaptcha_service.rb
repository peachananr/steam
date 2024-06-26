require 'httparty'

module Locomotive
  module Steam

    # This service supports Google Recaptcha or any API compatible with Google
    class RecaptchaService

      GOOGLE_API_URL = 'https://www.google.com/recaptcha/api/siteverify'.freeze

      def initialize(site, request)
        attributes = site.metafields.values.reduce({}, :merge).with_indifferent_access

        @api      = attributes[:recaptcha_api_url] || GOOGLE_API_URL
        @secret   = attributes[:recaptcha_secret]
        @ip       = request.ip
        @min_score = attributes[:recaptcha_threshold] || 0.5
      end

      def verify(response_code)
        # save a HTTP query if there is no code
        return false if response_code.blank?

        _response = HTTParty.get(@api, { query: {
          secret:   @secret,
          response: response_code,
          remoteip: @ip
        }})

        return false if _response.parsed_response['score'] < @min_score
        
        _response.parsed_response['success']
      end

    end

  end
end
