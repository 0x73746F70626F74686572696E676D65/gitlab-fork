# frozen_string_literal: true

require('spec_helper')

RSpec.describe Projects::Settings::AnalyticsController, feature_category: :product_analytics_visualization do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group, project_setting: build(:project_setting)) }
  let_it_be(:pointer_project) { create(:project, group: group) }

  context 'as a maintainer' do
    before_all do
      project.add_maintainer(user)
    end

    before do
      sign_in(user)
    end

    describe 'GET show' do
      subject do
        get project_settings_analytics_path(project)
      end

      it 'renders analytics settings' do
        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:show)
      end

      it 'is unavailable when the combined_analytics_dashboards feature flag is disabled' do
        stub_feature_flags(combined_analytics_dashboards: false)

        subject

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    describe 'PATCH update' do
      it 'redirects with expected flash' do
        params = {
          project: {
            project_setting_attributes: {
              cube_api_key: 'cube_api_key',
              product_analytics_configurator_connection_string: 'https://test:test@configurator.example.com',
              product_analytics_data_collector_host: 'https://collector.example.com',
              cube_api_base_url: 'https://cube.example.com'
            }
          }
        }
        patch project_settings_analytics_path(project, params)

        expect(response).to have_gitlab_http_status(:found)
        expect(response).to redirect_to(project_settings_analytics_path(project))
        expect(flash[:toast]).to eq("Analytics settings for '#{project.name}' were successfully updated.")
      end

      context 'with existing product_analytics_instrumentation_key' do
        before do
          project.project_setting.update!(
            product_analytics_instrumentation_key: "key",
            product_analytics_configurator_connection_string: 'http://test:test@old_configurator.example.com',
            product_analytics_data_collector_host: 'http://test.net',
            cube_api_base_url: 'https://test.com:3000',
            cube_api_key: 'helloworld'
          )
          project.reload
        end

        it 'updates product analytics settings' do
          params = {
            project: {
              project_setting_attributes: {
                product_analytics_configurator_connection_string: 'https://test:test@configurator.example.com',
                product_analytics_data_collector_host: 'https://collector.example.com',
                cube_api_base_url: 'https://cube.example.com',
                cube_api_key: 'cube_api_key'
              }
            }
          }

          expect do
            patch project_settings_analytics_path(project, params)
          end.to change {
            project.reload.project_setting.product_analytics_configurator_connection_string
          }.to(
            params.dig(:project, :project_setting_attributes, :product_analytics_configurator_connection_string)
          ).and change {
            project.reload.project_setting.product_analytics_data_collector_host
          }.to(
            params.dig(:project, :project_setting_attributes, :product_analytics_data_collector_host)
          ).and change {
            project.reload.project_setting.cube_api_base_url
          }.to(
            params.dig(:project, :project_setting_attributes, :cube_api_base_url)
          ).and change {
            project.reload.project_setting.cube_api_key
          }.to(
            params.dig(:project, :project_setting_attributes, :cube_api_key)
          )
        end

        it 'cleans up instrumentation key when params has product_analytics_configurator_connection_string' do
          params = {
            project: {
              project_setting_attributes: {
                product_analytics_configurator_connection_string: 'https://test:test@test.example.com',
                product_analytics_data_collector_host: 'http://test.net',
                cube_api_base_url: 'https://test.com:3000',
                cube_api_key: 'helloworld'
              }
            }
          }

          expect do
            patch project_settings_analytics_path(project, params)
          end.to change {
            project.reload.project_setting.product_analytics_configurator_connection_string
          }.to(
            params.dig(:project, :project_setting_attributes, :product_analytics_configurator_connection_string)
          ).and change {
            project.reload.project_setting.product_analytics_instrumentation_key
          }.to(nil)
        end

        it 'does not clean up instrumentation key when params does not have project_setting_attributes' do
          params = {
            project: {
              analytics_dashboards_pointer_attributes: {
                target_project_id: project.id,
                id: project.id
              }
            }
          }

          expect do
            patch project_settings_analytics_path(project, params)
          end.to not_change {
            project.reload.project_setting.product_analytics_instrumentation_key
          }
        end

        it 'updates dashboard pointer project reference and does not clean up instrumentation key' do
          params = settings_params(pointer_project.id)
          expect do
            patch project_settings_analytics_path(project, params)
          end.to change {
            project.reload.analytics_dashboards_configuration_project
          }.to(pointer_project)
          expect(project.reload.project_setting.product_analytics_instrumentation_key).not_to be_nil
        end
      end

      it 'updates dashboard pointer project reference' do
        params = settings_params(pointer_project.id)
        expect do
          patch project_settings_analytics_path(project, params)
        end.to change {
          project.reload.analytics_dashboards_configuration_project
        }.to(pointer_project)
      end

      context 'when save is unsuccessful' do
        before do
          allow_next_instance_of(::Projects::UpdateService) do |instance|
            allow(instance).to receive(:execute).and_return(ServiceResponse.error(message: 'failed'))
          end
        end

        it 'redirects back to form with error' do
          params = {
            project: {
              project_setting_attributes: {
                cube_api_key: 'cube_api_key'
              }
            }
          }
          patch project_settings_analytics_path(project, params)

          expect(response).to have_gitlab_http_status(:found)
          expect(response).to redirect_to(project_settings_analytics_path(project))
          expect(flash[:alert]).to eq('failed')
        end
      end

      context 'with existing dashboard pointer reference' do
        before do
          params = settings_params(project.id)
          patch project_settings_analytics_path(project, params)
        end

        it 'updates dashboard pointer reference' do
          params = {
            project: {
              analytics_dashboards_pointer_attributes: {
                target_project_id: pointer_project.id,
                id: project.analytics_dashboards_pointer.id
              }
            }
          }
          expect do
            patch project_settings_analytics_path(project, params)
          end.to change {
            project.reload.analytics_dashboards_configuration_project
          }.to(pointer_project)
        end
      end
    end
  end

  describe 'for personal namespace projects' do
    let_it_be_with_reload(:project) { create(:project) }
    let_it_be(:user) { project.first_owner }

    before_all do
      project.add_maintainer(user)
    end

    before do
      sign_in(user)
    end

    subject do
      get project_settings_analytics_path(project)
    end

    it 'returns a 404 on rendering analytics settings' do
      subject

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  shared_examples 'returns not found' do
    it 'returns 404 response' do
      send_analytics_settings_request
      expect(response).to have_gitlab_http_status(:not_found)

      send_analytics_settings_update_request
      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  shared_examples 'returns success' do
    it 'returns 200 response' do
      send_analytics_settings_request
      expect(response).to have_gitlab_http_status(:ok)

      send_analytics_settings_update_request
      expect(response).to have_gitlab_http_status(:found)
      expect(response).to redirect_to(project_settings_analytics_path(project))
      expect(flash[:toast]).to eq("Analytics settings for '#{project.name}' were successfully updated.")
    end
  end

  context 'with different access levels' do
    before do
      sign_in(user)
      stub_licensed_features(combined_project_analytics_dashboards: true)
      project.add_member(user, access_level)
    end

    where(:access_level, :example_to_run) do
      nil         | 'returns not found'
      :guest      | 'returns not found'
      :reporter   | 'returns not found'
      :developer  | 'returns not found'
      :maintainer | 'returns success'
      :owner      | 'returns success'
    end

    with_them do
      let_it_be_with_reload(:user) { create(:user) }

      it_behaves_like params[:example_to_run]
    end
  end

  private

  def send_analytics_settings_request
    get project_settings_analytics_path(project)
  end

  def send_analytics_settings_update_request
    params = {
      project: {
        project_setting_attributes: {
          product_analytics_configurator_connection_string: 'http://test:test@old_configurator.example.com',
          product_analytics_data_collector_host: 'http://test.net',
          cube_api_base_url: 'https://test.com:3000',
          cube_api_key: 'cube_api_key'
        }
      }
    }
    patch project_settings_analytics_path(project, params)
  end

  def settings_params(target_project_id)
    {
      project: {
        analytics_dashboards_pointer_attributes: {
          target_project_id: target_project_id
        }
      }
    }
  end
end
