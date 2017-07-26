require 'sinatra/base'
require 'sinatra_auth_github'
require 'securerandom'
require_relative '../app/models/user'
require_relative '../app/models/token'

#    Lame module to allow use of action_viiew which defines an empty
#    Rails module that triggers a bad check in wargen/sso.rb#5

# require_relative 'fake_rails'

module Sinatra
  module Auth
    # Helper methods
    module Helpers
      # To be used by services
      def verify_auth_token
        throw :warden unless valid_auth_token?
      end

      def valid_user?(token)
        begin
          t = Token.find(token)
          @current_user = t.user
        rescue ActiveResource::ResourceNotFound,
            ActiveRecord::RecordNotFound
          @current_user = nil
        end
      end

      def extracted_token
        pattern = /Token\s*token=(.*)/
        c = pattern.match(env['HTTP_AUTHORIZATION'])
        if c && c.captures.size
          c.captures[0]
        else
          nil
        end
      end

      def auth_header?
        !!env['HTTP_AUTHORIZATION']
      end

      def valid_auth_token?
        token = extracted_token
        if token && valid_user?(token)
          true
        else
          false
        end
      end

      def verify_user
        if auth_header?
          verify_auth_token
        else
          verify_logged_in_user
        end
      end

      # to be used by webpage viewers
      def verify_logged_in_user
        unless github_user && warden_github_sso_session_valid?(github_user, 120)
          request.env['warden'].logout
          request.env['warden'].authenticate!
        end
        @current_user = User.from_oauth(github_user)
      end
    end

    def self.registered(app)
      app.include Warden::GitHub::SSO
      # app.enable :sessions
      app.set :sessions, domain: ".#{ENV['DOMAIN']}"
      app.set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }
      # ENV['WARDEN_GITHUB_VERIFIER_SECRET'] ||= SecureRandom.hex(64)

      app.set :github_options, {
          :scopes    => "user",
          :secret    => ENV['GITHUB_CLIENT_SECRET'],
          :client_id => ENV['GITHUB_CLIENT_ID'],
      }

      app.get '/tokens' do
        verify_logged_in_user
        tokens = Token.find(:all, params: { by_user_id: @current_user.id } )
        [200, {tokens: tokens}.to_json ]
      end

      app.register Sinatra::Auth::Github
      app.helpers Auth::Helpers
    end
  end

  register Auth
end