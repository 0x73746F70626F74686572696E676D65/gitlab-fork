# frozen_string_literal: true

module ProductAnalytics
  class SyncFunnelsWorker
    include ApplicationWorker

    data_consistency :sticky
    feature_category :product_analytics_data_management
    idempotent!

    def perform(project_id, newrev, user_id)
      @project = Project.find_by_id(project_id)
      @commit = @project.repository.commit(newrev)
      @user_id = user_id
      @payload = configurator_url_project_map

      return if funnels.empty?

      @payload.each do |url, project_ids|
        Gitlab::HTTP.post(
          url,
          body: {
            project_ids: project_ids.map { |id| "gitlab_project_#{id}" },
            funnels: funnels
          }.to_json,
          allow_local_requests: true
        )
      end
    end

    private

    def funnels
      [new_funnels, updated_funnels, deleted_funnels].flatten
    end

    def funnel_files
      @commit.deltas.select { |delta| delta.old_path.start_with?(".gitlab/analytics/funnels/") }
    end

    def new_funnels
      funnel_files.select(&:new_file).map do |file|
        funnel = ProductAnalytics::Funnel.from_diff(file, project: @project)
        {
          state: 'created',
          name: funnel.name,
          schema: funnel.to_json
        }
      end
    end

    def updated_funnels
      # if a file is not new or deleted, but is in a diff, we assume it is changed.
      funnel_files.select { |f| !f.new_file && !f.deleted_file }.map do |file|
        funnel = ProductAnalytics::Funnel.from_diff(file, project: @project, commit: @commit)
        o = {
          state: 'updated',
          name: funnel.name,
          schema: funnel.to_json
        }

        o[:previous_name] = funnel.previous_name.parameterize(separator: '_') unless funnel.previous_name.nil?
        o
      end
    end

    def deleted_funnels
      funnel_files.select(&:deleted_file).map do |file|
        funnel = ProductAnalytics::Funnel.from_diff(file, project: @project, sha: @commit.parent.sha)
        {
          state: 'deleted',
          name: funnel.name
        }
      end
    end

    def configurator_url_project_map
      map = {}

      project_ids_to_send.each do |project_id|
        settings = ::ProductAnalytics::Settings.for_project(Project.find_by_id(project_id))
        url = URI.join(settings.product_analytics_configurator_connection_string, "funnel-schemas")

        if map.has_key?(url)
          map[url] << project_id
        else
          map[url] = [project_id]
        end
      end

      map
    end

    def project_ids_to_send
      project_ids = [@project.id]

      project_ids += @project.targeting_dashboards_pointer_project_ids if @project.custom_dashboard_project?

      # if product analytics is not initialized for a project, there won't be a clickhouse database to write funnels
      # also there might be a pointer project pointing to self, thus we remove duplicates
      project_ids.select { |id| Project.find_by_id(id).product_analytics_initialized? }.uniq
    end
  end
end
