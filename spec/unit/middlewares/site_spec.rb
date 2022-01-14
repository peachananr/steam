require 'spec_helper'

require_relative '../../../lib/locomotive/steam/middlewares/thread_safe'
require_relative '../../../lib/locomotive/steam/middlewares/concerns/helpers'
require_relative '../../../lib/locomotive/steam/middlewares/site'

describe Locomotive::Steam::Middlewares::Site do

  let(:render_404)      { true }
  let(:configuration)   { instance_double('SimpleConfiguration', render_404_if_no_site: render_404) }
  let(:services)        { instance_double('SimpleServices', configuration: configuration) }
  let(:url)             { 'http://models.example.com' }
  let(:engine_site)     { nil }
  let(:app)             { ->(env) { [200, env, 'app'] } }
  let(:middleware)      { Locomotive::Steam::Middlewares::Site.new(app) }
  let(:is_default_host) { nil }
  let(:live_editing)    { false }

  subject do
    env = env_for(url, 'steam.services' => services)
    env['steam.request']          = Rack::Request.new(env)
    env['steam.site']             = engine_site
    env['steam.is_default_host']  = is_default_host
    env['steam.live_editing']     = live_editing
    code, env = middleware.call(env)
    [code, env['Location']]
  end

  describe 'no site' do

    before { expect(services).to receive(:current_site).and_return(nil) }

    describe 'render_404 option on' do
      it { is_expected.to eq [404, nil] }
    end

    describe 'render_404 option off' do

      let(:render_404) { false }

      it 'raises an exception' do
        expect { subject }.to raise_exception(Locomotive::Steam::NoSiteException)
      end

    end

  end

  describe 'the site has been set from the Engine' do

    let(:engine_site) { instance_double('SiteWithDomains', name: 'Acme', domains: ['www.acme.com'], redirect_to_first_domain: false, redirect_to_https: false) }

    it 'sets the site for all the services' do
      expect(services).to receive(:set_site).with(engine_site).and_return(engine_site)
      is_expected.to eq [200, nil]
    end

  end

  describe 'redirection' do

    let(:redirect_to_first_domain)  { false }
    let(:redirect_to_https)         { false }    
    let(:url)  { 'http://acme.com' }
    let(:site) { instance_double('SiteWithDomains', name: 'Acme', domains: ['www.acme.com', 'acme.com'], redirect_to_first_domain: redirect_to_first_domain, redirect_to_https: redirect_to_https) }

    before { expect(services).to receive(:current_site).and_return(site) }

    describe 'redirection to https' do

      it { is_expected.to eq [200, nil] }

      describe 'option enabled' do

        let(:redirect_to_https) { true }

        it { is_expected.to eq [301, 'https://www.acme.com/'] }

        context 'https requested' do

          let(:url) { 'https://www.acme.com' }
          it { is_expected.to eq [200, nil] }

        end

        context 'requesting the default host' do

          let(:is_default_host) { true }
          it { is_expected.to eq [200, nil] }

        end

      end

    end

    describe 'redirection to the first domain' do

      it { is_expected.to eq [200, nil] }

      describe 'option enabled' do

        let(:redirect_to_first_domain) { true }

        it { is_expected.to eq [301, 'http://www.acme.com/'] }

        context 'first domain requested' do

          let(:url) { 'http://www.acme.com' }
          it { is_expected.to eq [200, nil] }

        end

        context 'requesting the default host' do

          let(:is_default_host) { true }
          it { is_expected.to eq [200, nil] }

        end

        context 'when editing the page in the editor' do

          let(:url) { 'https://locomotive.local/editor/foo' }
          let(:live_editing) { true }
          it { is_expected.to eq [200, nil] }

        end

      end

    end

    describe 'redirection to both https and the first domain' do

      let(:redirect_to_https)         { true }
      let(:redirect_to_first_domain)  { true }
      let(:url) { 'http://acme.com/foo/bar' }

      it { is_expected.to eq [301, 'https://www.acme.com/foo/bar'] }

    end

    describe 'redirection to the first domain' do

      let(:redirect_to_https)         { true }
      let(:redirect_to_first_domain)  { true }
      let(:url) { 'https://acme.com/foo/bar' }

      it { is_expected.to eq [301, 'https://www.acme.com/foo/bar'] }

    end

  end

end
