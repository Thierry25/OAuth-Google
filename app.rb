# frozen_string_literal: true

# Roda web app demonstrating Github OAuth
# Install:
# - clone this repo
# - rbenv install 3.1.1
# - bundle
# - setup OAuth app for Github and get Github id/secret
# - put OAuth id/secret in config/secrets.yml
#
# Run using: rackup -p 4567

require 'roda'
require 'figaro'
require 'http'
require 'pry'

# Demo app for three-legged OAuth
class OAuthDemo < Roda
  plugin :environments

  configure do
    # load config secrets into local environment variables (ENV)
    Figaro.application = Figaro::Application.new(
      environment: environment, # rubocop:disable Style/HashSyntax
      path: File.expand_path('config/secrets.yml')
    )
    Figaro.load
    def self.config = Figaro.env
  end

  ONE_MONTH = 30 * 24 * 60 * 60 # in seconds

  use Rack::Session::Cookie, expire_after: ONE_MONTH, secret: 'not-a-secret'

  def config
    @config ||= OAuthDemo.config
  end

  route do |routing|
    routing.root do
      'Tell me the <a href="/secret">secret to life</a>'
    end

    routing.get 'secret' do
      routing.redirect '/login' unless session[:credentials]

      account = JSON.parse(session[:credentials])
      binding.pry
      name = account['name']
      family_name = account['family_name']
      given_name = account['given_name']
      picture = account['picture']
      email = account['email']

      "THE SECRET TO LIFE: Both your best friend and worst enemy is #{name} at #{email}"\
      "THE FAMILY #{family_name} the given #{given_name} #{picture}"\
      "<BR><a href='/logout'>logout</a>"
    end

    routing.get 'login' do
      url = 'https://accounts.google.com/o/oauth2/v2/auth'

      # scope = 'https://www.googleapis.com/auth/userinfo.profile'
      scope = 'email profile'
      oauth_params = ["client_id=#{config.GOOGLE_CLIENT_ID}",
                      "redirect_uri=#{config.REDIRECT_URI}",
                      "scope=#{scope}",
                      'response_type=code'].join('&')
      "<a href='#{url}?#{oauth_params}'> Login with Google</a>"
    end

    routing.get 'oauth2callback' do
      result = HTTP.headers(accept: 'application/json')
                   .post('https://oauth2.googleapis.com/token',
                         form: { client_id: config.GOOGLE_CLIENT_ID,
                                 client_secret: config.GOOGLE_CLIENT_SECRET,
                                 code: routing.params['code'],
                                 redirect_uri: config.REDIRECT_URI.to_s,
                                 grant_type: 'authorization_code' })
                   .parse

      puts "ACCESS TOKEN: #{result}\n"

      google_account = HTTP.get("#{config.GET_USER_INFO}#{result['id_token']}").parse

      # puts "GITHUB ACCOUNT: #{gh_account}"
      # puts result
      session[:credentials] = google_account.to_json

      routing.redirect '/secret'
    end

    routing.get 'logout' do
      session[:credentials] = nil
      routing.redirect '/'
    end
  end
end
