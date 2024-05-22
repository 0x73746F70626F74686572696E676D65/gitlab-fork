# frozen_string_literal: true

module Groups
  module DiscoversHelper
    include Gitlab::Utils::StrongMemoize

    def trial_discover_page_features
      [
        {
          icon: "epic",
          title: s_("TrialDiscoverPage|Epics"),
          description: s_("TrialDiscoverPage|Collaborate on high-level ideas that share a common theme. " \
                          "Use epics to group issues that cross milestones and projects."),
          plan: s_("TrialDiscoverPage|Premium"),
          doc_url: help_page_url("user/group/epics/index"),
          video_url: "https://vimeo.com/693759778",
          container_class: 'gl-flex-basis-third',
          description_class: 'gl-h-13',
          tracking_label: 'epics_feature'
        },
        {
          icon: "location",
          title: s_("TrialDiscoverPage|Roadmaps"),
          description: s_("TrialDiscoverPage|Visualize your epics and milestones in a timeline."),
          plan: s_("TrialDiscoverPage|Premium"),
          doc_url: help_page_url("user/group/roadmap/index"),
          video_url: "https://vimeo.com/670922063",
          container_class: 'gl-flex-basis-third',
          description_class: 'gl-h-13',
          tracking_label: 'roadmaps_feature'
        },
        {
          icon: "label",
          title: s_("TrialDiscoverPage|Scoped Labels"),
          description: s_("TrialDiscoverPage|Create a more advanced workflow for issues, merge requests, " \
                          "and epics by using scoped, mutually exclusive labels."),
          plan: s_("TrialDiscoverPage|Premium"),
          doc_url: help_page_url("user/project/labels", anchor: "scoped-labels"),
          video_url: "https://vimeo.com/670906315",
          container_class: 'gl-flex-basis-third',
          description_class: 'gl-h-13',
          tracking_label: 'scoped_labels_feature'
        },
        {
          icon: "merge-request",
          title: s_("TrialDiscoverPage|Merge request approval rule"),
          description: s_("TrialDiscoverPage|Maintain high quality code by requiring approval " \
                          "from specific users on your merge requests."),
          plan: s_("TrialDiscoverPage|Premium"),
          doc_url: help_page_url("user/project/merge_requests/approvals/rules"),
          video_url: "https://vimeo.com/670904904",
          container_class: 'gl-flex-basis-third',
          description_class: 'gl-h-13',
          tracking_label: 'merge_request_rule_feature'
        },
        {
          icon: "progress",
          title: s_("TrialDiscoverPage|Burn down charts"),
          description: s_("TrialDiscoverPage|Track your development progress by viewing issues in a burndown chart."),
          plan: s_("TrialDiscoverPage|Premium"),
          doc_url: help_page_url("user/project/milestones/burndown_and_burnup_charts"),
          video_url: "https://vimeo.com/670905639",
          container_class: 'gl-flex-basis-third',
          description_class: 'gl-h-13',
          tracking_label: 'burn_down_chart_feature'
        },
        {
          icon: "account",
          title: s_("TrialDiscoverPage|Code owners"),
          description: s_("TrialDiscoverPage|Target the right approvers for your merge request by assigning " \
                          "owners to specific files."),
          plan: s_("TrialDiscoverPage|Premium"),
          doc_url: help_page_url("user/project/codeowners/index"),
          video_url: "https://vimeo.com/670896787",
          container_class: 'gl-flex-basis-third',
          description_class: 'gl-h-13',
          tracking_label: 'code_owners_feature'
        },
        {
          icon: "chart",
          title: s_("TrialDiscoverPage|Code review analytics"),
          description: s_("TrialDiscoverPage|Find and fix bottlenecks in your code review process by understanding " \
                          "how long open merge requests have been in review."),
          plan: s_("TrialDiscoverPage|Premium"),
          doc_url: help_page_url("user/analytics/code_review_analytics"),
          video_url: "https://vimeo.com/670893940",
          container_class: 'gl-flex-basis-half',
          description_class: 'gl-h-10',
          tracking_label: 'code_review_feature'
        },
        {
          icon: "shield",
          title: s_("TrialDiscoverPage|Free guest users"),
          description: s_("TrialDiscoverPage|Let users view what GitLab has to offer without using a " \
                          "subscription seat."),
          plan: s_("TrialDiscoverPage|Ultimate"),
          doc_url: help_page_url("user/permissions"),
          calculator_url: "https://about.gitlab.com/pricing/ultimate/#wu-guest-calculator",
          container_class: 'gl-flex-basis-half',
          description_class: 'gl-h-10',
          tracking_label: 'free_guests_feature'
        },
        {
          icon: "shield",
          title: s_("TrialDiscoverPage|Dependency scanning"),
          description: s_("TrialDiscoverPage|Keep your application secure by checking your libraries for " \
                          "vulnerabilities."),
          plan: s_("TrialDiscoverPage|Ultimate"),
          doc_url: help_page_url("user/application_security/dependency_scanning/index"),
          video_url: "https://vimeo.com/670886968",
          container_class: 'gl-flex-basis-half',
          description_class: 'gl-h-10',
          tracking_label: 'dependency_scanning_feature'
        },
        {
          icon: "issue-type-test-case",
          title: s_("TrialDiscoverPage|Dynamic application security testing (DAST)"),
          description: s_("TrialDiscoverPage|Keep your application secure by checking your deployed environments " \
                          "for vulnerabilities."),
          plan: s_("TrialDiscoverPage|Ultimate"),
          doc_url: help_page_url("user/application_security/dast/index"),
          video_url: "https://vimeo.com/670891385",
          container_class: 'gl-flex-basis-half',
          description_class: 'gl-h-10',
          tracking_label: 'dast_feature'
        }
      ]
    end

    def trial_discover_page_details
      [
        {
          icon: "users",
          title: s_("TrialDiscoverPage|Collaboration made easy"),
          description: s_("TrialDiscoverPage|Break down silos to coordinate seamlessly across development, " \
                          "operations, and security with a consistent experience across the development lifecycle.")
        },
        {
          icon: "code",
          title: s_("TrialDiscoverPage|Lower cost of development"),
          description: s_("TrialDiscoverPage|A single application eliminates complex integrations, data " \
                          "checkpoints, and toolchain maintenance, resulting in greater productivity and lower cost.")
        },
        {
          icon: "deployments",
          title: s_("TrialDiscoverPage|Your software, deployed your way"),
          description: s_("TrialDiscoverPage|GitLab is infrastructure agnostic. GitLab supports GCP, AWS, " \
                          "OpenShift, VMware, on-premises, bare metal, and more.")

        }
      ]
    end

    def group_trial_status(group)
      strong_memoize_with(:group_trial_status, group) do
        group.trial_active? ? 'trial_active' : 'trial_expired'
      end
    end
  end
end
