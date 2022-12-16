# frozen_string_literal: true

module IdeHelper
  def ide_data
    {
      'can-use-new-web-ide' => can_use_new_web_ide?.to_s,
      'use-new-web-ide' => use_new_web_ide?.to_s,
      'new-web-ide-help-page-path' => help_page_path('user/project/web_ide/index.md', anchor: 'vscode-reimplementation'),
      'user-preferences-path' => profile_preferences_path,
      'branch-name' => @branch,
      'file-path' => @path,
      'fork-info' => @fork_info&.to_json,
      'merge-request' => @merge_request
    }.merge(use_new_web_ide? ? new_ide_data : legacy_ide_data)
  end

  def can_use_new_web_ide?
    Feature.enabled?(:vscode_web_ide, current_user)
  end

  def use_new_web_ide?
    can_use_new_web_ide? && !current_user.use_legacy_web_ide
  end

  private

  def new_ide_data
    {
      'project-path' => @project&.path_with_namespace,
      'csp-nonce' => content_security_policy_nonce,
      # We will replace these placeholders in the FE
      'ide-remote-path' => ide_remote_path(remote_host: ':remote_host', remote_path: ':remote_path')
    }
  end

  def legacy_ide_data
    {
      'empty-state-svg-path' => image_path('illustrations/multi_file_editor_empty.svg'),
      'no-changes-state-svg-path' => image_path('illustrations/multi-editor_no_changes_empty.svg'),
      'committed-state-svg-path' => image_path('illustrations/multi-editor_all_changes_committed_empty.svg'),
      'pipelines-empty-state-svg-path': image_path('illustrations/pipelines_empty.svg'),
      'switch-editor-svg-path': image_path('illustrations/rocket-launch-md.svg'),
      'promotion-svg-path': image_path('illustrations/web-ide_promotion.svg'),
      'ci-help-page-path' => help_page_path('ci/quick_start/index'),
      'web-ide-help-page-path' => help_page_path('user/project/web_ide/index.md'),
      'clientside-preview-enabled': Gitlab::CurrentSettings.web_ide_clientside_preview_enabled?.to_s,
      'render-whitespace-in-code': current_user.render_whitespace_in_code.to_s,
      'codesandbox-bundler-url': Gitlab::CurrentSettings.web_ide_clientside_preview_bundler_url,
      'default-branch' => @project && @project.default_branch,
      'project' => convert_to_project_entity_json(@project),
      'enable-environments-guidance' => enable_environments_guidance?.to_s,
      'preview-markdown-path' => @project && preview_markdown_path(@project),
      'web-terminal-svg-path' => image_path('illustrations/web-ide_promotion.svg'),
      'web-terminal-help-path' => help_page_path('user/project/web_ide/index.md', anchor: 'interactive-web-terminals-for-the-web-ide'),
      'web-terminal-config-help-path' => help_page_path('user/project/web_ide/index.md', anchor: 'web-ide-configuration-file'),
      'web-terminal-runners-help-path' => help_page_path('user/project/web_ide/index.md', anchor: 'runner-configuration')
    }
  end

  def convert_to_project_entity_json(project)
    return unless project

    API::Entities::Project.represent(project, current_user: current_user).to_json
  end

  def enable_environments_guidance?
    experiment(:in_product_guidance_environments_webide, project: @project) do |e|
      e.candidate { !has_dismissed_ide_environments_callout? }

      e.run
    end
  end

  def has_dismissed_ide_environments_callout?
    current_user.dismissed_callout?(feature_name: 'web_ide_ci_environments_guidance')
  end
end
