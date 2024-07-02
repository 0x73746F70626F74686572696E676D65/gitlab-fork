# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dependencies::DependencyListExport, feature_category: :dependency_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }

  describe 'associations' do
    subject(:export) { build(:dependency_list_export, project: project) }

    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:group) }
    it { is_expected.to belong_to(:author).class_name('User') }
    it { is_expected.to have_many(:export_parts).class_name('Dependencies::DependencyListExport::Part') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:export_type) }
    it { is_expected.not_to validate_presence_of(:file) }

    context 'when export is finished' do
      subject(:export) { build(:dependency_list_export, :finished, project: project) }

      it { is_expected.to validate_presence_of(:file) }
    end

    describe 'only one exportable can be set' do
      using RSpec::Parameterized::TableSyntax

      let(:expected_error) { { error: 'Only one exportable is required' } }

      subject { export.errors.details[:base] }

      before do
        export.validate
      end

      where(:args, :valid) do
        organization = build_stubbed(:organization)
        group = build_stubbed(:group, organization: organization)
        project = build_stubbed(:project, organization: organization, group: group)
        pipeline = build_stubbed(:ci_pipeline, project: project)

        [
          [{ organization: organization, group: group, project: project, pipeline: pipeline }, false],
          [{ organization: organization, group: group, project: project, pipeline: nil }, false],
          [{ organization: organization, group: group, project: nil, pipeline: pipeline }, false],
          [{ organization: organization, group: group, project: nil, pipeline: nil }, false],
          [{ organization: organization, group: nil, project: project, pipeline: pipeline }, false],
          [{ organization: organization, group: nil, project: project, pipeline: nil }, false],
          [{ organization: organization, group: nil, project: nil, pipeline: pipeline }, false],
          [{ organization: organization, group: nil, project: nil, pipeline: nil }, true],
          [{ organization: nil, group: group, project: project, pipeline: pipeline }, false],
          [{ organization: nil, group: group, project: project, pipeline: nil }, false],
          [{ organization: nil, group: group, project: nil, pipeline: pipeline }, false],
          [{ organization: nil, group: group, project: nil, pipeline: nil }, true],
          [{ organization: nil, group: nil, project: project, pipeline: pipeline }, false],
          [{ organization: nil, group: nil, project: project, pipeline: nil }, true],
          [{ organization: nil, group: nil, project: nil, pipeline: pipeline }, true],
          [{ organization: nil, group: nil, project: nil, pipeline: nil }, false]
        ]
      end

      with_them do
        let(:export) { build(:dependency_list_export, args) }

        if params[:valid]
          it { is_expected.not_to include(expected_error) }
        else
          it { is_expected.to include(expected_error) }
        end
      end
    end
  end

  describe '#status' do
    subject(:dependency_list_export) { create(:dependency_list_export, project: project) }

    around do |example|
      freeze_time { example.run }
    end

    context 'when the export is new' do
      it { is_expected.to have_attributes(status: 0) }

      context 'and it fails' do
        before do
          dependency_list_export.failed!
        end

        it { is_expected.to have_attributes(status: -1) }
      end
    end

    context 'when the export starts' do
      before do
        dependency_list_export.start!
      end

      it { is_expected.to have_attributes(status: 1) }
    end

    context 'when the export is running' do
      context 'and it finishes' do
        subject(:dependency_list_export) { create(:dependency_list_export, :with_file, :running, project: project) }

        before do
          dependency_list_export.finish!
        end

        it { is_expected.to have_attributes(status: 2) }
      end

      context 'and it fails' do
        subject(:dependency_list_export) { create(:dependency_list_export, :running, project: project) }

        before do
          dependency_list_export.failed!
        end

        it { is_expected.to have_attributes(status: -1) }
      end
    end
  end

  describe '#retrieve_upload' do
    let(:dependency_list_export) { create(:dependency_list_export, :finished, project: project) }
    let(:relative_path) { dependency_list_export.file.url[1..] }

    subject(:retrieve_upload) { dependency_list_export.retrieve_upload(dependency_list_export, relative_path) }

    it { is_expected.to be_present }
  end

  describe '#exportable' do
    let(:export) do
      build(:dependency_list_export,
        project: project,
        group: group,
        pipeline: pipeline)
    end

    subject { export.exportable }

    context 'when the exportable is a project' do
      let(:group) { nil }
      let(:pipeline) { nil }

      it { is_expected.to eq(project) }
    end

    context 'when the exportable is a group' do
      let(:project) { nil }
      let(:pipeline) { nil }

      it { is_expected.to eq(group) }
    end

    context 'when the exportable is a pipeline' do
      let(:project) { nil }
      let(:group) { nil }

      it { is_expected.to eq(pipeline) }
    end
  end

  describe '#exportable=' do
    let(:export) { build(:dependency_list_export) }
    let(:organization) { build_stubbed(:organization) }

    it 'sets the correct association' do
      expect { export.exportable = project }.to change { export.project }.to(project)
      expect { export.exportable = group }.to change { export.group }.to(group)
      expect { export.exportable = pipeline }.to change { export.pipeline }.to(pipeline)
      expect { export.exportable = organization }.to change { export.organization }.to(organization)
    end

    it 'raises when exportable is an unknown type' do
      expect { export.exportable = nil }.to raise_error(RuntimeError)
    end
  end
end
