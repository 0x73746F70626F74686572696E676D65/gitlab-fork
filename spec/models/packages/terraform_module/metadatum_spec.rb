# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::TerraformModule::Metadatum, type: :model, feature_category: :package_registry do
  describe 'relationships' do
    it { is_expected.to belong_to(:package) }
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:package) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:fields) }

    it { expect(described_class).to validate_jsonb_schema(['terraform_module_metadata']) }

    describe '#metadata' do
      let_it_be(:metadata_fields) do
        {
          readme: 'README',
          inputs: [{ name: 'foo', description: 'input desc', type: 'string' }],
          outputs: [{ name: 'foo', description: 'output desc' }],
          dependencies: { providers: [{ name: 'foo', source: 'gitlab', version: '1.0.0' }],
                          modules: [{ name: 'bar', source: 'terraform', version: '1.2.3' }] },
          resources: %w[aws.gitlab_runner_instance aws_autoscaling_hook.terminate_instances]
        }
      end

      it 'validates #content against the terraform_module_metadata schema', :aggregate_failures do
        is_expected.to allow_value(root: { readme: 'README' }).for(:fields)
        is_expected.to allow_value(
          root: metadata_fields,
          submodules: { submodule: metadata_fields }
        ).for(:fields)
        is_expected.to allow_value(
          root: metadata_fields,
          submodules: { submodule: metadata_fields },
          examples: { example: metadata_fields.except(:dependencies, :resources) }
        ).for(:fields)
        is_expected.not_to allow_value({}).for(:fields)
        is_expected.not_to allow_value(root: { readme: 1 }).for(:fields)
        is_expected.not_to allow_value(root: { readme: 'README' }, submodules: [{ readme: 'README' }]).for(:fields)
        is_expected.not_to allow_value(root: { readme: 'README' * described_class::MAX_FIELDS_SIZE }).for(:fields)
                   .with_message(/metadata is too large/)
      end
    end

    describe '#terraform_module_package_type' do
      let_it_be(:metadatum) { build(:terraform_module_metadatum, package: build(:npm_package)) }

      it 'disallows a package with a different package_type' do
        expect(metadatum).not_to be_valid
        expect(metadatum.errors.to_a).to include('Package type must be Terraform Module')
      end
    end
  end
end
