# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Creating an Iteration' do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:cadence) { build(:iterations_cadence, group: group, automatic: false).tap { |cadence| cadence.save!(validate: false) } }

  let(:start_date) { Time.now.strftime('%F') }
  let(:end_date) { 1.day.from_now.strftime('%F') }
  let(:attributes) do
    {
        title: 'title',
        description: 'some description',
        start_date: start_date,
        due_date: end_date
    }
  end

  let(:params) do
    {
      group_path: group.full_path
    }
  end

  let(:mutation) do
    graphql_mutation(:create_iteration, params.merge(attributes))
  end

  def mutation_response
    graphql_mutation_response(:create_iteration)
  end

  shared_examples 'legacy iteration creation request' do
    it 'creates a new iteration in the default manual cadence' do
      post_graphql_mutation(mutation, current_user: current_user)

      iteration_hash = mutation_response['iteration']
      aggregate_failures do
        expect(iteration_hash['title']).to eq('title')
        expect(iteration_hash['iterationCadence']['id']).to eq(cadence.to_global_id.to_s)
      end
    end
  end

  shared_examples 'iteration create request' do
    context 'when there are several iteration cadences in the group' do
      let_it_be(:extra_cadence) { create(:iterations_cadence, group: group) }

      context 'when iteration cadence id is not provided' do
        it_behaves_like 'legacy iteration creation request'
      end

      context 'when iteration cadence id is provided' do
        before do
          attributes[:iterations_cadence_id] = extra_cadence.to_global_id.to_s
        end

        it_behaves_like 'legacy iteration creation request'
      end
    end

    context 'when there is only one iteration cadence in the group' do
      context 'when iteration cadence id is not provided' do
        it_behaves_like 'legacy iteration creation request'
      end

      context 'when iteration cadence id is provided' do
        before do
          attributes[:iterations_cadence_id] = cadence.to_global_id.to_s
        end

        it_behaves_like 'legacy iteration creation request'
      end
    end
  end

  context 'when the user does not have permission' do
    before do
      stub_licensed_features(iterations: true)
    end

    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not create iteration' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }.not_to change(Iteration, :count)
    end
  end

  context 'when the user has permission' do
    before do
      group.add_developer(current_user)
    end

    context 'when iterations are disabled' do
      before do
        stub_licensed_features(iterations: false)
      end

      it_behaves_like 'a mutation that returns top-level errors',
                      errors: ['The resource that you are attempting to access does not '\
                 'exist or you don\'t have permission to perform this action']
    end

    context 'when iterations are enabled' do
      before do
        stub_licensed_features(iterations: true)
      end

      context 'with iterations_cadences FF disabled' do
        before do
          stub_feature_flags(iteration_cadences: false)
        end

        it_behaves_like 'iteration create request'
      end

      context 'with iterations_cadences FF enabled' do
        before do
          stub_feature_flags(iteration_cadences: true)
        end

        it_behaves_like 'iteration create request'

        context 'when title is not given' do
          let(:attributes) { { start_date: start_date, due_date: end_date } }

          it 'creates an iteration' do
            post_graphql_mutation(mutation, current_user: current_user)

            iteration_hash = mutation_response['iteration']
            aggregate_failures do
              expect(iteration_hash['title']).to eq(nil)
              expect(iteration_hash['startDate']).to eq(start_date)
              expect(iteration_hash['dueDate']).to eq(end_date)
            end
          end
        end
      end

      context 'with iterations_cadences FF disabled' do
        before do
          stub_feature_flags(iteration_cadences: false)
        end

        context 'when title is not given' do
          let(:attributes) { { start_date: start_date, due_date: end_date } }

          it_behaves_like 'a mutation that returns top-level errors',
                          errors: ["Title can't be blank"]

          it 'does not create the iteration' do
            expect { post_graphql_mutation(mutation, current_user: current_user) }.not_to change(Iteration, :count)
          end
        end
      end

      context 'when there are ActiveRecord validation errors' do
        let(:attributes) { { description: '' } }

        it_behaves_like 'a mutation that returns errors in the response',
                        errors: ["Start date can't be blank", "Due date can't be blank"]

        it 'does not create the iteration' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }.not_to change(Iteration, :count)
        end
      end

      context 'when the list of attributes is empty' do
        let(:attributes) { {} }

        it_behaves_like 'a mutation that returns top-level errors',
                        errors: ['The list of iteration attributes is empty']

        it 'does not create the iteration' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }.not_to change(Iteration, :count)
        end
      end

      context 'when the params contains neither group nor project path' do
        let(:params) { {} }

        it_behaves_like 'a mutation that returns top-level errors',
                        errors: ['Exactly one of group_path or project_path arguments is required']

        it 'does not create the iteration' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }.not_to change(Iteration, :count)
        end
      end

      context 'when the params contains both group and project path' do
        let(:params) { { group_path: group.full_path, project_path: 'doesnotreallymatter' } }

        it_behaves_like 'a mutation that returns top-level errors',
                        errors: ['Exactly one of group_path or project_path arguments is required']

        it 'does not create the iteration' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }.not_to change(Iteration, :count)
        end
      end
    end
  end
end
