# frozen_string_literal: true

module Dependencies # rubocop:disable Gitlab/BoundedContexts -- This is an existing module
  class DependencyListExport
    class Part < ApplicationRecord
      include FileStoreMounter

      self.table_name = 'dependency_list_export_parts'

      mount_file_store_uploader AttachmentUploader

      belongs_to :dependency_list_export, class_name: 'Dependencies::DependencyListExport'
      belongs_to :organization, class_name: 'Organizations::Organization'

      validates :start_id, presence: true
      validates :end_id, presence: true

      def retrieve_upload(_identifier, paths)
        Upload.find_by(model: self, path: paths)
      end
    end
  end
end
