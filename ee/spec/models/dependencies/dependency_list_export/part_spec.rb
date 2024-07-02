# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dependencies::DependencyListExport::Part, feature_category: :dependency_management do
  describe 'associations' do
    it { is_expected.to belong_to(:dependency_list_export).class_name('Dependencies::DependencyListExport') }
    it { is_expected.to belong_to(:organization).class_name('Organizations::Organization') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:start_id) }
    it { is_expected.to validate_presence_of(:end_id) }
  end

  describe '#retrieve_upload' do
    let(:export_part) { create(:dependency_list_export_part, :exported) }
    let(:relative_path) { export_part.file.url[1..] }

    subject { export_part.retrieve_upload(export_part, relative_path) }

    it { is_expected.to be_present }
  end
end
