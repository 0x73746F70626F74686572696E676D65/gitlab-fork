# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Patch::LegacyDatabaseConfig do
  describe '#load_geo_database_yaml' do
    let(:configuration) { Rails::Application::Configuration.new(Rails.root) }

    context 'when config/database_geo.yml does not exist' do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(Rails.root.join("config/database_geo.yml")).and_return(false)
      end

      it 'returns an empty hash' do
        expect(configuration.load_geo_database_yaml).to eq({})
      end
    end

    context 'when config/database_geo.yml exists' do
      shared_examples 'hash containing geo: connection name' do
        it 'returns a hash containing geo:' do
          expect(configuration.load_geo_database_yaml).to match(
            "production" => { "geo" => a_hash_including("adapter") },
            "development" => { "geo" => a_hash_including("adapter" => "postgresql") },
            "test" => { "geo" => a_hash_including("adapter" => "postgresql") }
          )
        end
      end

      before do
        allow(Pathname)
          .to receive(:new)
          .and_call_original

        allow(Pathname)
          .to receive(:new).with(Rails.root.join('config/database_geo.yml'))
          .and_return(double(read: database_geo_yml))
      end

      context 'when config/database_geo.yml use a new syntax' do
        let(:database_geo_yml) do
          <<-EOS
            production:
              geo:
                adapter: postgresql
                encoding: unicode
                database: gitlabhq_geo_production
                username: git
                password: "secure password"
                host: localhost

            development:
              geo:
                adapter: postgresql
                encoding: unicode
                database: gitlabhq_geo_development
                username: postgres
                password: "secure password"
                host: localhost
                variables:
                  statement_timeout: 15s

            test: &test
              geo:
                adapter: postgresql
                encoding: unicode
                database: gitlabhq_geo_test
                username: postgres
                password:
                host: localhost
                prepared_statements: false
                variables:
                  statement_timeout: 15s
          EOS
        end

        include_examples 'hash containing geo: connection name'
      end

      context 'when config/database_geo.yml use a legacy syntax' do
        let(:database_geo_yml) do
          <<-EOS
            production:
              adapter: postgresql
              encoding: unicode
              database: gitlabhq_geo_production
              username: git
              password: "secure password"
              host: localhost

            development:
              adapter: postgresql
              encoding: unicode
              database: gitlabhq_geo_development
              username: postgres
              password: "secure password"
              host: localhost
              variables:
                statement_timeout: 15s

            test: &test
              adapter: postgresql
              encoding: unicode
              database: gitlabhq_geo_test
              username: postgres
              password:
              host: localhost
              prepared_statements: false
              variables:
                statement_timeout: 15s
          EOS
        end

        include_examples 'hash containing geo: connection name'
      end
    end
  end

  describe '#database_configuration' do
    let(:configuration) { Rails::Application::Configuration.new(Rails.root) }

    before do
      # The `AS::ConfigurationFile` calls `read` in `def initialize`
      # thus we cannot use `allow_next_instance_of`
      # rubocop:disable RSpec/AnyInstanceOf
      allow_any_instance_of(ActiveSupport::ConfigurationFile)
        .to receive(:read).with(Rails.root.join('config/database.yml')).and_return(database_yml)
      # rubocop:enable RSpec/AnyInstanceOf
    end

    context 'when config/database_geo.yml does not exist' do
      shared_examples 'hash containing main: connection name' do
        it 'returns a hash containing only main:' do
          database_configuration = configuration.database_configuration

          expect(database_configuration).to match(
            "production" => { "main" => a_hash_including("adapter") },
            "development" => { "main" => a_hash_including("adapter" => "postgresql") },
            "test" => { "main" => a_hash_including("adapter" => "postgresql") }
          )
        end
      end

      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(Rails.root.join("config/database_geo.yml")).and_return(false)
      end

      context 'when config/database.yml use a new syntax' do
        let(:database_yml) do
          <<-EOS
            production:
              main:
                adapter: postgresql
                encoding: unicode
                database: gitlabhq_production
                username: git
                password: "secure password"
                host: localhost

            development:
              main:
                adapter: postgresql
                encoding: unicode
                database: gitlabhq_development
                username: postgres
                password: "secure password"
                host: localhost
                variables:
                  statement_timeout: 15s

            test: &test
              main:
                adapter: postgresql
                encoding: unicode
                database: gitlabhq_test
                username: postgres
                password:
                host: localhost
                prepared_statements: false
                variables:
                  statement_timeout: 15s
          EOS
        end

        include_examples 'hash containing main: connection name'
      end

      context 'when config/database.yml use a legacy syntax' do
        let(:database_yml) do
          <<-EOS
            production:
              adapter: postgresql
              encoding: unicode
              database: gitlabhq_production
              username: git
              password: "secure password"
              host: localhost

            development:
              adapter: postgresql
              encoding: unicode
              database: gitlabhq_development
              username: postgres
              password: "secure password"
              host: localhost
              variables:
                statement_timeout: 15s

            test: &test
              adapter: postgresql
              encoding: unicode
              database: gitlabhq_test
              username: postgres
              password:
              host: localhost
              prepared_statements: false
              variables:
                statement_timeout: 15s
          EOS
        end

        include_examples 'hash containing main: connection name'

        it 'configuration is legacy' do
          configuration.database_configuration

          expect(configuration.uses_legacy_database_config).to eq(true)
        end
      end
    end

    context 'when config/database_geo.yml exists' do
      let(:database_geo_yml) do
        <<-EOS
          production:
            adapter: postgresql
            encoding: unicode
            database: gitlabhq_geo_production
            username: git
            password: "secure password"
            host: localhost

          development:
            adapter: postgresql
            encoding: unicode
            database: gitlabhq_geo_development
            username: postgres
            password: "secure password"
            host: localhost

          staging:
            adapter: postgresql
            encoding: unicode
            database: gitlabhq_geo_staging
            username: git
            password: "secure password"
            host: localhost

          test: &test
            adapter: postgresql
            encoding: unicode
            database: gitlabhq_geo_test
            username: postgres
            password:
            host: localhost
        EOS
      end

      shared_examples 'hash containing both main: and geo: connection names' do
        it 'returns a hash containing both main: and geo:' do
          database_configuration = configuration.database_configuration

          expect(database_configuration).to match(
            "production" => { "main" => a_hash_including("adapter"), "geo" => a_hash_including("adapter") },
            "development" => { "main" => a_hash_including("adapter"), "geo" => a_hash_including("adapter" => "postgresql") },
            "test" => { "main" => a_hash_including("adapter"), "geo" => a_hash_including("adapter" => "postgresql") }
          )
        end
      end

      before do
        # The `AS::ConfigurationFile` calls `read` in `def initialize`
        # thus we cannot use `allow_next_instance_of`
        # rubocop:disable RSpec/AnyInstanceOf
        allow_any_instance_of(ActiveSupport::ConfigurationFile)
          .to receive(:read).with(Rails.root.join('config/database_geo.yml')).and_return(database_geo_yml)
        # rubocop:enable RSpec/AnyInstanceOf
      end

      context 'when config/database.yml use a new syntax' do
        let(:database_yml) do
          <<-EOS
            production:
              main:
                adapter: postgresql
                encoding: unicode
                database: gitlabhq_production
                username: git
                password: "secure password"
                host: localhost

            development:
              main:
                adapter: postgresql
                encoding: unicode
                database: gitlabhq_development
                username: postgres
                password: "secure password"
                host: localhost
                variables:
                  statement_timeout: 15s

            test: &test
              main:
                adapter: postgresql
                encoding: unicode
                database: gitlabhq_test
                username: postgres
                password:
                host: localhost
                prepared_statements: false
                variables:
                  statement_timeout: 15s
          EOS
        end

        include_examples 'hash containing both main: and geo: connection names'
      end

      context 'when config/database.yml use a legacy syntax' do
        let(:database_yml) do
          <<-EOS
            production:
              adapter: postgresql
              encoding: unicode
              database: gitlabhq_production
              username: git
              password: "secure password"
              host: localhost

            development:
              adapter: postgresql
              encoding: unicode
              database: gitlabhq_development
              username: postgres
              password: "secure password"
              host: localhost
              variables:
                statement_timeout: 15s

            test: &test
              adapter: postgresql
              encoding: unicode
              database: gitlabhq_test
              username: postgres
              password:
              host: localhost
              prepared_statements: false
              variables:
                statement_timeout: 15s
          EOS
        end

        include_examples 'hash containing both main: and geo: connection names'
      end
    end
  end
end
