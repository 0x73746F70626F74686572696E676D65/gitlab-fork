# frozen_string_literal: true
module Dependencies
  class DependencyListExport < ApplicationRecord
    include FileStoreMounter

    mount_file_store_uploader AttachmentUploader

    belongs_to :organization, class_name: 'Organizations::Organization'
    belongs_to :project
    belongs_to :group
    belongs_to :pipeline, class_name: 'Ci::Pipeline'
    belongs_to :author, class_name: 'User', foreign_key: :user_id, inverse_of: :dependency_list_exports

    has_many :export_parts, class_name: 'Dependencies::DependencyListExport::Part'

    validates :status, presence: true
    validates :file, presence: true, if: :finished?
    validates :export_type, presence: true

    validate :only_one_exportable

    enum export_type: {
      dependency_list: 0,
      sbom: 1
    }

    state_machine :status, initial: :created do
      state :created, value: 0
      state :running, value: 1
      state :finished, value: 2
      state :failed, value: -1

      event :start do
        transition created: :running
      end

      event :finish do
        transition running: :finished
      end

      event :reset_state do
        transition running: :created
      end

      event :failed do
        transition [:created, :running] => :failed
      end
    end

    def retrieve_upload(_identifier, paths)
      Upload.find_by(model: self, path: paths)
    end

    def exportable
      pipeline || project || group || organization
    end

    def exportable=(value)
      case value
      when Project
        self.project = value
      when Group
        self.group = value
      when Organizations::Organization
        self.organization = value
      when Ci::Pipeline
        self.pipeline = value
      else
        raise "Can not assign #{value.class} as exportable"
      end
    end

    private

    def only_one_exportable
      errors.add(:base, 'Only one exportable is required') unless [project, group, pipeline, organization].one?
    end
  end
end
