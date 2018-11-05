require 'securerandom'

module QA
  module Factory
    module Resource
      class User < Factory::Base
        attr_reader :unique_id
        attr_writer :username, :password

        def initialize
          @unique_id = SecureRandom.hex(8)
        end

        def username
          @username ||= "qa-user-#{unique_id}"
        end

        def password
          @password ||= 'password'
        end

        def name
          @name ||= username
        end

        def email
          @email ||= "#{username}@example.com"
        end

        def credentials_given?
          defined?(@username) && defined?(@password)
        end

        def fabricate!
          # Don't try to log-out if we're not logged-in
          if Page::Main::Menu.perform { |p| p.has_personal_area?(wait: 0) }
            Page::Main::Menu.perform { |main| main.sign_out }
          end

          if credentials_given?
            Page::Main::Login.perform do |login|
              login.sign_in_using_credentials(self)
            end
          else
            Page::Main::Login.perform do |login|
              login.switch_to_register_tab
            end
            Page::Main::SignUp.perform do |signup|
              signup.sign_up!(self)
            end
          end
        end

        def fabricate_via_api!
          resource_web_url(api_get)
        rescue ResourceNotFoundError
          super
        end

        def api_get_path
          "/users/#{fetch_id(username)}"
        end

        def api_post_path
          '/users'
        end

        def api_post_body
          {
            email: email,
            password: password,
            username: username,
            name: name,
            skip_confirmation: true
          }
        end

        private

        def fetch_id(username)
          users = parse_body(api_get_from("/users?username=#{username}"))

          unless users.size == 1 && users.first[:username] == username
            raise ResourceNotFoundError, "Expected one user with username #{username} but found: `#{users}`."
          end

          users.first[:id]
        end
      end
    end
  end
end
