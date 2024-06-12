# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Export::Part, type: :model, feature_category: :vulnerability_management do
  describe 'associations' do
    it { is_expected.to belong_to(:vulnerability_export) }
    it { is_expected.to belong_to(:organization) }
  end

  describe 'validations' do
    subject(:export_part) { build(:vulnerability_export_part) }

    it { is_expected.to validate_presence_of(:start_id) }
    it { is_expected.to validate_presence_of(:end_id) }
  end

  describe '#retrive_upload' do
    subject(:export_part) { create(:vulnerability_export_part) }

    before do
      file = Tempfile.new
      file.print "Hello World!"
      export_part.update!(file: file)
    end

    it 'retrieves the file associated with the vulnerability export part' do
      expect(export_part.file.read).to eq("Hello World!")
    end
  end
end
