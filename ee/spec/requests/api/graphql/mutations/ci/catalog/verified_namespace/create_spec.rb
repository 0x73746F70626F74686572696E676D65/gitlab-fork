# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'VerifiedNamespaceCreate', feature_category: :pipeline_composition do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:root_namespace) { create(:group) }
  let_it_be(:project) { create(:project, group: root_namespace) }
  let_it_be(:group_project_resource) { create(:ci_catalog_resource, :published, project: project) }

  let(:mutation) do
    graphql_mutation(
      :verified_namespace_create,
      namespace_path: root_namespace.full_path,
      verification_level: 'GITLAB_MAINTAINED'
    )
  end

  let(:mutation_response) { graphql_mutation_response(:verified_namespace_create) }

  describe '#resolve' do
    context 'when on gitlab.com' do
      before do
        allow(Gitlab).to receive(:com?).and_return(true)
      end

      context 'when unauthorized' do
        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when authorized' do
        let_it_be(:current_user) { create(:admin) }

        context 'with valid arguments' do
          context 'when there is no verified namespace record for a given namespace' do
            it 'creates a verified namespace record' do
              post_graphql_mutation(mutation, current_user: current_user)

              expect(group_project_resource.reload.verification_level).to eq('gitlab_maintained')
              expect(Ci::Catalog::VerifiedNamespace.all.count).to eq(1)
            end
          end

          context 'when there is a verified namespace record for a given namespace' do
            it 'updates a verified namespace record' do
              ::Ci::Catalog::VerifyNamespaceService.new(root_namespace, 'verified_creator_maintained').execute
              expect(Ci::Catalog::VerifiedNamespace.all.count).to eq(1)
              expect(group_project_resource.reload.verification_level).to eq('verified_creator_maintained')

              post_graphql_mutation(mutation, current_user: current_user)

              expect(Ci::Catalog::VerifiedNamespace.all.count).to eq(1)
              expect(Ci::Catalog::VerifiedNamespace.first.verification_level).to eq('gitlab_maintained')
              expect(group_project_resource.reload.verification_level).to eq('gitlab_maintained')
            end
          end
        end

        context 'with invalid arguments' do
          context 'with invalid verification level' do
            let(:mutation) do
              graphql_mutation(
                :verified_namespace_create,
                namespace_path: root_namespace.full_path,
                verification_level: 'unknown'
              )
            end

            it 'returns an error' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
              end.not_to change { Ci::Catalog::VerifiedNamespace.all.count }

              expect { mutation_response }.to raise_error(GraphqlHelpers::NoData)
              expect(group_project_resource.reload.verification_level).to eq('unverified')
            end
          end

          context 'with invalid namespace path' do
            let(:invalid_path_error) { 'Please pass in the root namespace.' }
            let(:subgroup) { create(:group, parent: root_namespace) }

            let(:mutation) do
              graphql_mutation(
                :verified_namespace_create,
                namespace_path: subgroup.full_path,
                verification_level: 'GITLAB_MAINTAINED'
              )
            end

            it 'returns an error' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
              end.not_to change { Ci::Catalog::VerifiedNamespace.all.count }

              expect(mutation_response['errors']).to match_array([invalid_path_error])
              expect(group_project_resource.reload.verification_level).to eq('unverified')
            end
          end

          context 'with invalid verification level and namespace path' do
            let(:subgroup) { create(:group, parent: root_namespace) }

            let(:mutation) do
              graphql_mutation(
                :verified_namespace_create,
                namespace_path: subgroup.full_path,
                verification_level: 'unknown'
              )
            end

            let(:error_message) do
              'Variable $verifiedNamespaceCreateInput of type ' \
                'VerifiedNamespaceCreateInput! was provided invalid value for verificationLevel'
            end

            it 'returns multiple errors' do
              expect do
                post_graphql_mutation(mutation, current_user: current_user)
              end.not_to change { Ci::Catalog::VerifiedNamespace.all.count }

              expect do
                mutation_response
              end.to raise_error(GraphqlHelpers::NoData) { |error|
                expect(error.message).to include(error_message)
              }

              expect(group_project_resource.reload.verification_level).to eq('unverified')
            end
          end
        end
      end
    end

    context 'when on self-managed' do
      before do
        allow(Gitlab).to receive(:com?).and_return(false)
      end

      it 'returns an error' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response[
          'errors'
        ]).to eq(["Can't perform this action on a non-Gitlab.com instance."])
      end
    end
  end
end
