# frozen_string_literal: true

module Vulnerabilities
  class Export
    class Part < ApplicationRecord
      include FileStoreMounter

      self.table_name = "vulnerability_export_parts"

      mount_file_store_uploader AttachmentUploader

      belongs_to :vulnerability_export, class_name: "Vulnerabilities::Export"
      belongs_to :organization, class_name: "Organizations::Organization"

      validates :start_id, presence: true
      validates :end_id, presence: true

      def retrieve_upload(_identifier, paths)
        Upload.find_by(model: self, path: paths)
      end
    end
  end
end
