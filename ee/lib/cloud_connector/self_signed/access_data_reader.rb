# frozen_string_literal: true

module CloudConnector
  module SelfSigned
    class AccessDataReader
      include ::CloudConnector::Utils

      def read_available_services
        service_descriptors = access_record_data['services'] || {}
        service_descriptors.map do |name, access_data|
          build_available_service_data(name, access_data)
        end.index_by(&:name)
      end

      private

      def parse_bundled_with(bundled_with_config)
        return unless bundled_with_config

        bundled_with = {}

        bundled_with_config.each do |bundle_descriptor_name, bundle_descriptor_data|
          bundled_with[bundle_descriptor_name] = bundle_descriptor_data['unit_primitives'].map(&:to_sym)
        end

        bundled_with
      end

      def access_record_data
        YAML.load_file(Rails.root.join('ee/config/cloud_connector/access_data.yml'))
      end

      def build_available_service_data(name, access_data)
        AvailableServiceData.new(
          name.to_sym,
          parse_time(access_data['cut_off_date']),
          parse_bundled_with(access_data['bundled_with']),
          access_data['backend']
        )
      end
    end
  end
end
