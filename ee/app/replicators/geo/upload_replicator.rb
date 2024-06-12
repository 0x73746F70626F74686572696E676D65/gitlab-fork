# frozen_string_literal: true

module Geo
  class UploadReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy

    def self.model
      ::Upload
    end

    override :verification_feature_flag_enabled?
    def self.verification_feature_flag_enabled?
      true
    end

    def carrierwave_uploader
      model_record.retrieve_uploader
    end

    # Do not allow download unless the upload's owner `model` is present.
    # Otherwise, attempting to build file paths will raise an exception.
    def predownload_validation_failure
      error_message = super
      return error_message if error_message

      upload = model_record

      unless upload.model.present?
        missing_model = "#{upload.model_type} with ID #{upload.model_id}"
        return "The model which owns Upload with ID #{upload.id} is missing: #{missing_model}"
      end

      nil
    end
  end
end
