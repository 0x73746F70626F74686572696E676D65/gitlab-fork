# frozen_string_literal: true

module Geo
  class PackageFileReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy

    def self.model
      ::Packages::PackageFile
    end

    override :verification_feature_flag_enabled?
    def self.verification_feature_flag_enabled?
      true
    end

    def carrierwave_uploader
      model_record.file
    end
  end
end
