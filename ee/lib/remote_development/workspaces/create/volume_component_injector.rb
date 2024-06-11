# frozen_string_literal: true

module RemoteDevelopment
  module Workspaces
    module Create
      class VolumeComponentInjector
        include Messages

        # @param [Hash] context
        # @return [Hash]
        def self.inject(context)
          context => { processed_devfile: Hash => processed_devfile, volume_mounts: Hash => volume_mounts }
          volume_mounts => { data_volume: Hash => data_volume }
          data_volume => {
            name: String => volume_name,
            path: String => volume_path,
          }

          volume_component = {
            'name' => volume_name,
            'volume' => {
              'size' => '15Gi'
            }
          }

          processed_devfile['components'] << volume_component
          processed_devfile['components'].each do |component|
            next if component['container'].nil?

            component['container']['volumeMounts'] = [] if component['container']['volumeMounts'].nil?
            component['container']['volumeMounts'] += [{ 'name' => volume_name, 'path' => volume_path }]
          end

          context
        end
      end
    end
  end
end
