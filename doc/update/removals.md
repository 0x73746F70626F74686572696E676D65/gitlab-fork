---
stage: none
group: none
info: "See the Technical Writers assigned to Development Guidelines: https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments-to-development-guidelines"
---

# Removals by version

In each release, GitLab removes features that were [deprecated](deprecations.md) in an earlier release.
Some features cause breaking changes when they are removed.

**{rss}** **To be notified of upcoming breaking changes**,
add this URL to your RSS feed reader: `https://about.gitlab.com/breaking-changes.xml`

<!-- vale off -->

<!--
DO NOT EDIT THIS PAGE DIRECTLY

This page is automatically generated from the YAML files in `/data/removals` by the rake task
located at `lib/tasks/gitlab/docs/compile_removals.rake`.

For removal authors (usually Product Managers and Engineering Managers):

- To add a removal, use the example.yml file in `/data/removals/templates` as a template.
- For more information about authoring removals, check the the removal item guidance:
  https://about.gitlab.com/handbook/marketing/blog/release-posts/#creating-a-removal-entry

For removal reviewers (Technical Writers only):

- To update the removal doc, run: `bin/rake gitlab:docs:compile_removals`
- To verify the removals doc is up to date, run: `bin/rake gitlab:docs:check_removals`
- For more information about updating the removal doc, see the removal doc update guidance:
  https://about.gitlab.com/handbook/marketing/blog/release-posts/#update-the-removals-doc
-->

{::options parse_block_html="true" /}

## Removed in 16.0

### Auto DevOps no longer provisions a database by default

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/343988).
</div>

Currently, Auto DevOps provisions an in-cluster PostgreSQL database by default.
In GitLab 16.0, databases will be provisioned only for users who opt in. This
change supports production deployments that require more robust database management.

If you want Auto DevOps to provision an in-cluster database,
set the `POSTGRES_ENABLED` CI/CD variable to `true`.

### Azure Storage Driver defaults to the correct root prefix

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/container-registry/-/issues/854).
</div>

The Azure Storage Driver used to write to `//` as the default root directory. This default root directory appeared in some places in the Azure UI as `/<no-name>/`. We maintained this legacy behavior to support older deployments using this storage driver. However, when moving to Azure from another storage driver, this behavior hides all your data until you configure the storage driver with `trimlegacyrootprefix: true` to build root paths without an extra leading slash.

In GitLab 16.0, the new default configuration for the storage driver uses `trimlegacyrootprefix: true`, and `/` is the default root directory. You can set your configuration to `trimlegacyrootprefix: false` if needed, to revert to the previous behavior.

### Bundled Grafana Helm Chart

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.10</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/charts/gitlab/-/issues/4353).
</div>

The Grafana Helm chart that was bundled with the GitLab Helm Chart is removed in the GitLab Helm Chart 7.0 release (releasing along with GitLab 16.0).

The `global.grafana.enabled` setting for the GitLab Helm Chart has also been removed alongside the Grafana Helm chart.

If you're using the bundled Grafana, you should switch to the [newer chart version from Grafana Labs](https://artifacthub.io/packages/helm/grafana/grafana)
or a Grafana Operator from a trusted provider.

In your new Grafana instance, you can [configure the GitLab provided Prometheus as a data source](https://docs.gitlab.com/ee/administration/monitoring/performance/grafana_configuration.html#integration-with-gitlab-ui)
and [connect Grafana to the GitLab UI](https://docs.gitlab.com/ee/administration/monitoring/performance/grafana_configuration.html#integration-with-gitlab-ui).

### CAS OmniAuth provider is removed

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.3</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/369127).
</div>

The `omniauth-cas3` gem that provides GitLab with the CAS OmniAuth provider is being removed. You can no longer authenticate into a GitLab instance through CAS. This gem sees very little use. [The gem](https://rubygems.org/gems/omniauth-cas3/) has not had a new release in almost 5 years, which means that its dependencies are out of date and required manual patching during GitLab's [upgrade to OmniAuth 2.0](https://gitlab.com/gitlab-org/gitlab/-/issues/30073).

### CiCdSettingsUpdate mutation renamed to ProjectCiCdSettingsUpdate

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.0</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/361801).
</div>

The `CiCdSettingsUpdate` mutation was renamed to `ProjectCiCdSettingsUpdate` in GitLab 15.0.
The `CiCdSettingsUpdate` mutation will be removed in GitLab 16.0.
Any user scripts that use the `CiCdSettingsUpdate` mutation must be updated to use `ProjectCiCdSettingsUpdate`
instead.

### Conan project-level search returns only project-specific results"

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/384455).
</div>

The [GitLab Conan repository](https://docs.gitlab.com/ee/user/packages/conan_repository/) supports the `conan search` command, but when searching a project-level endpoint, instance-level Conan packages could have been returned. This unintended functionality is removed in GitLab 16.0. The search endpoint for the project level now only returns packages from the target project.

### Configuring Redis config file paths using environment variables is no longer supported

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/388255).
</div>

You can no longer specify Redis configuration file locations
using the environment variables like `GITLAB_REDIS_CACHE_CONFIG_FILE` or
`GITLAB_REDIS_QUEUES_CONFIG_FILE`. Use the default
configuration file locations instead, for example `config/redis.cache.yml` or
`config/redis.queues.yml`.

### Container Registry pull-through cache is removed

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/container-registry/-/issues/937).
</div>

The Container Registry [pull-through cache](https://docs.docker.com/registry/recipes/mirror/) was deprecated in GitLab 15.8 and removed in GitLab 16.0. This feature is part of the upstream [Docker Distribution project](https://github.com/distribution/distribution) but we are removing that code in favor of the GitLab Dependency Proxy. Use the GitLab Dependency Proxy to proxy and cache container images from Docker Hub.

### Container Scanning variables that reference Docker removed

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.4</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/371840).
</div>

All Container Scanning variables with a name prefixed by `DOCKER_` have been removed. This includes:

- `DOCKER_IMAGE`
- `DOCKER_PASSWORD`
- `DOCKER_USER`
- `DOCKERFILE_PATH`

Instead, use the [new variable names](https://docs.gitlab.com/ee/user/application_security/container_scanning/#available-cicd-variables):

- `CS_IMAGE`
- `CS_REGISTRY_PASSWORD`
- `CS_REGISTRY_USER`
- `CS_DOCKERFILE_PATH`

### Dependency Scanning ends support for Java 13, 14, 15, and 16

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/387560).
</div>

Dependency Scanning no longer supports projects that use Java versions 13, 14, 15, and 16.

### Developer role providing the ability to import projects to a group

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/387891).
</div>

The ability for users with the Developer role for a group to import projects to that group was deprecated in GitLab
15.8 and is removed in GitLab 16.0.

From GitLab 16.0, only users with at least the Maintainer role for a group can import projects to that group.

### Embedding Grafana panels in Markdown is removed

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/389477).
</div>

The ability to add Grafana panels in GitLab Flavored Markdown is removed.
We intend to replace this feature with the ability to [embed charts](https://gitlab.com/groups/gitlab-org/opstrace/-/epics/33)
with the [GitLab Observability UI](https://gitlab.com/gitlab-org/opstrace/opstrace-ui).

### Enforced validation of CI/CD parameter character lengths

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/372770).
</div>

Previously, only CI/CD [job names](https://docs.gitlab.com/ee/ci/jobs/index.html#job-name-limitations) had a strict 255-character limit. Now, more CI/CD keywords are validated to ensure they stay under the limit.

The following to 255 characters are now strictly limited to 255 characters:

- The `stage` keyword.
- The `ref` parameter, which is the Git branch or tag name for the pipeline.
- The `description` and `target_url` parameters, used by external CI/CD integrations.

Users on self-managed instances should update their pipelines to ensure they do not use parameters that exceed 255 characters. Users on GitLab.com do not need to make any changes, as these parameters are already limited in that database.

### GitLab administrators must have permission to modify protected branches or tags

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">16.0</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/12776).
</div>

GitLab administrators can no longer perform actions on protected branches or tags unless they have been explicitly granted that permission. These actions include pushing and merging into a [protected branch](https://docs.gitlab.com/ee/user/project/protected_branches.html), unprotecting a branch, and creating [protected tags](https://docs.gitlab.com/ee/user/project/protected_tags.html).

### GitLab.com importer

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.8</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-com/Product/-/issues/4895).
</div>

The [GitLab.com importer](https://docs.gitlab.com/ee/user/project/import/gitlab_com.html) was deprecated in GitLab 15.8 and is removed in GitLab 16.0.

The GitLab.com importer was introduced in 2015 for importing a project from GitLab.com to a self-managed GitLab instance through the UI.

This feature was available on self-managed instances only. [Migrating GitLab groups and projects by direct transfer](https://docs.gitlab.com/ee/user/group/import/#migrate-groups-by-direct-transfer-recommended)
supersedes the GitLab.com importer and provides a more cohesive importing functionality.

See [migrated group items](https://docs.gitlab.com/ee/user/group/import/#migrated-group-items) and [migrated project items](https://docs.gitlab.com/ee/user/group/import/#migrated-project-items) for an overview.

### GraphQL API: Runner status no longer returns `PAUSED` and `ACTIVE` values

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/344648).
</div>

In GitLab 16.0 and later, the GraphQL query for runners will no longer return the statuses `PAUSED` and `ACTIVE`.

- `PAUSED` has been replaced with the field, `paused: true`.
- `ACTIVE` has been replaced with the field, `paused: false`.

### Jira DVCS connector for Jira Cloud and Jira 8.13 and earlier

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.1</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/362168).
</div>

The [Jira DVCS connector](https://docs.gitlab.com/ee/integration/jira/dvcs/) for Jira Cloud was deprecated in GitLab 15.1 and has been removed in 16.0. Use the [GitLab for Jira Cloud app](https://docs.gitlab.com/ee/integration/jira/connect-app.html) instead. The Jira DVCS connector was also deprecated for Jira 8.13 and earlier. You can only use the Jira DVCS connector with Jira Data Center or Jira Server in Jira 8.14 and later. Upgrade your Jira instance to Jira 8.14 or later, and reconfigure the Jira integration in your GitLab instance.
If you cannot upgrade your Jira instance in time and are on GitLab self-managed version, we offer a workaround until GitLab 16.6. This breaking change is deployed in GitLab 16.0 behind a feature flag named `jira_dvcs_end_of_life_amnesty`. The flag is disabled by default, but you can ask an administrator to enable the flag at any time. For questions related to this announcement, see the [feedback issue](https://gitlab.com/gitlab-org/gitlab/-/issues/408185).

### Legacy Gitaly configuration method

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.10</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/393574).
</div>

Previously, Gitaly configuration keys for Omnibus GitLab were scattered throughout the configuration file. In GitLab
15.10, we added support for a single configuration structure that matches Gitaly internal configuration. Both methods
of configuring Gitaly were supported in parallel.

In GitLab 16.0, we removed support for the former configuration method and now only support the new configuration
method.

Before upgrading to GitLab 16.0, administrators must migrate to the new single configuration structure. For
instructions, see [Gitaly - Omnibus GitLab configuration structure change](https://docs.gitlab.com/ee/update/#gitaly-omnibus-gitlab-configuration-structure-change).

### Legacy Gitaly configuration methods with variables

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/352609).
</div>

The environment variables `GIT_CONFIG_SYSTEM` and `GIT_CONFIG_GLOBAL` were deprecated in GitLab 14.8 and are removed
in GitLab 16.0. These variables are replaced with standard
[`config.toml` Gitaly configuration](https://docs.gitlab.com/ee/administration/gitaly/reference.html).

GitLab instances that use `GIT_CONFIG_SYSTEM` and `GIT_CONFIG_GLOBAL` to configure Gitaly must switch to configuring
using `config.toml`.

### Legacy Praefect configuration method

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/390291).
</div>

Previously, Praefect configuration keys for Omnibus GitLab were scattered throughout the configuration file. In GitLab
15.9, we added support for a single configuration structure that matches Praefect internal configuration. Both methods
of configuring Praefect were supported in parallel.

In GitLab 16.0, we removed support for the former configuration method and now only support the new configuration
method.

Before upgrading to GitLab 16.0, administrators must migrate to the new single configuration structure. For
instructions, see [Praefect - Omnibus GitLab configuration structure change](https://docs.gitlab.com/ee/update/#praefect-omnibus-gitlab-configuration-structure-change).

### Legacy routes removed

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/214217).
</div>

GitLab 16.0 removes legacy URLs from the GitLab application.

When subgroups were introduced in GitLab 9.0, a `/-/` delimiter was added to URLs to signify the end of a group path. All GitLab URLs now use this delimiter for project, group, and instance level features.

URLs that do not use the `/-/` delimiter are planned for removal in GitLab 16.0. For the full list of these URLs, along with their replacements, see [issue 28848](https://gitlab.com/gitlab-org/gitlab/-/issues/28848#release-notes).

Update any scripts or bookmarks that reference the legacy URLs. GitLab APIs are not affected by this change.

### License-Check and the Policies tab on the License Compliance page

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/390417).
</div>

The License Check Policies feature has been removed. Additionally, the Policies tab on the License Compliance page and all APIs related to the License Check feature have been removed. To enforce approvals based on detected licenses, use the [License Approval policy](https://docs.gitlab.com/ee/user/compliance/license_approval_policies.html) feature instead.

### Limit CI_JOB_TOKEN scope is disabled

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/395708).
</div>

In GitLab 14.4 we introduced the ability to [limit your project's CI/CD job token](https://docs.gitlab.com/ee/ci/jobs/ci_job_token.html#limit-your-projects-job-token-access) (`CI_JOB_TOKEN`) access to make it more secure. You could use the **Limit CI_JOB_TOKEN access** setting to prevent job tokens from your project's pipelines from being used to **access other projects**. When enabled with no other configuration, your pipelines could not access any other projects. To use job tokens to access other projects from your project's pipelines, you needed to list those other projects explicitly in the setting's allowlist, and you needed to be a maintainer in _all_ the projects. You might have seen this mentioned as the "outbound scope" of the job token.

The job token functionality was updated in 15.9 with a [better security setting](https://docs.gitlab.com/ee/ci/jobs/ci_job_token.html#allow-access-to-your-project-with-a-job-token). Instead of securing your own project's job tokens from accessing other projects, the new workflow is to secure your own project from being accessed by other projects' job tokens without authorization. You can see this as an "inbound scope" for job tokens. When this new **Allow access to this project with a CI_JOB_TOKEN** setting is enabled with no other configuration, job tokens from other projects cannot **access your project**. If you want a project to have access to your own project, you must list it in the new setting's allowlist. You must be a maintainer in your own project to control the new allowlist, but you only need to have the Guest role in the other projects. This new setting is enabled by default for all new projects.

In GitLab 16.0, the old **Limit CI_JOB_TOKEN access** setting is disabled by default for all **new** projects. In existing projects with this setting currently enabled, it will continue to function as expected, but you are unable to add any more projects to the old allowlist. If the setting is disabled in any project, it is not possible to re-enable this setting in 16.0 or later. To control access between your projects, use the new **Allow access** setting instead.

In 17.0, we plan to remove the **Limit** setting completely, and set the **Allow access** setting to enabled for all projects. This change ensures a higher level of security between projects. If you currently use the **Limit** setting, you should update your projects to use the **Allow access** setting instead. If other projects access your project with a job token, you must add them to the **Allow access** setting's allowlist.

To prepare for this change, users on GitLab.com or self-managed GitLab 15.9 or later can enable the **Allow access** setting now and add the other projects. It will not be possible to disable the setting in 17.0 or later.

### Managed Licenses API

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/390417).
</div>

The [Managed Licenses API](https://archives.docs.gitlab.com/15.8/ee/api/managed_licenses.html) has been removed. To enforce approvals in merge requests when non-compliant licenses are detected, use the [License Approval policy](https://docs.gitlab.com/ee/user/compliance/license_approval_policies.html) feature instead.

Our [GraphQL APIs](https://docs.gitlab.com/ee/api/graphql/reference/) can be used to create a Security Policy Project, [update the policy.yml](https://docs.gitlab.com/ee/api/graphql/reference/#mutationscanexecutionpolicycommit) in the Security Policy Project, and enforce those policies.

To query a list of dependencies and components, use our [Dependencies REST API](https://docs.gitlab.com/ee/api/dependencies.html) or [export from the Dependency List](https://docs.gitlab.com/ee/user/application_security/dependency_list/).

### Maximum number of active pipelines per project limit (`ci_active_pipelines`)

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.3</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/368195).
</div>

The [**Maximum number of active pipelines per project** limit](https://docs.gitlab.com/ee/user/admin_area/settings/continuous_integration.html#set-cicd-limits) has been removed. Instead, use the other recommended rate limits that offer similar protection:

- [**Pipelines rate limits**](https://docs.gitlab.com/ee/user/admin_area/settings/rate_limit_on_pipelines_creation.html).
- [**Total number of jobs in currently active pipelines**](https://docs.gitlab.com/ee/user/admin_area/settings/continuous_integration.html#set-cicd-limits).

### Monitoring performance metrics through Prometheus is removed

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.7</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/346541).
</div>

We previously launched a solution that allows you to view performance metrics by displaying data stored in a Prometheus instance.
The Prometheus instance can be set up as a GitLab-managed app or you can connect a previously configured Prometheus instance.
The latter is known as an "external Prometheus" in GitLab. The value we provided was to enable you to easily set up monitoring
(using GitLab Managed Apps) and have the visualization of the metrics all in the same tool you used to build the application.

However, as we are removing certificate-based integrations, the full monitoring experience is also deprecated as you will not
have the option to easily set up Prometheus from GitLab. Furthermore, we plan to consolidate on
a focused observability dashboard experience instead of having multiple paths to view metrics. Because of this, we are also removing the external
Prometheus experience, together with the metrics visualization capability.

This removal only refers to the GitLab Metrics capabilities, and **does not** include:

- Deprecating [alerts for Prometheus](https://gitlab.com/gitlab-org/gitlab/-/issues/338834).
- [Capabilities that GitLab comes with that allow operators of GitLab to retrieve metrics from those instances](https://docs.gitlab.com/ee/administration/monitoring/prometheus/gitlab_metrics.html).

### Non-expiring access tokens no longer supported

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.4</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/369123).
</div>

Currently, you can create access tokens that have no expiration date. These access tokens are valid indefinitely, which presents a security risk if the access token is
divulged. Because expiring access tokens are better, from GitLab 15.4 we [populate a default expiration date](https://gitlab.com/gitlab-org/gitlab/-/issues/348660).

In GitLab 16.0, any personal, project, or group access token that does not have an expiration date will automatically have an expiration date set at 365 days later than the current date.

### Non-standard default Redis ports are no longer supported

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/388269).
</div>

If GitLab starts without any Redis configuration file present,
GitLab assumes it can connect to three Redis servers at `localhost:6380`,
`localhost:6381` and `localhost:6382`. We are changing this behavior
so GitLab assumes there is one Redis server at `localhost:6379`.

If you want to keep using the three servers, you must configure
the Redis URLs by editing the `config/redis.cache.yml`,`config/redis.queues.yml`,
and `config/redis.shared_state.yml` files.

### PipelineSecurityReportFinding name GraphQL field

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.1</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/346335).
</div>

Previously, the [PipelineSecurityReportFinding GraphQL type was updated](https://gitlab.com/gitlab-org/gitlab/-/issues/335372) to include a new `title` field. This field is an alias for the current `name` field, making the less specific `name` field redundant. The `name` field is removed from the PipelineSecurityReportFinding type in GitLab 16.0.

### PostgreSQL 12 compatibility

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.0</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/omnibus-gitlab/-/issues/7395).
</div>

In GitLab 16.0, PostgreSQL 13 is the minimum supported PostgreSQL version. PostgreSQL 12 is no longer shipped with the GitLab Omnibus package.
Before upgrading to GitLab 16.0, if you are:

- Still using GitLab-packaged PostgreSQL 12, you must [perform a database upgrade](https://docs.gitlab.com/omnibus/settings/database.html#upgrade-packaged-postgresql-server)
  to PostgreSQL 13.
- Using an externally-provided PostgreSQL 12, you must upgrade to PostgreSQL 13 or later to meet the
  [minimum version requirements](https://docs.gitlab.com/ee/install/requirements.html#postgresql-requirements).

### Praefect custom metrics endpoint configuration

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/390266).
</div>

Support for using the `prometheus_exclude_database_from_default_metrics` configuration value was deprecated in
GitLab 15.9 and is removed in GitLab 16.0. We made this change to improve the performance of Praefect.
All metrics that scrape the Praefect database are now exported to the `/db_metrics` endpoint.

You must update your metrics collection targets to use the `/db_metrics` endpoint.

### Project REST API field `operations_access_level` removed

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/385798).
</div>

In project REST API endpoints, the `operations_access_level` field
is removed in favor of more specialized fields like:

- `releases_access_level`
- `environments_access_level`
- `feature_flags_access_level`
- `infrastructure_access_level`
- `monitor_access_level`

### Rake task for importing bare repositories

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.8</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-com/Product/-/issues/5255).
</div>

The [Rake task for importing bare repositories](https://docs.gitlab.com/ee/raketasks/import.html) `gitlab:import:repos` was deprecated in GitLab 15.8 and is removed in GitLab 16.0.

This Rake task imported a directory tree of repositories into a GitLab instance. These repositories must have been
managed by GitLab previously, because the Rake task relied on the specific directory structure or a specific custom Git setting in order to work (`gitlab.fullpath`).

Importing repositories using this Rake task had limitations. The Rake task:

- Only knew about project and project wiki repositories and didn't support repositories for designs, group wikis, or snippets.
- Permitted you to import non-hashed storage projects even though these aren't supported.
- Relied on having Git config `gitlab.fullpath` set. [Epic 8953](https://gitlab.com/groups/gitlab-org/-/epics/8953) proposes removing support for this setting.

Alternatives to using the `gitlab:import:repos` Rake task include:

- Migrating projects using either [an export file](https://docs.gitlab.com/ee/user/project/settings/import_export.html) or
  [direct transfer](https://docs.gitlab.com/ee/user/group/import/#migrate-groups-by-direct-transfer-recommended) migrate repositories as well.
- Importing a [repository by URL](https://docs.gitlab.com/ee/user/project/import/repo_by_url.html).
- Importing a [repositories from a non-GitLab source](https://docs.gitlab.com/ee/user/project/import/).

### Redis 5 compatibility

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.3</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/331468).
</div>

In GitLab 13.9, we updated the Omnibus GitLab package and GitLab Helm chart 4.9 to Redis 6. Redis 5 reached end of life in April 2022 and is not supported.

GitLab 16.0, we have removed support for Redis 5. If you are using your own Redis 5.0 instance, you must upgrade it to Redis 6.0 or later before upgrading to GitLab 16.0
or later.

### Removal of job_age parameter in `POST /jobs/request` Runner endpoint

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.2</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/334253).
</div>

The `job_age` parameter, returned from the `POST /jobs/request` API endpoint used in communication with GitLab Runner, has been removed in GitLab 16.0.

This could be a breaking change for anyone that developed their own runner that relies on this parameter being returned by the endpoint. This is not a breaking change for anyone using an officially released version of GitLab Runner, including public shared runners on GitLab.com.

### Remove legacy configuration fields in GitLab Runner Helm Chart

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.6</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/379064).
</div>

In GitLab 13.6 and later, users can [specify any runner configuration in the GitLab Runner Helm chart](https://docs.gitlab.com/runner/install/kubernetes.html). When this features was released, we deprecated the fields in the GitLab Helm Chart configuration specific to the runner. As of v1.0 of the GitLab Runner Helm chart (GitLab 16.0), the following fields have been removed and are no longer supported:

- `image`
- `rbac.resources`
- `rbac.verbs`
- `runners.image`
- `runners.imagePullSecrets`
- `runners.imagePullPolicy`
- `runners.requestConcurrency`
- `runners.privileged`
- `runners.namespace`
- `runners.pollTimeout`
- `runners.outputLimit`
- `runners.cache.cacheType`
- `runners.cache.cachePath`
- `runners.cache.cacheShared`
- `runners.cache.s3ServerAddress`
- `runners.cache.s3BucketLocation`
- `runners.cache.s3CacheInsecure`
- `runners.cache.gcsBucketName`
- `runners.builds`
- `runners.services`
- `runners.helpers`
- `runners.pod_security_context`
- `runners.serviceAccountName`
- `runners.cloneUrl`
- `runners.nodeSelector`
- `runners.nodeTolerations`
- `runners.podLabels`
- `runners.podAnnotations`
- `runners.env`

### Remove the deprecated `environment_tier` parameter from the DORA API

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.2</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/365939).
</div>

The `environment_tier` parameter has been superseded by the `environment_tiers` parameter.

If you use the `environment_tier` parameter in your integration (REST or GraphQL) then you need to replace it with the `environment_tiers` parameter which accepts an array of strings.

### Removed `external` field from GraphQL `ReleaseAssetLink` type

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/388983).
</div>

From GitLab 15.9, all Release links are external. The `external` field of the `ReleaseAssetLink` type was deprecated in 15.9, and removed in GitLab 16.0.

### Removed `external` field from Releases and Release link APIs

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/388984).
</div>

From GitLab 15.9, all Release links are external. The `external` field in the Releases and Release link APIs was deprecated in 15.9, and removed in GitLab 16.0.

### Security report schemas version 14.x.x

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.3</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/366477).
</div>

Version 14.x.x [security report schemas](https://gitlab.com/gitlab-org/security-products/security-report-schemas) have been removed.
Security reports that use schema version 14.x.x will cause an error in the pipeline's **Security** tab. For more information, refer to [security report validation](https://docs.gitlab.com/ee/user/application_security/#security-report-validation).

### Self-monitoring project is removed

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/groups/gitlab-org/-/epics/10030).
</div>

GitLab self-monitoring project was meant to enable self-hosted GitLab administrators to visualize performance metrics of GitLab within GitLab itself. This feature relied on GitLab Metrics dashboards. With metrics dashboard being removed, self-monitoring project is also removed. We recommended that self-hosted users monitor their GitLab instance with alternative visualization tools, such as Grafana.

### Starboard directive in the config for the GitLab agent for Kubernetes removed

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.4</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/368828).
</div>

The GitLab operational container scanning feature no longer requires you to install Starboard. The `starboard:` directive in configuration files for the GitLab agent for Kubernetes has been removed. Use the `container_scanning:` directive instead.

### Stop publishing GitLab Runner images based on Windows Server 2004 and 20H2

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">16.0</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/31001).
</div>

As of GitLab 16.0, GitLab Runner images based on Windows Server 2004 and 20H2 will not be provided as these operating systems are end-of-life.

### The Phabricator task importer

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.7</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-com/Product/-/issues/4894).
</div>

The [Phabricator task importer](https://docs.gitlab.com/ee/user/project/import/phabricator.html) was deprecated in
GitLab 15.7 and is removed in 16.0.

The Phabricator project hasn't been actively maintained since June 1, 2021. We haven't observed imports using this
tool. There has been no activity on the open related issues on GitLab.

### The Security Code Scan-based GitLab SAST analyzer is now removed

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/390416).
</div>

GitLab SAST uses various [analyzers](https://docs.gitlab.com/ee/user/application_security/sast/analyzers/) to scan code for vulnerabilities.
We've reduced the number of supported analyzers used by default in GitLab SAST.
This is part of our long-term strategy to deliver a faster, more consistent user experience across different programming languages.

As of GitLab 16.0, the [SAST CI/CD template](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Security/SAST.gitlab-ci.yml) no longer uses the [Security Code Scan](https://gitlab.com/gitlab-org/security-products/analyzers/security-code-scan)-based analyzer for .NET.
We've removed this analyzer from the SAST CI/CD template and replaced it with GitLab-supported detection rules for C# in the [Semgrep-based analyzer](https://gitlab.com/gitlab-org/security-products/analyzers/semgrep).

Because this analyzer has reached End of Support in GitLab 16.0, we won't provide further updates to it.
However, we won't delete any container images we previously published for this analyzer or remove the ability to run it by using a [custom CI/CD pipeline job](https://docs.gitlab.com/ee/ci/yaml/artifacts_reports.html#artifactsreportssast).

If you've already dismissed a vulnerability finding from the deprecated analyzer, the replacement attempts to respect your previous dismissal. See [Vulnerability translation documentation](https://docs.gitlab.com/ee/user/application_security/sast/analyzers.html#vulnerability-translation) for further details.

If you customize the behavior of GitLab SAST by disabling the Semgrep-based analyzer or depending on specific SAST jobs in your pipelines, you must take action as detailed in the [deprecation issue for this change](https://gitlab.com/gitlab-org/gitlab/-/issues/390416#actions-required).

### The stable Terraform CI/CD template has been replaced with the latest template

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/386001).
</div>

With every major GitLab version, we update the stable Terraform templates with the current latest templates.
This change affects the [quickstart](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Terraform.gitlab-ci.yml)
and the [base](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Terraform/Base.gitlab-ci.yml) templates.

The new templates do not change the directory to `$TF_ROOT` explicitly: `gitlab-terraform` gracefully
handles directory changing. If you altered the job scripts to assume that the current working directory is `$TF_ROOT`, you must manually add `cd "$TF_ROOT"` now.

Because the latest template introduces Merge Request Pipeline support which is not supported in Auto DevOps,
those rules are not yet integrated into the stable template.
However, we may introduce them later on, which may break your Terraform pipelines in regards to which jobs are executed.

To accommodate the changes, you might need to adjust the [`rules`](https://docs.gitlab.com/ee/ci/yaml/#rules) in your
`.gitlab-ci.yml` file.

### Two DAST API variables have been removed

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.7</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/383467).
</div>

The variables `DAST_API_HOST_OVERRIDE` and `DAST_API_SPECIFICATION` have been removed from use for DAST API scans.

`DAST_API_HOST_OVERRIDE` has been removed in favor of using the `DAST_API_TARGET_URL` to automatically override the host in the OpenAPI specification.

`DAST_API_SPECIFICATION` has been removed in favor of `DAST_API_OPENAPI`. To continue using an OpenAPI specification to guide the test, users must replace the `DAST_API_SPECIFICATION` variable with the `DAST_API_OPENAPI` variable. The value can remain the same, but the variable name must be replaced.

### Use of `id` field in vulnerabilityFindingDismiss mutation

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.3</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/367166).
</div>

You can use the vulnerabilityFindingDismiss GraphQL mutation to set the status of a vulnerability finding to `Dismissed`. Previously, this mutation used the `id` field to identify findings uniquely. However, this did not work for dismissing findings from the pipeline security tab. Therefore, using the `id` field as an identifier has been dropped in favor of the `uuid` field. Using the 'uuid' field as an identifier allows you to dismiss the finding from the pipeline security tab.

### Vulnerability confidence field

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.4</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/372332).
</div>

In GitLab 15.3, [security report schemas below version 15 were deprecated](https://docs.gitlab.com/ee/update/deprecations.html#security-report-schemas-version-14xx).
The `confidence` attribute on vulnerability findings exists only in schema versions before `15-0-0` and in GitLab prior to 15.4.  To maintain consistency
between the reports and our public APIs, the `confidence` attribute on any vulnerability-related components of our GraphQL API is now removed.

### `CI_BUILD_*` predefined variables removed

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/352957).
</div>

The predefined CI/CD variables that start with `CI_BUILD_*` were deprecated in GitLab 9.0, and removed in GitLab 16.0. If you still use these variables, you must change to the replacement [predefined variables](https://docs.gitlab.com/ee/ci/variables/predefined_variables.html) which are functionally identical:

| Removed variable      | Replacement variable    |
| --------------------- |------------------------ |
| `CI_BUILD_BEFORE_SHA` | `CI_COMMIT_BEFORE_SHA`  |
| `CI_BUILD_ID`         | `CI_JOB_ID`             |
| `CI_BUILD_MANUAL`     | `CI_JOB_MANUAL`         |
| `CI_BUILD_NAME`       | `CI_JOB_NAME`           |
| `CI_BUILD_REF`        | `CI_COMMIT_SHA`         |
| `CI_BUILD_REF_NAME`   | `CI_COMMIT_REF_NAME`    |
| `CI_BUILD_REF_SLUG`   | `CI_COMMIT_REF_SLUG`    |
| `CI_BUILD_REPO`       | `CI_REPOSITORY_URL`     |
| `CI_BUILD_STAGE`      | `CI_JOB_STAGE`          |
| `CI_BUILD_TAG`        | `CI_COMMIT_TAG`         |
| `CI_BUILD_TOKEN`      | `CI_JOB_TOKEN`          |
| `CI_BUILD_TRIGGERED`  | `CI_PIPELINE_TRIGGERED` |

### `POST ci/lint` API endpoint removed

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.7</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/381669).
</div>

The `POST ci/lint` API endpoint was deprecated in 15.7, and removed in 16.0. This endpoint did not validate the full range of CI/CD configuration options. Instead, use [`POST /projects/:id/ci/lint`](https://docs.gitlab.com/ee/api/lint.html#validate-a-ci-yaml-configuration-with-a-namespace), which properly validates CI/CD configuration.

### vulnerabilityFindingDismiss GraphQL mutation

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.5</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/375645).
</div>

The `VulnerabilityFindingDismiss` GraphQL mutation has been removed. This mutation was not used often as the Vulnerability Finding ID was not available to users (this field was [deprecated in 15.3](https://docs.gitlab.com/ee/update/deprecations.html#use-of-id-field-in-vulnerabilityfindingdismiss-mutation)). Instead of `VulnerabilityFindingDismiss`, you should use `VulnerabilityDismiss` to dismiss vulnerabilities in the Vulnerability Report or `SecurityFindingDismiss` for security findings in the CI Pipeline Security tab.

## Removed in 15.11

### Exporting and importing projects in JSON format not supported

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.10</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/389888).
</div>

GitLab previously created project file exports in JSON format. In GitLab 12.10, NDJSON was added as the preferred format.

To support transitions, importing JSON-formatted project file exports was still possible if you configured the
relevant feature flags.

From GitLab 15.11, importing a JSON-formatted project file exports is not supported.

### openSUSE Leap 15.3 packages

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.8</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/omnibus-gitlab/-/issues/7371).
</div>

Distribution support and security updates for openSUSE Leap 15.3 [ended December 2022](https://en.opensuse.org/Lifetime#Discontinued_distributions).

Starting in GitLab 15.7 we started providing packages for openSUSE Leap 15.4, and in GitLab 15.11 we stopped providing packages for openSUSE Leap 15.3.

To continue using GitLab, [upgrade](https://en.opensuse.org/SDB:System_upgrade) to openSUSE Leap 15.4.

## Removed in 15.9

### Live Preview no longer available in the Web IDE

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/383889).
</div>

The Live Preview feature of the Web IDE was intended to provide a client-side preview of static web applications. However, complex configuration steps and a narrow set of supported project types have limited its utility. With the introduction of the Web IDE Beta in GitLab 15.7, you can now connect to a full server-side runtime environment. With upcoming support for installing extensions in the Web IDE, we’ll also support more advanced workflows than those available with Live Preview. As of GitLab 15.9, Live Preview is no longer available in the Web IDE.

### `omniauth-authentiq` gem no longer available

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/389452).
</div>

`omniauth-authentiq` is an OmniAuth strategy gem that was part of GitLab. The company providing authentication services, Authentiq, has shut down. Therefore the gem is being removed.

### `omniauth-shibboleth` gem no longer available

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">10.0</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/388959).
</div>

`omniauth-shibboleth` is an OmniAuth strategy gem that was part of GitLab. The gem has not received security updates and does not meet GitLab quality guidance criteria. This gem was originally scheduled for removal by 14.1, but it was not removed at that time. The gem is being removed now.

## Removed in 15.8

### CiliumNetworkPolicy within the auto deploy Helm chart is removed

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/382044).
</div>

All functionality related to the GitLab Container Network Security and Container Host Security categories was deprecated in GitLab 14.8 and scheduled for removal in GitLab 15.0. The [CiliumNetworkPolicy definition](https://gitlab.com/gitlab-org/cluster-integration/auto-deploy-image/-/blob/master/assets/auto-deploy-app/values.yaml#L175) that exists as part of the [GitLab Auto Deploy Helm chart](https://gitlab.com/gitlab-org/cluster-integration/auto-deploy-image/-/tree/master/assets/auto-deploy-app) was not removed as scheduled in GitLab 15.0. This policy is planned to be removed in the GitLab 15.8 release.

If you want to preserve this functionality, you can follow one of these two paths:

1. Fork the [GitLab Auto Deploy Helm chart](https://gitlab.com/gitlab-org/cluster-integration/auto-deploy-image/-/tree/master/assets/auto-deploy-app) into the `chart/` path within your project
1. Set `AUTO_DEPLOY_IMAGE_VERSION` and `DAST_AUTO_DEPLOY_IMAGE_VERSION` to the most recent version of the image that included the CiliumNetworkPolicy

### Exporting and importing groups in JSON format not supported

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.10</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/389888).
</div>

GitLab previously created group file exports in JSON format. In GitLab 13.10, NDJSON was added as the preferred format.

To support transitions, importing JSON-formatted group file exports was still possible if you configured the
relevant feature flags.

From GitLab 15.8, importing a JSON-formatted group file exports is not supported.

### `artifacts:public` CI/CD keyword refactored

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.10</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/322454).
</div>

The [`artifacts:public` CI/CD keyword](https://docs.gitlab.com/ee/ci/yaml/#artifactspublic) was discovered to be not working properly since GitLab 15.8 and needed to be refactored. This feature is disabled on GitLab.com, and disabled by default on self-managed instances. If an administrator for an instance running GitLab 15.8 or 15.9 enabled this feature via the `non_public_artifacts` feature flag, it is likely that artifacts created with the `public:false` setting are being treated as `public:true`.

If you have projects that use this setting, you should delete artifacts that must not be public, or [change the visibility](https://docs.gitlab.com/ee/user/public_access.html#change-project-visibility) of affected projects to private, before updating to GitLab 15.8 or later.

In GitLab 15.10, this feature's code was refactored. On instances with this feature enabled, new artifacts created with `public:false` are now working as expected, though still disabled by default. Avoid testing this feature with production data until it is enabled by default and made generally available.

## Removed in 15.7

### File Type variable expansion in `.gitlab-ci.yml`

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.5</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/29407).
</div>

Prior to this change, variables that referenced or applied alias file variables expanded the value of the `File` type variable. For example, the file contents. This behavior was incorrect because it did not comply with typical shell variable expansion rules. A user could run an $echo command with the variable as an input parameter to leak secrets or sensitive information stored in 'File' type variables.

In 15.7, we are removing file type variable expansion from GitLab. It is essential to check your CI pipelines to confirm if your scripts reference a file variable. If your CI job relies on the previous expansion functionality, that CI job will not work and generate an error as of 15.7.  The new behavior is that variable expansion that reference or apply alias file variables expand to the file name or path of the `File` type variable, instead of its value, such as the file contents.

### Flowdock integration

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.7</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/379197).
</div>

As of December 22, 2022, we are removing the Flowdock integration because the service was shut down on August 15, 2022.

## Removed in 15.6

### NFS as Git repository storage is no longer supported

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.0</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/351243).
</div>

As of November 22, 2022, we have removed support for customers using NFS for Git repository storage. This was
originally planned for May 22, 2022, but in an effort to allow continued maturity of Gitaly Cluster, we delayed
our removal of support date until now. Please see our official [Statement of Support](https://about.gitlab.com/support/statement-of-support/#gitaly-and-nfs)
for further information.

This change in support follows the development deprecation for NFS for Git repository storage that occurred in GitLab 14.0.

Gitaly Cluster offers tremendous benefits for our customers such as:

- [Variable replication factors](https://docs.gitlab.com/ee/administration/gitaly/index.html#replication-factor).
- [Strong consistency](https://docs.gitlab.com/ee/administration/gitaly/index.html#strong-consistency).
- [Distributed read capabilities](https://docs.gitlab.com/ee/administration/gitaly/index.html#distributed-reads).

We encourage customers currently using NFS for Git repositories to migrate as soon as possible by reviewing our documentation on
[migrating to Gitaly Cluster](https://docs.gitlab.com/ee/administration/gitaly/index.html#migrate-to-gitaly-cluster).

## Removed in 15.4

### SAST analyzer consolidation and CI/CD template changes

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/352554).
</div>

We have replaced the GitLab SAST [analyzers](https://docs.gitlab.com/ee/user/application_security/sast/analyzers/) for certain languages in GitLab 15.4 as part of our long-term strategy to deliver a more consistent user experience, faster scan times, and reduced CI minute usage.

Starting from GitLab 15.4, the [GitLab-managed SAST CI/CD template](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Security/SAST.gitlab-ci.yml) uses [Semgrep-based scanning](https://docs.gitlab.com/ee/user/application_security/sast/analyzers.html#transition-to-semgrep-based-scanning) instead of the following analyzers:

- [ESLint](https://gitlab.com/gitlab-org/security-products/analyzers/eslint) for JavaScript, TypeScript, React
- [Gosec](https://gitlab.com/gitlab-org/security-products/analyzers/gosec) for Go
- [Bandit](https://gitlab.com/gitlab-org/security-products/analyzers/bandit) for Python
- [SpotBugs](https://gitlab.com/gitlab-org/security-products/analyzers/spotbugs) for Java

We will no longer make any updates to the ESLint-, Gosec-, and Bandit-based analyzers.
The SpotBugs-based analyzer will continue to be used for Groovy, Kotlin, and Scala scanning.

We won't delete container images previously published for these analyzers, so older versions of the CI/CD template will continue to work.

If you changed the default GitLab SAST configuration, you may need to update your configuration as detailed in the [deprecation issue for this change](https://gitlab.com/gitlab-org/gitlab/-/issues/352554#actions-required).

## Removed in 15.3

### Support for Debian 9

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
</div>

Long term service and support (LTSS) for [Debian 9 Stretch ended in July 2022](https://wiki.debian.org/LTS). Therefore, we will no longer support the Debian 9 distribution for the GitLab package. Users can upgrade to Debian 10 or Debian 11.

### Vulnerability Report sort by State

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.0</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/360516).
</div>

The ability to sort the Vulnerability Report by the `State` column was disabled and put behind a feature flag in GitLab 14.10 due to a refactor
of the underlying data model. The feature flag has remained off by default as further refactoring will be required to ensure sorting
by this value remains performant. Due to very low usage of the `State` column for sorting, the feature flag is instead removed in 15.3 to simplify the codebase and prevent any unwanted performance degradation.

### Vulnerability Report sort by Tool

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">15.1</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/363138).
</div>

The ability to sort the Vulnerability Report by the `Tool` column (scan type) was disabled and put behind a feature flag in GitLab 14.10 due to a refactor
of the underlying data model. The feature flag has remained off by default as further refactoring will be required to ensure sorting
by this value remains performant. Due to very low usage of the `Tool` column for sorting, the feature flag is instead removed in
GitLab 15.3 to simplify the codebase and prevent any unwanted performance degradation.

## Removed in 15.2

### Support for older browsers

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
</div>

In GitLab 15.2, we are cleaning up and [removing old code](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/86003) that was specific for browsers that we no longer support. This has no impact on users if they use one of our [supported web browsers](https://docs.gitlab.com/ee/install/requirements.html#supported-web-browsers).

Most notably, support for the following browsers has been removed:

- Apple Safari 14 and older.
- Mozilla Firefox 78.

The minimum supported browser versions are:

- Apple Safari 14.1.
- Mozilla Firefox 91.
- Google Chrome 92.
- Chromium 92.
- Microsoft Edge 92.

## Removed in 15.0

### API: `stale` status returned instead of `offline` or `not_connected`

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.6</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/347303).
</div>

The Runner [API](https://docs.gitlab.com/ee/api/runners.html#runners-api) endpoints have changed in 15.0.

If a runner has not contacted the GitLab instance in more than three months, the API returns `stale` instead of `offline` or `not_connected`.
The `stale` status was introduced in 14.6.

The `not_connected` status is no longer valid. It was replaced with `never_contacted`. Available statuses are `online`, `offline`, `stale`, and `never_contacted`.

### Audit events for repository push events

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.3</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/337993).
</div>

Audit events for [repository events](https://docs.gitlab.com/ee/administration/audit_events.html#removed-events) are removed as of GitLab 15.0.

Audit events for repository events were always disabled by default and had to be manually enabled with a feature flag.
Enabling them could slow down GitLab instances by generating too many events. Therefore, they are removed.

Please note that we will add high-volume audit events in the future as part of [streaming audit events](https://docs.gitlab.com/ee/administration/audit_event_streaming.html). An example of this is how we will send [Git fetch actions](https://gitlab.com/gitlab-org/gitlab/-/issues/343984) as a streaming audit event. If you would be interested in seeing repository push events or some other action as a streaming audit event, please reach out to us!

### Background upload for object storage

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/26600).
</div>

To reduce the overall complexity and maintenance burden of GitLab's [object storage feature](https://docs.gitlab.com/ee/administration/object_storage.html), support for using `background_upload` has been removed in GitLab 15.0.
By default [direct upload](https://docs.gitlab.com/ee/development/uploads/index.html#direct-upload) will be used.

This impacts a subset of object storage providers, including but not limited to:

- **OpenStack** Customers using OpenStack need to change their configuration to use the S3 API instead of Swift.
- **RackSpace** Customers using RackSpace-based object storage need to migrate data to a different provider.

If your object storage provider does not support `background_upload`, please [migrate objects to a supported object storage provider](https://docs.gitlab.com/ee/administration/object_storage.html#migrate-objects-to-a-different-object-storage-provider).

#### Encrypted S3 buckets

Additionally, this also breaks the use of [encrypted S3 buckets](https://docs.gitlab.com/ee/administration/object_storage.html#encrypted-s3-buckets) with [storage-specific configuration form](https://docs.gitlab.com/ee/administration/object_storage.html#configure-each-object-type-to-define-its-own-storage-connection-storage-specific-form).

If your S3 buckets have [SSE-S3 or SSE-KMS encryption enabled](https://docs.aws.amazon.com/kms/latest/developerguide/services-s3.html), please [migrate your configuration to use consolidated object storage form](https://docs.gitlab.com/ee/administration/object_storage.html#transition-to-consolidated-form) before upgrading to GitLab 15.0. Otherwise, you may start getting `ETag mismatch` errors during objects upload.

#### 403 errors

If you see 403 errors when uploading to object storage after
upgrading to GitLab 15.0, check that the [correct permissions](https://docs.gitlab.com/ee/administration/object_storage.html#iam-permissions)
are assigned to the bucket. Direct upload needs the ability to delete an
object (example: `s3:DeleteObject`), but background uploads do not.

#### `remote_directory` with a path prefix

If the object storage `remote_directory` configuration contains a slash (`/`) after the bucket (example: `gitlab/uploads`), be aware that this [was never officially supported](https://gitlab.com/gitlab-org/gitlab/-/issues/292958).
Some users found that they could specify a path prefix to the bucket. In direct upload mode, object storage uploads will fail if a slash is present in GitLab 15.0.

If you have set a prefix, you can use a workaround to revert to background uploads:

1. Continue to use [storage-specific configuration](https://docs.gitlab.com/ee/administration/object_storage.html#configure-each-object-type-to-define-its-own-storage-connection-storage-specific-form).
1. In Omnibus GitLab, set the `GITLAB_LEGACY_BACKGROUND_UPLOADS` to re-enable background uploads:

    ```ruby
    gitlab_rails['env'] = { 'GITLAB_LEGACY_BACKGROUND_UPLOADS' => 'artifacts,external_diffs,lfs,uploads,packages,dependency_proxy,terraform_state,pages' }
    ```

Support for prefixes was restored in GitLab 15.2 via [this MR](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/91307).
Support for setting `GITLAB_LEGACY_BACKGROUND_UPLOADS` will be removed in GitLab 15.4.

### Container Network and Host Security

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/groups/gitlab-org/-/epics/7477).
</div>

All functionality related to the Container Network Security and Container Host Security categories was deprecated in GitLab 14.8 and is scheduled for removal in GitLab 15.0. Users who need a replacement for this functionality are encouraged to evaluate the following open source projects as potential solutions that can be installed and managed outside of GitLab: [AppArmor](https://gitlab.com/apparmor/apparmor), [Cilium](https://github.com/cilium/cilium), [Falco](https://github.com/falcosecurity/falco), [FluentD](https://github.com/fluent/fluentd), [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/). To integrate these technologies with GitLab, add the desired Helm charts in your copy of the [Cluster Management Project Template](https://docs.gitlab.com/ee/user/clusters/management_project_template.html). Deploy these Helm charts in production by calling commands through GitLab [CI/CD](https://docs.gitlab.com/ee/user/clusters/agent/ci_cd_workflow.html).

As part of this change, the following capabilities within GitLab are scheduled for removal in GitLab 15.0:

- The **Security & Compliance > Threat Monitoring** page.
- The Network Policy security policy type, as found on the **Security & Compliance > Policies** page.
- The ability to manage integrations with the following technologies through GitLab: AppArmor, Cilium, Falco, FluentD, and Pod Security Policies.
- All APIs related to the above functionality.

For additional context, or to provide feedback regarding this change, please reference our [deprecation issue](https://gitlab.com/groups/gitlab-org/-/epics/7476).

### Container registry authentication with htpasswd

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

The Container Registry supports [authentication](https://gitlab.com/gitlab-org/container-registry/-/blob/master/docs/configuration.md#auth) with `htpasswd`. It relies on an [Apache `htpasswd` file](https://httpd.apache.org/docs/2.4/programs/htpasswd.html), with passwords hashed using `bcrypt`.

Since it isn't used in the context of GitLab (the product), `htpasswd` authentication will be deprecated in GitLab 14.9 and removed in GitLab 15.0.

### Custom `geo:db:*` Rake tasks are no longer available

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/351945).
</div>

In GitLab 14.8, we [deprecated the `geo:db:*` Rake tasks and replaced them with built-in tasks](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/77269/diffs) after [switching the Geo tracking database to use Rails' 6 support of multiple databases](https://gitlab.com/groups/gitlab-org/-/epics/6458).
The following `geo:db:*` tasks have been removed from GitLab 15.0 and have been replaced with their corresponding `db:*:geo` tasks:

- `geo:db:drop` -> `db:drop:geo`
- `geo:db:create` -> `db:create:geo`
- `geo:db:setup` -> `db:setup:geo`
- `geo:db:migrate` -> `db:migrate:geo`
- `geo:db:rollback` -> `db:rollback:geo`
- `geo:db:version` -> `db:version:geo`
- `geo:db:reset` -> `db:reset:geo`
- `geo:db:seed` -> `db:seed:geo`
- `geo:schema:load:geo` -> `db:schema:load:geo`
- `geo:db:schema:dump` -> `db:schema:dump:geo`
- `geo:db:migrate:up` -> `db:migrate:up:geo`
- `geo:db:migrate:down` -> `db:migrate:down:geo`
- `geo:db:migrate:redo` -> `db:migrate:redo:geo`
- `geo:db:migrate:status` -> `db:migrate:status:geo`
- `geo:db:test:prepare` -> `db:test:prepare:geo`
- `geo:db:test:load` -> `db:test:load:geo`
- `geo:db:test:purge` -> `db:test:purge:geo`

### DS_DEFAULT_ANALYZERS environment variable

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.0</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/333299).
</div>

We are removing the `DS_DEFAULT_ANALYZERS` environment variable from Dependency Scanning on May 22, 2022 in 15.0. After this removal, this variable's value will be ignored. To configure which analyzers to run with the default configuration, you should use the `DS_EXCLUDED_ANALYZERS` variable instead.

### Dependency Scanning default Java version changed to 17

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.10</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

For Dependency Scanning, the default version of Java that the scanner expects will be updated from 11 to 17. Java 17 is [the most up-to-date Long Term Support (LTS) version](https://en.wikipedia.org/wiki/Java_version_history). Dependency Scanning continues to support the same [range of versions (8, 11, 13, 14, 15, 16, 17)](https://docs.gitlab.com/ee/user/application_security/dependency_scanning/#supported-languages-and-package-managers), only the default version is changing. If your project uses the previous default of Java 11, be sure to [set the `DS_JAVA_VERSION` variable to match](https://docs.gitlab.com/ee/user/application_security/dependency_scanning/#configuring-specific-analyzers-used-by-dependency-scanning). Please note that consequently the default version of Gradle is now 7.3.3.

### ELK stack logging

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.7</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/346485).
</div>

The logging features in GitLab allow users to install the ELK stack (Elasticsearch, Logstash, and Kibana) to aggregate and manage application logs. Users could search for relevant logs in GitLab directly. However, since deprecating certificate-based integration with Kubernetes clusters and GitLab Managed Apps, this feature is no longer available. For more information on the future of logging and observability, you can follow the issue for [integrating Opstrace with GitLab](https://gitlab.com/groups/gitlab-org/-/epics/6976).

### Elasticsearch 6.8.x in GitLab 15.0

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/350275).
</div>

Elasticsearch 6.8 support has been removed in GitLab 15.0. Elasticsearch 6.8 has reached [end of life](https://www.elastic.co/support/eol).
If you use Elasticsearch 6.8, **you must upgrade your Elasticsearch version to 7.x** prior to upgrading to GitLab 15.0.
You should not upgrade to Elasticsearch 8 until you have completed the GitLab 15.0 upgrade.

View the [version requirements](https://docs.gitlab.com/ee/integration/advanced_search/elasticsearch.html#version-requirements) for details.

### End of support for Python 3.6 in Dependency Scanning

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/351503).
</div>

For those using Dependency Scanning for Python projects, we are removing support for the default `gemnasium-python:2` image which uses Python 3.6, as well as the custom `gemnasium-python:2-python-3.9` image which uses Python 3.9. The new default image as of GitLab 15.0 will be for Python 3.9 as it is a [supported version](https://endoflife.date/python) and 3.6 [is no longer supported](https://endoflife.date/python).

### External status check API breaking changes

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/339039).
</div>

The [external status check API](https://docs.gitlab.com/ee/api/status_checks.html) was originally implemented to
support pass-by-default requests to mark a status check as passing. Pass-by-default requests are now removed.
Specifically, the following are removed:

- Requests that do not contain the `status` field.
- Requests that have the `status` field set to `approved`.

From GitLab 15.0, status checks are only set to a passing state if the `status` field is both present
and set to `passed`. Requests that:

- Do not contain the `status` field will be rejected with a `400` error. For more information, see [the relevant issue](https://gitlab.com/gitlab-org/gitlab/-/issues/338827).
- Contain any value other than `passed`, such as `approved`, cause the status check to fail. For more information, see [the relevant issue](https://gitlab.com/gitlab-org/gitlab/-/issues/339039).

To align with this change, API calls to list external status checks also return the value of `passed` rather than
`approved` for status checks that have passed.

### GitLab Serverless

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.3</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/groups/gitlab-org/configure/-/epics/6).
</div>

All functionality related to GitLab Serverless was deprecated in GitLab 14.3 and is scheduled for removal in GitLab 15.0. Users who need a replacement for this functionality are encouraged to explore using the following technologies with GitLab CI/CD:

- [Serverless Framework](https://www.serverless.com)
- [AWS Serverless Application Model](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/deploying-using-gitlab.html)

For additional context, or to provide feedback regarding this change, please reference our [deprecation issue](https://gitlab.com/groups/gitlab-org/configure/-/epics/6).

### Gitaly nodes in virtual storage

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">13.12</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

Configuring the Gitaly nodes directly in the virtual storage's root configuration object has been deprecated in GitLab 13.12 and is no longer supported in GitLab 15.0. You must move the Gitaly nodes under the `'nodes'` key as described in [the Praefect configuration](https://docs.gitlab.com/ee/administration/gitaly/praefect.html#praefect).

### GraphQL permissions change for Package settings

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

The GitLab Package stage offers a Package Registry, Container Registry, and Dependency Proxy to help you manage all of your dependencies using GitLab. Each of these product categories has a variety of settings that can be adjusted using the API.

The permissions model for GraphQL is being updated. After 15.0, users with the Guest, Reporter, and Developer role can no longer update these settings:

- [Package Registry settings](https://docs.gitlab.com/ee/api/graphql/reference/#packagesettings)
- [Container Registry cleanup policy](https://docs.gitlab.com/ee/api/graphql/reference/#containerexpirationpolicy)
- [Dependency Proxy time-to-live policy](https://docs.gitlab.com/ee/api/graphql/reference/#dependencyproxyimagettlgrouppolicy)
- [Enabling the Dependency Proxy for your group](https://docs.gitlab.com/ee/api/graphql/reference/#dependencyproxysetting)

The issue for this removal is [GitLab-#350682](https://gitlab.com/gitlab-org/gitlab/-/issues/350682)

### Jaeger integration

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.7</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/346540).
</div>

Tracing in GitLab is an integration with Jaeger, an open-source end-to-end distributed tracing system. GitLab users could previously navigate to their Jaeger instance to gain insight into the performance of a deployed application, tracking each function or microservice that handles a given request. Tracing in GitLab was deprecated in GitLab 14.7, and removed in 15.0. To track work on a possible replacement, see the issue for [Opstrace integration with GitLab](https://gitlab.com/groups/gitlab-org/-/epics/6976).

### Known host required for GitLab Runner SSH executor

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.5</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/28192).
</div>

In [GitLab 14.3](https://gitlab.com/gitlab-org/gitlab-runner/-/merge_requests/3074), we added a configuration setting in the GitLab Runner `config.toml`. This setting, [`[runners.ssh.disable_strict_host_key_checking]`](https://docs.gitlab.com/runner/executors/ssh.html#security), controls whether or not to use strict host key checking with the SSH executor.

In GitLab 15.0, the default value for this configuration option has changed from `true` to `false`. This means that strict host key checking will be enforced when using the GitLab Runner SSH executor.

### Legacy Geo Admin UI routes

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/351345).
</div>

In GitLab 13.0, we introduced new project and design replication details routes in the Geo Admin UI. These routes are `/admin/geo/replication/projects` and `/admin/geo/replication/designs`. We kept the legacy routes and redirected them to the new routes. These legacy routes `/admin/geo/projects` and `/admin/geo/designs` have been removed in GitLab 15.0. Please update any bookmarks or scripts that may use the legacy routes.

### Legacy approval status names in License Compliance API

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.6</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/345839).
</div>

We have now removed the deprecated legacy names for approval status of license policy (`blacklisted`, `approved`) in the API queries and responses. If you are using our License Compliance API you should stop using the `approved` and `blacklisted` query parameters, they are now `allowed` and `denied`. In 15.0 the responses will also stop using `approved` and `blacklisted` so you may need to adjust any of your custom tools.

### Move Gitaly Cluster Praefect `database_host_no_proxy` and `database_port_no_proxy configs`

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.0</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/omnibus-gitlab/-/issues/6150).
</div>

The Gitaly Cluster configuration keys for `praefect['database_host_no_proxy']` and `praefect['database_port_no_proxy']` are replaced with `praefect['database_direct_host']` and `praefect['database_direct_port']`.

### Move `custom_hooks_dir` setting from GitLab Shell to Gitaly

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/omnibus-gitlab/-/merge_requests/4208).
</div>

The [`custom_hooks_dir`](https://docs.gitlab.com/ee/administration/server_hooks.html#create-a-global-server-hook-for-all-repositories) setting is now configured in Gitaly, and is removed from GitLab Shell in GitLab 15.0.

### OAuth implicit grant

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.0</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

The OAuth implicit grant authorization flow is no longer supported. Any applications that use OAuth implicit grant must switch to alternative [supported OAuth flows](https://docs.gitlab.com/ee/api/oauth2.html).

### OAuth tokens without an expiration

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.3</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

GitLab no longer supports OAuth tokens [without an expiration](https://docs.gitlab.com/ee/integration/oauth_provider.html#expiring-access-tokens).

Any existing token without an expiration has one automatically generated and applied.

### Optional enforcement of SSH expiration

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/351963).
</div>

Disabling SSH expiration enforcement is unusual from a security perspective and could create unusual situations where an expired
key is unintentionally able to be used. Unexpected behavior in a security feature is inherently dangerous and so now we enforce
expiration on all SSH keys.

### Optional enforcement of personal access token expiration

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/351962).
</div>

Allowing expired personal access tokens to be used is unusual from a security perspective and could create unusual situations where an
expired key is unintentionally able to be used. Unexpected behavior in a security feature is inherently dangerous and so we now do not let expired personal access tokens be used.

### Out-of-the-box SAST (SpotBugs) support for Java 8

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/352549).
</div>

The [GitLab SAST SpotBugs analyzer](https://gitlab.com/gitlab-org/security-products/analyzers/spotbugs) scans [Java, Scala, Groovy, and Kotlin code](https://docs.gitlab.com/ee/user/application_security/sast/#supported-languages-and-frameworks) for security vulnerabilities.
For technical reasons, the analyzer must first compile the code before scanning.
Unless you use the [pre-compilation strategy](https://docs.gitlab.com/ee/user/application_security/sast/#pre-compilation), the analyzer attempts to automatically compile your project's code.

In GitLab versions prior to 15.0, the analyzer image included Java 8 and Java 11 runtimes to facilitate compilation.

As of GitLab 15.0, we've:

- Removed Java 8 from the analyzer image to reduce the size of the image.
- Added Java 17 to the analyzer image to make it easier to compile with Java 17.
- Changed the default Java version from Java 8 to Java 17.

If you rely on Java 8 being present in the analyzer environment, you must take action as detailed in the [deprecation issue for this change](https://gitlab.com/gitlab-org/gitlab/-/issues/352549#breaking-change).

### Pipelines field from the version field

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.5</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/342882).
</div>

In GraphQL, there are two `pipelines` fields that you can use in a [`PackageDetailsType`](https://docs.gitlab.com/ee/api/graphql/reference/#packagedetailstype) to get the pipelines for package versions:

- The `versions` field's `pipelines` field. This returns all the pipelines associated with all the package's versions, which can pull an unbounded number of objects in memory and create performance concerns.
- The `pipelines` field of a specific `version`. This returns only the pipelines associated with that single package version.

To mitigate possible performance problems, we will remove the `versions` field's `pipelines` field in GitLab 15.0. Although you will no longer be able to get all pipelines for all versions of a package, you can still get the pipelines of a single version through the remaining `pipelines` field for that version.

### Pseudonymizer

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.7</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/219952).
</div>

The Pseudonymizer feature is generally unused, can cause production issues with large databases, and can interfere with object storage development.
It was removed in GitLab 15.0.

### Request profiling

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/352488).
</div>

[Request profiling](https://docs.gitlab.com/ee/administration/monitoring/performance/index.html) has been removed in GitLab 15.0.

We're working on [consolidating our profiling tools](https://gitlab.com/groups/gitlab-org/-/epics/7327) and making them more easily accessible.
We [evaluated](https://gitlab.com/gitlab-org/gitlab/-/issues/350152) the use of this feature and we found that it is not widely used.
It also depends on a few third-party gems that are not actively maintained anymore, have not been updated for the latest version of Ruby, or crash frequently when profiling heavy page loads.

For more information, check the [summary section of the deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/352488#deprecation-summary).

### Required pipeline configurations in Premium tier

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

[Required pipeline configuration](https://docs.gitlab.com/ee/user/admin_area/settings/continuous_integration.html#required-pipeline-configuration) helps to define and mandate organization-wide pipeline configurations and is a requirement at an executive and organizational level. To align better with our [pricing philosophy](https://about.gitlab.com/company/pricing/#three-tiers), this feature is removed from the Premium tier in GitLab 15.0. This feature continues to be available in the GitLab Ultimate tier.

We recommend customers use [Compliance Pipelines](https://docs.gitlab.com/ee/user/project/settings/index.html#compliance-pipeline-configuration), also in GitLab Ultimate, as an alternative as it provides greater flexibility, allowing required pipelines to be assigned to specific compliance framework labels.

This change also helps GitLab remain consistent in our tiering strategy with the other related Ultimate-tier features:

- [Security policies](https://docs.gitlab.com/ee/user/application_security/policies/).
- [Compliance framework pipelines](https://docs.gitlab.com/ee/user/project/settings/index.html#compliance-pipeline-configuration).

### Retire-JS Dependency Scanning tool

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/289830).
</div>

We have removed support for retire.js from Dependency Scanning as of May 22, 2022 in GitLab 15.0. JavaScript scanning functionality will not be affected as it is still being covered by Gemnasium.

If you have explicitly excluded retire.js using the `DS_EXCLUDED_ANALYZERS` variable, then you will be able to remove the reference to retire.js. If you have customized your pipeline’s Dependency Scanning configuration related to the `retire-js-dependency_scanning` job, then you will want to switch to `gemnasium-dependency_scanning`. If you have not used the `DS_EXCLUDED_ANALYZERS` to reference retire.js, or customized your template specifically for retire.js, you will not need to take any action.

### Runner status `not_connected` API value

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.6</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/347305).
</div>

The GitLab Runner REST and GraphQL [API](https://docs.gitlab.com/ee/api/runners.html#runners-api) endpoints
deprecated the `not_connected` status value in GitLab 14.6 and will start returning `never_contacted` in its place
starting in GitLab 15.0.

Runners that have never contacted the GitLab instance will also return `stale` if created more than 3 months ago.

### SAST support for .NET 2.1

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/352553).
</div>

The [GitLab SAST Security Code Scan analyzer](https://gitlab.com/gitlab-org/security-products/analyzers/security-code-scan) scans .NET code for security vulnerabilities.
For technical reasons, the analyzer must first build the code to scan it.

In GitLab versions prior to 15.0, the default analyzer image (version 2) included support for:

- .NET 2.1
- .NET Core 3.1
- .NET 5.0

In GitLab 15.0, we've changed the default major version for this analyzer from version 2 to version 3. This change:

- Adds [severity values for vulnerabilities](https://gitlab.com/gitlab-org/gitlab/-/issues/350408) along with [other new features and improvements](https://gitlab.com/gitlab-org/security-products/analyzers/security-code-scan/-/blob/master/CHANGELOG.md).
- Removes .NET 2.1 support.
- Adds support for .NET 6.0, Visual Studio 2019, and Visual Studio 2022.

Version 3 was [announced in GitLab 14.6](https://about.gitlab.com/releases/2021/12/22/gitlab-14-6-released/#sast-support-for-net-6) and made available as an optional upgrade.

If you rely on .NET 2.1 support being present in the analyzer image by default, you must take action as detailed in the [deprecation issue for this change](https://gitlab.com/gitlab-org/gitlab/-/issues/352553#breaking-change).

### SUSE Linux Enterprise Server 12 SP2

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.5</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

Long term service and support (LTSS) for SUSE Linux Enterprise Server (SLES) 12 SP2 [ended on March 31, 2021](https://www.suse.com/lifecycle/). The CA certificates on SP2 include the expired DST root certificate, and it's not getting new CA certificate package updates. We have implemented some [workarounds](https://gitlab.com/gitlab-org/gitlab-omnibus-builder/-/merge_requests/191), but we will not be able to continue to keep the build running properly.

### Secret Detection configuration variables

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/352565).
</div>

To make it simpler and more reliable to [customize GitLab Secret Detection](https://docs.gitlab.com/ee/user/application_security/secret_detection/#customizing-settings), we've removed some of the variables that you could previously set in your CI/CD configuration.

The following variables previously allowed you to customize the options for historical scanning, but interacted poorly with the [GitLab-managed CI/CD template](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Security/Secret-Detection.gitlab-ci.yml) and are now removed:

- `SECRET_DETECTION_COMMIT_FROM`
- `SECRET_DETECTION_COMMIT_TO`
- `SECRET_DETECTION_COMMITS`
- `SECRET_DETECTION_COMMITS_FILE`

The `SECRET_DETECTION_ENTROPY_LEVEL` previously allowed you to configure rules that only considered the entropy level of strings in your codebase, and is now removed.
This type of entropy-only rule created an unacceptable number of incorrect results (false positives).

You can still customize the behavior of the Secret Detection analyzer using the [available CI/CD variables](https://docs.gitlab.com/ee/user/application_security/secret_detection/#available-cicd-variables).

For further details, see [the deprecation issue for this change](https://gitlab.com/gitlab-org/gitlab/-/issues/352565).

### Self-managed certificate-based integration with Kubernetes feature flagged

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.5</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/groups/gitlab-org/configure/-/epics/8).
</div>

In 15.0 the certificate-based integration with Kubernetes will be disabled by default.

After 15.0, you should use the [agent for Kubernetes](https://docs.gitlab.com/ee/user/clusters/agent/) to connect Kubernetes clusters with GitLab. The agent for Kubernetes is a more robust, secure, and reliable integration with Kubernetes. [How do I migrate to the agent?](https://docs.gitlab.com/ee/user/infrastructure/clusters/migrate_to_gitlab_agent.html)

If you need more time to migrate, you can enable the `certificate_based_clusters` [feature flag](https://docs.gitlab.com/ee/administration/feature_flags.html), which re-enables the certificate-based integration.

In GitLab 16.0, we will [remove the feature, its related code, and the feature flag](https://about.gitlab.com/blog/2021/11/15/deprecating-the-cert-based-kubernetes-integration/). GitLab will continue to fix any security or critical issues until 16.0.

For updates and details, follow [this epic](https://gitlab.com/groups/gitlab-org/configure/-/epics/8).

### Sidekiq configuration for metrics and health checks

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.7</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/347509).
</div>

In GitLab 15.0, you can no longer serve Sidekiq metrics and health checks over a single address and port.

To improve stability, availability, and prevent data loss in edge cases, GitLab now serves
[Sidekiq metrics and health checks from two separate servers](https://gitlab.com/groups/gitlab-org/-/epics/6409).

When you use Omnibus or Helm charts, if GitLab is configured for both servers to bind to the same address,
a configuration error occurs.
To prevent this error, choose different ports for the metrics and health check servers:

- [Configure Sidekiq health checks](https://docs.gitlab.com/ee/administration/sidekiq.html#configure-health-checks)
- [Configure the Sidekiq metrics server](https://docs.gitlab.com/ee/administration/sidekiq.html#configure-the-sidekiq-metrics-server)

If you installed GitLab from source, verify manually that both servers are configured to bind to separate addresses and ports.

### Static Site Editor

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.7</span>
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/347137).
</div>

The Static Site Editor was deprecated in GitLab 14.7 and the feature is being removed in GitLab 15.0. Incoming requests to the Static Site Editor will be redirected and open the target file to edit in the Web IDE. Current users of the Static Site Editor can view the [documentation](https://docs.gitlab.com/ee/user/project/web_ide/index.html) for more information, including how to remove the configuration files from existing projects. We will continue investing in improvements to the Markdown editing experience by [maturing the Content Editor](https://gitlab.com/groups/gitlab-org/-/epics/5401) and making it available as a way to edit content across GitLab.

### Support for `gitaly['internal_socket_dir']`

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.10</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/omnibus-gitlab/-/issues/6758).
</div>

Gitaly introduced a new directory that holds all runtime data Gitaly requires to operate correctly. This new directory replaces the old internal socket directory, and consequentially the usage of `gitaly['internal_socket_dir']` was deprecated in favor of `gitaly['runtime_dir']`.

### Support for legacy format of `config/database.yml`

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.3</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/338182).
</div>

The syntax of [GitLab's database](https://docs.gitlab.com/omnibus/settings/database.html)
configuration located in `database.yml` has changed and the legacy format has been removed.
The legacy format supported a single PostgreSQL adapter, whereas the new format supports multiple databases.
The `main:` database needs to be defined as a first configuration item.

This change only impacts users compiling GitLab from source, all the other installation methods handle this configuration automatically.
Instructions are available [in the source update documentation](https://docs.gitlab.com/ee/update/upgrading_from_source.html#new-configuration-options-for-databaseyml).

### Test coverage project CI/CD setting

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

To specify a test coverage pattern, in GitLab 15.0 the
[project setting for test coverage parsing](https://docs.gitlab.com/ee/ci/pipelines/settings.html#add-test-coverage-results-to-a-merge-request-removed)
has been removed.

To set test coverage parsing, use the project’s `.gitlab-ci.yml` file by providing a regular expression with the
[`coverage` keyword](https://docs.gitlab.com/ee/ci/yaml/index.html#coverage).

### The `promote-db` command is no longer available from `gitlab-ctl`

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.5</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/345207).
</div>

In GitLab 14.5, we introduced the command `gitlab-ctl promote` to promote any Geo secondary node to a primary during a failover. This command replaces `gitlab-ctl promote-db` which is used to promote database nodes in multi-node Geo secondary sites. The `gitlab-ctl promote-db` command has been removed in GitLab 15.0.

### Update to the Container Registry group-level API

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.5</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/336912).
</div>

In GitLab 15.0, support for the `tags` and `tags_count` parameters will be removed from the Container Registry API that [gets registry repositories from a group](../api/container_registry.md#within-a-group).

The `GET /groups/:id/registry/repositories` endpoint will remain, but won't return any info about tags. To get the info about tags, you can use the existing `GET /registry/repositories/:id` endpoint, which will continue to support the `tags` and `tag_count` options as it does today. The latter must be called once per image repository.

### Versions from `PackageType`

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.5</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/327453).
</div>

As part of the work to create a [Package Registry GraphQL API](https://gitlab.com/groups/gitlab-org/-/epics/6318), the Package group deprecated the `Version` type for the basic `PackageType` type and moved it to [`PackageDetailsType`](https://docs.gitlab.com/ee/api/graphql/reference/index.html#packagedetailstype).

In GitLab 15.0, we will completely remove `Version` from `PackageType`.

### Vulnerability Check

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/357300).
</div>

The vulnerability check feature was deprecated in GitLab 14.8 and is scheduled for removal in GitLab 15.0. We encourage you to migrate to the new security approvals feature instead. You can do so by navigating to **Security & Compliance > Policies** and creating a new Scan Result Policy.

The new security approvals feature is similar to vulnerability check. For example, both can require approvals for MRs that contain security vulnerabilities. However, security approvals improve the previous experience in several ways:

- Users can choose who is allowed to edit security approval rules. An independent security or compliance team can therefore manage rules in a way that prevents development project maintainers from modifying the rules.
- Multiple rules can be created and chained together to allow for filtering on different severity thresholds for each scanner type.
- A two-step approval process can be enforced for any desired changes to security approval rules.
- A single set of security policies can be applied to multiple development projects to allow for ease in maintaining a single, centralized ruleset.

### `Managed-Cluster-Applications.gitlab-ci.yml`

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.0</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/333610).
</div>

The `Managed-Cluster-Applications.gitlab-ci.yml` CI/CD template is being removed. If you need an  alternative, try the [Cluster Management project template](https://gitlab.com/gitlab-org/gitlab/-/issues/333610) instead. If your are not ready to move, you can copy the [last released version](https://gitlab.com/gitlab-org/gitlab-foss/-/blob/v14.10.1/lib/gitlab/ci/templates/Managed-Cluster-Applications.gitlab-ci.yml) of the template into your project.

### `artifacts:reports:cobertura` keyword

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.7</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/348980).
</div>

As of GitLab 15.0, the [`artifacts:reports:cobertura`](https://docs.gitlab.com/ee/ci/yaml/artifacts_reports.html#artifactsreportscobertura-removed)
keyword has been [replaced](https://gitlab.com/gitlab-org/gitlab/-/issues/344533) by
[`artifacts:reports:coverage_report`](https://docs.gitlab.com/ee/ci/yaml/artifacts_reports.html#artifactsreportscoverage_report).
Cobertura is the only supported report file, but this is the first step towards GitLab supporting other report types.

### `defaultMergeCommitMessageWithDescription` GraphQL API field

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.5</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/345451).
</div>

The GraphQL API field `defaultMergeCommitMessageWithDescription` has been removed in GitLab 15.0. For projects with a commit message template set, it will ignore the template.

### `dependency_proxy_for_private_groups` feature flag

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.5</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/276777).
</div>

A feature flag was [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/11582) in GitLab 13.7 as part of the change to require authentication to use the Dependency Proxy. Before GitLab 13.7, you could use the Dependency Proxy without authentication.

In GitLab 15.0, we will remove the feature flag, and you must always authenticate when you use the Dependency Proxy.

### `omniauth-kerberos` gem

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.3</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

The `omniauth-kerberos` gem is no longer supported. This gem has not been maintained and has very little usage. Therefore, we
removed support for this authentication method and recommend using [SPEGNO](https://en.wikipedia.org/wiki/SPNEGO) instead. You can
follow the [upgrade instructions](https://docs.gitlab.com/ee/integration/kerberos.html#upgrading-from-password-based-to-ticket-based-kerberos-sign-ins)
to upgrade from the removed integration to the new supported one.

We are not removing Kerberos SPNEGO integration. We are removing the old password-based Kerberos.

### `promote-to-primary-node` command from `gitlab-ctl`

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.5</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/345207).
</div>

In GitLab 14.5, we introduced the command `gitlab-ctl promote` to promote any Geo secondary node to a primary during a failover. This command replaces `gitlab-ctl promote-to-primary-node` which was only usable for single-node Geo sites. `gitlab-ctl promote-to-primary-node` has been removed in GitLab 15.0.

### `push_rules_supersede_code_owners` feature flag

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/262019).
</div>

The `push_rules_supersede_code_owners` feature flag has been removed in GitLab 15.0. From now on, push rules will supersede the `CODEOWNERS` file. Even if Code Owner approval is required, a push rule that explicitly allows a specific user to push code supersedes the Code Owners setting.

### `type` and `types` keyword from CI/CD configuration

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.6</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

The `type` and `types` CI/CD keywords is removed in GitLab 15.0, so pipelines that use these keywords fail with a syntax error. Switch to `stage` and `stages`, which have the same behavior.

### bundler-audit Dependency Scanning tool

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.8</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/347491).
</div>

We are removing bundler-audit from Dependency Scanning on May 22, 2022 in 15.0. After this removal, Ruby scanning functionality will not be affected as it is still being covered by Gemnasium.

If you have explicitly excluded bundler-audit using the `DS_EXCLUDED_ANALYZERS` variable, then you will be able to remove the reference to bundler-audit. If you have customized your pipeline’s Dependency Scanning configuration related to the `bundler-audit-dependency_scanning` job, then you will want to switch to `gemnasium-dependency_scanning`. If you have not used the `DS_EXCLUDED_ANALYZERS` to reference bundler-audit or customized your template specifically for bundler-audit, you will not need to take any action.

## Removed in 14.10

### Permissions change for downloading Composer dependencies

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

The GitLab Composer repository can be used to push, search, fetch metadata about, and download PHP dependencies. All these actions require authentication, except for downloading dependencies.

Downloading Composer dependencies without authentication is deprecated in GitLab 14.9, and will be removed in GitLab 15.0. Starting with GitLab 15.0, you must authenticate to download Composer dependencies.

## Removed in 14.9

### Integrated error tracking disabled by default

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone">14.9</span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/353639).
</div>

In GitLab 14.4, GitLab released an integrated error tracking backend that replaces Sentry. This feature caused database performance issues. In GitLab 14.9, integrated error tracking is removed from GitLab.com, and turned off by default in GitLab self-managed. While we explore the future development of this feature, please consider switching to the Sentry backend by [changing your error tracking to Sentry in your project settings](https://docs.gitlab.com/ee/operations/error_tracking.html#sentry-error-tracking).

For additional background on this removal, please reference [Disable Integrated Error Tracking by Default](https://gitlab.com/groups/gitlab-org/-/epics/7580). If you have feedback please add a comment to [Feedback: Removal of Integrated Error Tracking](https://gitlab.com/gitlab-org/gitlab/-/issues/355493).

## Removed in 14.6

### Limit the number of triggered pipeline to 25K in free tier

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
</div>

A large amount of triggered pipelines in a single project impacts the performance of GitLab.com. In GitLab 14.6, we are limiting the number of triggered pipelines in a single project on GitLab.com at any given moment to 25,000. This change applies to projects in the free tier only, Premium and Ultimate are not affected by this change.

### Release CLI distributed as a generic package

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
</div>

The [release-cli](https://gitlab.com/gitlab-org/release-cli) will be released as a [generic package](https://gitlab.com/gitlab-org/release-cli/-/packages) starting in GitLab 14.2. We will continue to deploy it as a binary to S3 until GitLab 14.5 and stop distributing it in S3 in GitLab 14.6.

## Removed in 14.3

### Introduced limit of 50 tags for jobs

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
</div>

GitLab values efficiency and is prioritizing reliability for [GitLab.com in FY22](https://about.gitlab.com/direction/#gitlab-hosted-first). In 14.3, GitLab CI/CD jobs must have less than 50 [tags](https://docs.gitlab.com/ee/ci/yaml/index.html#tags). If a pipeline contains a job with 50 or more tags, you will receive an error and the pipeline will not be created.

### List project pipelines API endpoint removes `name` support in 14.3

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
</div>

In GitLab 14.3, we will remove the ability to filter by `name` in the [list project pipelines API endpoint](https://docs.gitlab.com/ee/api/pipelines.html#list-project-pipelines) to improve performance. If you currently use this parameter with this endpoint, you must switch to `username`.

### Use of legacy storage setting

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
</div>

The support for [`gitlab_pages['use_legacy_storage']` setting](https://docs.gitlab.com/ee/administration/pages/index.html#domain-source-configuration-before-140) in Omnibus installations has been removed.

In 14.0 we removed [`domain_config_source`](https://docs.gitlab.com/ee/administration/pages/index.html#domain-source-configuration-before-140) which had been previously deprecated, and allowed users to specify disk storage. In 14.0 we added `use_legacy_storage` as a **temporary** flag to unblock upgrades, and allow us to debug issues with our users and it was deprecated and communicated for removal in 14.3.

## Removed in 14.2

### Max job log file size of 100 MB

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
</div>

GitLab values efficiency for all users in our wider community of contributors, so we're always working hard to make sure the application performs at a high level with a lovable UX.
  In GitLab 14.2, we have introduced a [job log file size limit](https://docs.gitlab.com/ee/administration/instance_limits.html#maximum-file-size-for-job-logs), set to 100 megabytes by default. Administrators of self-managed GitLab instances can customize this to any value. All jobs that exceed this limit are dropped and marked as failed, helping prevent performance impacts or over-use of resources. This ensures that everyone using GitLab has the best possible experience.

## Removed in 14.1

### Remove support for `prometheus.listen_address` and `prometheus.enable`

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
</div>

The support for `prometheus.listen_address` and `prometheus.enable` has been removed from `gitlab.yml`. Use `prometheus.enabled` and `prometheus.server_address` to set up Prometheus server that GitLab instance connects to. Refer to [our documentation](https://docs.gitlab.com/ee/install/installation.html#prometheus-server-setup) for details.

This only affects new installations from source where users might use the old configurations.

### Remove support for older browsers

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
</div>

In GitLab 14.1, we are cleaning up and [removing old code](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/63994) that was specific for browsers that we no longer support. This has no impact on users when one of our [supported web browsers](https://docs.gitlab.com/ee/install/requirements.html#supported-web-browsers) is used.

Most notably, support for the following browsers has been removed:

- Apple Safari 13 and older.
- Mozilla Firefox 68.
- Pre-Chromium Microsoft Edge.

The minimum supported browser versions are:

- Apple Safari 13.1.
- Mozilla Firefox 78.
- Google Chrome 84.
- Chromium 84.
- Microsoft Edge 84.

## Removed in 14.0

### Auto Deploy CI template v1

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/300862).
</div>

In GitLab 14.0, we will update the [Auto Deploy](https://docs.gitlab.com/ee/topics/autodevops/stages.html#auto-deploy) CI template to the latest version. This includes new features, bug fixes, and performance improvements with a dependency on the v2 [auto-deploy-image](https://gitlab.com/gitlab-org/cluster-integration/auto-deploy-image). Auto Deploy CI template v1 is deprecated going forward.

Since the v1 and v2 versions are not backward-compatible, your project might encounter an unexpected failure if you already have a deployed application. Follow the [upgrade guide](https://docs.gitlab.com/ee/topics/autodevops/upgrading_auto_deploy_dependencies.html#upgrade-guide) to upgrade your environments. You can also start using the latest template today by following the [early adoption guide](https://docs.gitlab.com/ee/topics/autodevops/upgrading_auto_deploy_dependencies.html#early-adopters).

### Breaking changes to Terraform CI template

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/328500).
</div>

GitLab 14.0 renews the Terraform CI template to the latest version. The new template is set up for the GitLab Managed Terraform state, with a dependency on the GitLab `terraform-images` image, to provide a good user experience around GitLab's Infrastructure-as-Code features.

The current stable and latest templates are not compatible, and the current latest template becomes the stable template beginning with GitLab 14.0, your Terraform pipeline might encounter an unexpected failure if you run a custom `init` job.

### Code Quality RuboCop support changed

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

By default, the Code Quality feature has not provided support for Ruby 2.6+ if you're using the Code Quality template. To better support the latest versions of Ruby, the default RuboCop version is updated to add support for Ruby 2.4 through 3.0. As a result, support for Ruby 2.1, 2.2, and 2.3 is removed. You can re-enable support for older versions by [customizing your configuration](https://docs.gitlab.com/ee/ci/testing/code_quality.html#rubocop-errors).

Relevant Issue: [Default `codeclimate-rubocop` engine does not support Ruby 2.6+](https://gitlab.com/gitlab-org/ci-cd/codequality/-/issues/28)

### Container Scanning Engine Clair

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

Clair, the default container scanning engine, was deprecated in GitLab 13.9 and is removed from GitLab 14.0 and replaced by Trivy. We advise customers who are customizing variables for their container scanning job to [follow these instructions](https://docs.gitlab.com/ee/user/application_security/container_scanning/#change-scanners) to ensure that their container scanning jobs continue to work.

### DAST default template stages

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

In GitLab 14.0, we've removed the stages defined in the current `DAST.gitlab-ci.yml` template to avoid the situation where the template overrides manual changes made by DAST users. We're making this change in response to customer issues where the stages in the template cause problems when used with customized DAST configurations. Because of this removal, `gitlab-ci.yml` configurations that do not specify a `dast` stage must be updated to include this stage.

### DAST environment variable renaming and removal

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

GitLab 13.8 renamed multiple environment variables to support their broader usage in different workflows. In GitLab 14.0, the old variables have been permanently removed and will no longer work. Any configurations using these variables must be updated to the new variable names. Any scans using these variables in GitLab 14.0 and later will fail to be configured correctly. These variables are:

- `DAST_AUTH_EXCLUDE_URLS` becomes `DAST_EXCLUDE_URLS`.
- `AUTH_EXCLUDE_URLS` becomes `DAST_EXCLUDE_URLS`.
- `AUTH_USERNAME` becomes `DAST_USERNAME`.
- `AUTH_PASSWORD` becomes `DAST_PASSWORD`.
- `AUTH_USERNAME_FIELD` becomes `DAST_USERNAME_FIELD`.
- `AUTH_PASSWORD_FIELD` becomes `DAST_PASSWORD_FIELD`.
- `DAST_ZAP_USE_AJAX_SPIDER` will now be `DAST_USE_AJAX_SPIDER`.
- `DAST_FULL_SCAN_DOMAIN_VALIDATION_REQUIRED` will be removed, since the feature is being removed.

### Default Browser Performance testing job renamed in GitLab 14.0

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

Browser Performance Testing has run in a job named `performance` by default. With the introduction of [Load Performance Testing](https://docs.gitlab.com/ee/ci/testing/code_quality.html) in GitLab 13.2, this naming could be confusing. To make it clear which job is running [Browser Performance Testing](https://docs.gitlab.com/ee/ci/testing/browser_performance_testing.html), the default job name is changed from `performance` to `browser_performance` in the template in GitLab 14.0.

Relevant Issue: [Rename default Browser Performance Testing job](https://gitlab.com/gitlab-org/gitlab/-/issues/225914)

### Default DAST spider begins crawling at target URL

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

In GitLab 14.0, DAST has removed the current method of resetting the scan to the hostname when starting to spider. Prior to GitLab 14.0, the spider would not begin at the specified target path for the URL but would instead reset the URL to begin crawling at the host root. GitLab 14.0 changes the default for the new variable `DAST_SPIDER_START_AT_HOST` to `false` to better support users' intention of beginning spidering and scanning at the specified target URL, rather than the host root URL. This change has an added benefit: scans can take less time, if the specified path does not contain links to the entire site. This enables easier scanning of smaller sections of an application, rather than crawling the entire app during every scan.

### Default branch name for new repositories now `main`

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

Every Git repository has an initial branch, which is named `master` by default. It's the first branch to be created automatically when you create a new repository. Future [Git versions](https://lore.kernel.org/git/pull.656.v4.git.1593009996.gitgitgadget@gmail.com/) will change the default branch name in Git from `master` to `main`. In coordination with the Git project and the broader community, [GitLab has changed the default branch name](https://gitlab.com/gitlab-org/gitlab/-/issues/223789) for new projects on both our SaaS (GitLab.com) and self-managed offerings starting with GitLab 14.0. This will not affect existing projects.

GitLab has already introduced changes that allow you to change the default branch name both at the [instance level](https://docs.gitlab.com/ee/user/project/repository/branches/default.html#instance-level-custom-initial-branch-name) (for self-managed users) and at the [group level](https://docs.gitlab.com/ee/user/group/#use-a-custom-name-for-the-initial-branch) (for both SaaS and self-managed users). We encourage you to make use of these features to set default branch names on new projects.

For more information, check out our [blog post](https://about.gitlab.com/blog/2021/03/10/new-git-default-branch-name/).

### Dependency Scanning

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

As mentioned in [13.9](https://about.gitlab.com/releases/2021/02/22/gitlab-13-9-released/#deprecations-for-dependency-scanning) and [this blog post](https://about.gitlab.com/blog/2021/02/08/composition-analysis-14-deprecations-and-removals/) several removals for Dependency Scanning take effect.

Previously, to exclude a DS analyzer, you needed to remove it from the default list of analyzers, and use that to set the `DS_DEFAULT_ANALYZERS` variable in your project’s CI template. We determined it should be easier to avoid running a particular analyzer without losing the benefit of newly added analyzers. As a result, we ask you to migrate from `DS_DEFAULT_ANALYZERS` to `DS_EXCLUDED_ANALYZERS` when it is available. Read about it in [issue #287691](https://gitlab.com/gitlab-org/gitlab/-/issues/287691).

Previously, to prevent the Gemnasium analyzers to fetch the advisory database at runtime, you needed to set the `GEMNASIUM_DB_UPDATE` variable. However, this is not documented properly, and its naming is inconsistent with the equivalent `BUNDLER_AUDIT_UPDATE_DISABLED` variable. As a result, we ask you to migrate from `GEMNASIUM_DB_UPDATE` to `GEMNASIUM_UPDATE_DISABLED` when it is available. Read about it in [issue #215483](https://gitlab.com/gitlab-org/gitlab/-/issues/215483).

### Deprecated GraphQL fields

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

In accordance with our [GraphQL deprecation and removal process](https://docs.gitlab.com/ee/api/graphql/#deprecation-process), the following fields that were deprecated prior to 13.7 are [fully removed in 14.0](https://gitlab.com/gitlab-org/gitlab/-/issues/267966):

- `Mutations::Todos::MarkAllDone`, `Mutations::Todos::RestoreMany` - `:updated_ids`
- `Mutations::DastScannerProfiles::Create`, `Types::DastScannerProfileType` - `:global_id`
- `Types::SnippetType` - `:blob`
- `EE::Types::GroupType`, `EE::Types::QueryType` - `:vulnerabilities_count_by_day_and_severity`
- `DeprecatedMutations (concern**)` - `AddAwardEmoji`, `RemoveAwardEmoji`, `ToggleAwardEmoji`
- `EE::Types::DeprecatedMutations (concern***)` - `Mutations::Pipelines::RunDastScan`, `Mutations::Vulnerabilities::Dismiss`, `Mutations::Vulnerabilities::RevertToDetected`

### DevOps Adoption API Segments

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

The first release of the DevOps Adoption report had a concept of **Segments**. Segments were [quickly removed from the report](https://gitlab.com/groups/gitlab-org/-/epics/5251) because they introduced an additional layer of complexity on top of **Groups** and **Projects**. Subsequent iterations of the DevOps Adoption report focus on comparing adoption across groups rather than segments. GitLab 14.0 removes all references to **Segments** [from the GraphQL API](https://gitlab.com/gitlab-org/gitlab/-/issues/324414) and replaces them with **Enabled groups**.

### Disk source configuration for GitLab Pages

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/omnibus-gitlab/-/issues/5993).
</div>

GitLab Pages [API-based configuration](https://docs.gitlab.com/ee/administration/pages/#gitlab-api-based-configuration) has been available since GitLab 13.0. It replaces the unsupported `disk` source configuration removed in GitLab 14.0, which can no longer be chosen. You should stop using `disk` source configuration, and move to `gitlab` for an API-based configuration. To migrate away from the 'disk' source configuration, set `gitlab_pages['domain_config_source'] = "gitlab"` in your `/etc/gitlab/gitlab.rb` file. We recommend you migrate before updating to GitLab 14.0, to identify and troubleshoot any potential problems before upgrading.

### Experimental prefix in Sidekiq queue selector options

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

GitLab supports a [queue selector](https://docs.gitlab.com/ee/administration/operations/extra_sidekiq_processes.html#queue-selector) to run only a subset of background jobs for a given process. When it was introduced, this option had an 'experimental' prefix (`experimental_queue_selector` in Omnibus, `experimentalQueueSelector` in Helm charts).

As announced in the [13.6 release post](https://about.gitlab.com/releases/2020/11/22/gitlab-13-6-released/#sidekiq-cluster-queue-selector-configuration-option-has-been-renamed), the 'experimental' prefix is no longer supported. Instead, `queue_selector` for Omnibus and `queueSelector` in Helm charts should be used.

### External Pipeline Validation Service Code Changes

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

For self-managed instances using the experimental [external pipeline validation service](https://docs.gitlab.com/ee/administration/external_pipeline_validation.html), the range of error codes GitLab accepts will be reduced. Currently, pipelines are invalidated when the validation service returns a response code from `400` to `499`. In GitLab 14.0 and later, pipelines will be invalidated for the `406: Not Accepted` response code only.

### Geo Foreign Data Wrapper settings

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

As [announced in GitLab 13.3](https://about.gitlab.com/releases/2020/08/22/gitlab-13-3-released/#geo-foreign-data-wrapper-settings-deprecated), the following configuration settings in `/etc/gitlab/gitlab.rb` have been removed in 14.0:

- `geo_secondary['db_fdw']`
- `geo_postgresql['fdw_external_user']`
- `geo_postgresql['fdw_external_password']`
- `gitlab-_rails['geo_migrated_local_files_clean_up_worker_cron']`

### GitLab OAuth implicit grant

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/288516).
</div>

GitLab is deprecating the [OAuth 2 implicit grant flow](https://docs.gitlab.com/ee/api/oauth2.html#implicit-grant-flow) as it has been removed for [OAuth 2.1](https://oauth.net/2.1/).

Migrate your existing applications to other supported [OAuth2 flows](https://docs.gitlab.com/ee/api/oauth2.html#supported-oauth2-flows).

### GitLab Runner helper image in GitLab.com Container Registry

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

In 14.0, we are now pulling the GitLab Runner [helper image](https://docs.gitlab.com/runner/configuration/advanced-configuration.html#helper-image) from the GitLab Container Registry instead of Docker Hub. Refer to [issue #27218](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/27218) for details.

### GitLab Runner installation to ignore the `skel` directory

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

In GitLab Runner 14.0, the installation process will ignore the `skel` directory by default when creating the user home directory. Refer to [issue #4845](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/4845) for details.

### Gitaly Cluster SQL primary elector

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

Now that Praefect supports a [primary election strategy](https://docs.gitlab.com/ee/administration/gitaly/praefect.html#repository-specific-primary-nodes) for each repository, we have removed the `sql` election strategy.
The `per_repository` election strategy is the new default, which is automatically used if no election strategy was specified.

If you had configured the `sql` election strategy, you must follow the [migration instructions](https://docs.gitlab.com/ee/administration/gitaly/praefect.html#migrate-to-repository-specific-primary-gitaly-nodes) before upgrading to 14.0.

### Global `SAST_ANALYZER_IMAGE_TAG` in SAST CI template

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/301216).
</div>

With the maturity of GitLab Secure scanning tools, we've needed to add more granularity to our release process. Previously, GitLab shared a major version number for [all analyzers and tools](https://docs.gitlab.com/ee/user/application_security/sast/#supported-languages-and-frameworks). This requires all tools to share a major version, and prevents the use of [semantic version numbering](https://semver.org/). In GitLab 14.0, SAST removes the `SAST_ANALYZER_IMAGE_TAG` global variable in our [managed `SAST.gitlab-ci.yml`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Jobs/SAST.gitlab-ci.yml) CI template, in favor of the analyzer job variable setting the `major.minor` tag in the SAST vendored template.

Each analyzer job now has a scoped `SAST_ANALYZER_IMAGE_TAG` variable, which will be actively managed by GitLab and set to the `major` tag for the respective analyzer. To pin to a specific version, [change the variable value to the specific version tag](https://docs.gitlab.com/ee/user/application_security/sast/#pinning-to-minor-image-version).
If you override or maintain custom versions of `SAST.gitlab-ci.yml`, update your CI templates to stop referencing the global `SAST_ANALYZER_IMAGE_TAG`, and move it to a scoped analyzer job tag. We strongly encourage [inheriting and overriding our managed CI templates](https://docs.gitlab.com/ee/user/application_security/sast/#overriding-sast-jobs) to future-proof your CI templates. This change allows you to more granularly control future analyzer updates with a pinned `major.minor` version.
This deprecation and removal changes our [previously announced plan](https://about.gitlab.com/releases/2021/02/22/gitlab-13-9-released/#pin-static-analysis-analyzers-and-tools-to-minor-versions) to pin the Static Analysis tools.

### Hardcoded `master` in CI/CD templates

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

Our CI/CD templates have been updated to no longer use hard-coded references to a `master` branch. In 14.0, they all use a variable that points to your project's configured default branch instead. If your CI/CD pipeline relies on our built-in templates, verify that this change works with your current configuration. For example, if you have a `master` branch and a different default branch, the updates to the templates may cause changes to your pipeline behavior. For more information, [read the issue](https://gitlab.com/gitlab-org/gitlab/-/issues/324131).

### Helm v2 support

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

Helm v2 was [officially deprecated](https://helm.sh/blog/helm-v2-deprecation-timeline/) in November of 2020, with the `stable` repository being [de-listed from the Helm Hub](https://about.gitlab.com/blog/2020/11/09/ensure-auto-devops-work-after-helm-stable-repo/) shortly thereafter. With the release of GitLab 14.0, which will include the 5.0 release of the [GitLab Helm chart](https://docs.gitlab.com/charts/), Helm v2 will no longer be supported.

Users of the chart should [upgrade to Helm v3](https://helm.sh/docs/topics/v2_v3_migration/) to deploy GitLab 14.0 and later.

### Legacy DAST domain validation

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

The legacy method of DAST Domain Validation for CI/CD scans was deprecated in GitLab 13.8, and is removed in GitLab 14.0. This method of domain validation only disallows scans if the `DAST_FULL_SCAN_DOMAIN_VALIDATION_REQUIRED` environment variable is set to `true` in the `gitlab-ci.yml` file, and a `Gitlab-DAST-Permission` header on the site is not set to `allow`. This two-step method required users to opt in to using the variable before they could opt out from using the header.

For more information, see the [removal issue](https://gitlab.com/gitlab-org/gitlab/-/issues/293595).

### Legacy feature flags

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/254324).
</div>

Legacy feature flags became read-only in GitLab 13.4. GitLab 14.0 removes support for legacy feature flags, so you must migrate them to the [new version](https://docs.gitlab.com/ee/operations/feature_flags.html). You can do this by first taking a note (screenshot) of the legacy flag, then deleting the flag through the API or UI (you don't need to alter the code), and finally create a new Feature Flag with the same name as the legacy flag you deleted. Also, make sure the strategies and environments match the deleted flag. We created a [video tutorial](https://www.youtube.com/watch?v=CAJY2IGep7Y) to help with this migration.

### Legacy fields from DAST report

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

As a part of the migration to a common report format for all of the Secure scanners in GitLab, DAST is making changes to the DAST JSON report. Certain legacy fields were deprecated in 13.8 and have been completely removed in 14.0. These fields are `@generated`, `@version`, `site`, and `spider`. This should not affect any normal DAST operation, but does affect users who consume the JSON report in an automated way and use these fields. Anyone affected by these changes, and needs these fields for business reasons, is encouraged to open a new GitLab issue and explain the need.

For more information, see [the removal issue](https://gitlab.com/gitlab-org/gitlab/-/issues/33915).

### Legacy storage

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

As [announced in GitLab 13.0](https://about.gitlab.com/releases/2020/05/22/gitlab-13-0-released/#planned-removal-of-legacy-storage-in-14.0), [legacy storage](https://docs.gitlab.com/ee/administration/repository_storage_types.html#legacy-storage) has been removed in GitLab 14.0.

### License Compliance

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

In 13.0, we deprecated the License-Management CI template and renamed it License-Scanning. We have been providing backward compatibility by warning users of the old template to switch. Now in 14.0, we are completely removing the License-Management CI template. Read about it in [issue #216261](https://gitlab.com/gitlab-org/gitlab/-/issues/216261) or [this blog post](https://about.gitlab.com/blog/2021/02/08/composition-analysis-14-deprecations-and-removals/).

### Limit projects returned in `GET /groups/:id/`

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/257829).
</div>

To improve performance, we are limiting the number of projects returned from the `GET /groups/:id/` API call to 100. A complete list of projects can still be retrieved with the `GET /groups/:id/projects` API call.

### Make `pwsh` the default shell for newly-registered Windows Runners

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

In GitLab Runner 13.2, PowerShell Core support was added to the Shell executor. In 14.0, PowerShell Core, `pwsh` is now the default shell for newly-registered Windows runners. Windows `CMD` will still be available as a shell option for Windows runners. Refer to [issue #26419](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/26419) for details.

### Migrate from `SAST_DEFAULT_ANALYZERS` to `SAST_EXCLUDED_ANALYZERS`

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/229974).
</div>

Until GitLab 13.9, if you wanted to avoid running one particular GitLab SAST analyzer, you needed to remove it from the [long string of analyzers in the `SAST.gitlab-ci.yml` file](https://gitlab.com/gitlab-org/gitlab/-/blob/390afc431e7ce1ac253b35beb39f19e49c746bff/lib/gitlab/ci/templates/Security/SAST.gitlab-ci.yml#L12) and use that to set the [`SAST_DEFAULT_ANALYZERS`](https://docs.gitlab.com/ee/user/application_security/sast/#docker-images) variable in your project's CI file. If you did this, it would exclude you from future new analyzers because this string hard codes the list of analyzers to execute. We avoid this problem by inverting this variable's logic to exclude, rather than choose default analyzers.
Beginning with 13.9, [we migrated](https://gitlab.com/gitlab-org/gitlab/-/blob/14fed7a33bfdbd4663d8928e46002a5ef3e3282c/lib/gitlab/ci/templates/Security/SAST.gitlab-ci.yml#L13) to `SAST_EXCLUDED_ANALYZERS` in our `SAST.gitlab-ci.yml` file. We encourage anyone who uses a [customized SAST configuration](https://docs.gitlab.com/ee/user/application_security/sast/#customizing-the-sast-settings) in their project CI file to migrate to this new variable. If you have not overridden `SAST_DEFAULT_ANALYZERS`, no action is needed. The CI/CD variable `SAST_DEFAULT_ANALYZERS` has been removed in GitLab 14.0, which released on June 22, 2021.

### Off peak time mode configuration for Docker Machine autoscaling

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

In GitLab Runner 13.0, [issue #5069](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/5069), we introduced new timing options for the GitLab Docker Machine executor. In GitLab Runner 14.0, we have removed the old configuration option, [off peak time mode](https://docs.gitlab.com/runner/configuration/autoscale.html#off-peak-time-mode-configuration-deprecated).

### OpenSUSE Leap 15.1

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

Support for [OpenSUSE Leap 15.1 is being deprecated](https://gitlab.com/gitlab-org/omnibus-gitlab/-/merge_requests/5135). Support for 15.1 will be dropped in 14.0. We are now providing support for openSUSE Leap 15.2 packages.

### PostgreSQL 11 support

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

GitLab 14.0 requires PostgreSQL 12 or later. It offers [significant improvements](https://www.postgresql.org/about/news/postgresql-12-released-1976/) to indexing, partitioning, and general performance benefits.

Starting in GitLab 13.7, all new installations default to PostgreSQL version 12. From GitLab 13.8, single-node instances are automatically upgraded as well. If you aren't ready to upgrade, you can [opt out of automatic upgrades](https://docs.gitlab.com/omnibus/settings/database.html#opt-out-of-automatic-postgresql-upgrades).

### Redundant timestamp field from DORA metrics API payload

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/325931).
</div>

The [deployment frequency project-level API](https://docs.gitlab.com/ee/api/dora/metrics.html#list-project-deployment-frequencies) endpoint has been deprecated in favor of the [DORA 4 API](https://docs.gitlab.com/ee/api/dora/metrics.html), which consolidates all the metrics under one API with the specific metric as a required field. As a result, the timestamp field, which doesn't allow adding future extensions and causes performance issues, will be removed. With the old API, an example response would be `{ "2021-03-01": 3, "date": "2021-03-01", "value": 3 }`. The first key/value (`"2021-03-01": 3`) will be removed and replaced by the last two (`"date": "2021-03-01", "value": 3`).

### Release description in the Tags API

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/300887).
</div>

GitLab 14.0 removes support for the release description in the Tags API. You can no longer add a release description when [creating a new tag](https://docs.gitlab.com/ee/api/tags.html#create-a-new-tag). You also can no longer [create](https://docs.gitlab.com/ee/api/tags.html#create-a-new-release) or [update](https://docs.gitlab.com/ee/api/tags.html#update-a-release) a release through the Tags API. Please migrate to use the [Releases API](https://docs.gitlab.com/ee/api/releases/#create-a-release) instead.

### Ruby version changed in `Ruby.gitlab-ci.yml`

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

By default, the `Ruby.gitlab-ci.yml` file has included Ruby 2.5.

To better support the latest versions of Ruby, the template is changed to use `ruby:latest`, which is currently 3.0. To better understand the changes in Ruby 3.0, please reference the [Ruby-lang.org release announcement](https://www.ruby-lang.org/en/news/2020/12/25/ruby-3-0-0-released/).

Relevant Issue: [Updates Ruby version 2.5 to 3.0](https://gitlab.com/gitlab-org/gitlab/-/issues/329160)

### SAST analyzer `SAST_GOSEC_CONFIG` variable

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/301215).
</div>

With the release of [SAST Custom Rulesets](https://docs.gitlab.com/ee/user/application_security/sast/#customize-rulesets) in GitLab 13.5 we allow greater flexibility in configuration options for our Go analyzer (GoSec). As a result we no longer plan to support our less flexible [`SAST_GOSEC_CONFIG`](https://docs.gitlab.com/ee/user/application_security/sast/#analyzer-settings) analyzer setting. This variable was deprecated in GitLab 13.10.
GitLab 14.0 removes the old `SAST_GOSEC_CONFIG variable`. If you use or override `SAST_GOSEC_CONFIG` in your CI file, update your SAST CI configuration or pin to an older version of the GoSec analyzer. We strongly encourage [inheriting and overriding our managed CI templates](https://docs.gitlab.com/ee/user/application_security/sast/#overriding-sast-jobs) to future-proof your CI templates.

### Service Templates

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

Service Templates are [removed in GitLab 14.0](https://gitlab.com/groups/gitlab-org/-/epics/5672). They were used to apply identical settings to a large number of projects, but they only did so at the time of project creation.

While they solved part of the problem, _updating_ those values later proved to be a major pain point. [Project Integration Management](https://docs.gitlab.com/ee/user/admin_area/settings/project_integration_management.html) solves this problem by enabling you to create settings at the Group or Instance level, and projects within that namespace inheriting those settings.

### Success and failure for finished build metric conversion

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

In GitLab Runner 13.5, we introduced `failed` and `success` states for a job. To support Prometheus rules, we chose to convert `success/failure` to `finished` for the metric. In 14.0, the conversion has now been removed. Refer to [issue #26900](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/26900) for details.

### Terraform template version

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue]().
</div>

As we continuously [develop GitLab's Terraform integrations](https://gitlab.com/gitlab-org/gitlab/-/issues/325312), to minimize customer disruption, we maintain two GitLab CI/CD templates for Terraform:

- The ["latest version" template](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Terraform.latest.gitlab-ci.yml), which is updated frequently between minor releases of GitLab (such as 13.10, 13.11, etc).
- The ["major version" template](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Terraform.gitlab-ci.yml), which is updated only at major releases (such as 13.0, 14.0, etc).

At every major release of GitLab, the "latest version" template becomes the "major version" template, inheriting the "latest template" setup.
As we have added many new features to the Terraform integration, the new setup for the "major version" template can be considered a breaking change.

The latest template supports the [Terraform Merge Request widget](https://docs.gitlab.com/ee/user/infrastructure/iac/mr_integration.html) and
doesn't need additional setup to work with the [GitLab managed Terraform state](https://docs.gitlab.com/ee/user/infrastructure/iac/terraform_state.html).

To check the new changes, see the [new "major version" template](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Terraform.gitlab-ci.yml).

### Ubuntu 16.04 support

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

Ubuntu 16.04 [reached end-of-life in April 2021](https://ubuntu.com/about/release-cycle), and no longer receives maintenance updates. We strongly recommend users to upgrade to a newer release, such as 20.04.

GitLab 13.12 will be the last release with Ubuntu 16.04 support.

### Ubuntu 19.10 (Eoan Ermine) package

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

Ubuntu 19.10 (Eoan Ermine) reached end of life on Friday, July 17, 2020. In GitLab Runner 14.0, Ubuntu 19.10 (Eoan Ermine) is no longer available from our package distribution. Refer to [issue #26036](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/26036) for details.

### Unicorn in GitLab self-managed

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

[Support for Unicorn](https://gitlab.com/gitlab-org/omnibus-gitlab/-/issues/6078) has been removed in GitLab 14.0 in favor of Puma. [Puma has a multi-threaded architecture](https://docs.gitlab.com/ee/administration/operations/puma.html) which uses less memory than a multi-process application server like Unicorn. On GitLab.com, we saw a 40% reduction in memory consumption by using Puma.

### WIP merge requests renamed 'draft merge requests'

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

The WIP (work in progress) status for merge requests signaled to reviewers that the merge request in question wasn't ready to merge. We've renamed the WIP feature to **Draft**, a more inclusive and self-explanatory term. **Draft** clearly communicates the merge request in question isn't ready for review, and makes no assumptions about the progress being made toward it. **Draft** also reduces the cognitive load for new users, non-English speakers, and anyone unfamiliar with the WIP acronym.

### Web Application Firewall (WAF)

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

The Web Application Firewall (WAF) was deprecated in GitLab 13.6 and is removed from GitLab 14.0. The WAF had limitations inherent in the architectural design that made it difficult to meet the requirements traditionally expected of a WAF. By removing the WAF, GitLab is able to focus on improving other areas in the product where more value can be provided to users. Users who currently rely on the WAF can continue to use the free and open source [ModSecurity](https://github.com/SpiderLabs/ModSecurity) project, which is independent from GitLab. Additional details are available in the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/271276).

### Windows Server 1903 image support

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

In 14.0, we have removed Windows Server 1903. Microsoft ended support for this version on 2020-08-12. Refer to [issue #27551](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/27551) for details.

### Windows Server 1909 image support

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

In 14.0, we have removed Windows Server 1909. Microsoft ended support for this version on 2021-05-11. Refer to [issue #27899](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/27899) for details.

### `/usr/lib/gitlab-runner` symlink from package

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

In GitLab Runner 13.3, a symlink was added from `/user/lib/gitlab-runner/gitlab-runner` to `/usr/bin/gitlab-runner`. In 14.0, the symlink has been removed and the runner is now installed in `/usr/bin/gitlab-runner`. Refer to [issue #26651](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/26651) for details.

### `?w=1` URL parameter to ignore whitespace changes

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

To create a consistent experience for users based on their preferences, support for toggling whitespace changes via URL parameter has been removed in GitLab 14.0.

### `CI_PROJECT_CONFIG_PATH` variable

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

The `CI_PROJECT_CONFIG_PATH` [predefined project variable](https://docs.gitlab.com/ee/ci/variables/predefined_variables.html)
has been removed in favor of `CI_CONFIG_PATH`, which is functionally the same.

If you are using `CI_PROJECT_CONFIG_PATH` in your pipeline configurations,
please update them to use `CI_CONFIG_PATH` instead.

### `FF_RESET_HELPER_IMAGE_ENTRYPOINT` feature flag

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

In 14.0, we have deactivated the `FF_RESET_HELPER_IMAGE_ENTRYPOINT` feature flag. Refer to issue [#26679](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/26679) for details.

### `FF_SHELL_EXECUTOR_USE_LEGACY_PROCESS_KILL` feature flag

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

In [GitLab Runner 13.1](https://docs.gitlab.com/runner/executors/shell.html#gitlab-131-and-later), [issue #3376](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/3376), we introduced `sigterm` and then `sigkill` to a process in the Shell executor. We also introduced a new feature flag, `FF_SHELL_EXECUTOR_USE_LEGACY_PROCESS_KILL`, so you can use the previous process termination sequence. In GitLab Runner 14.0, [issue #6413](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/6413), the feature flag has been removed.

### `FF_USE_GO_CLOUD_WITH_CACHE_ARCHIVER` feature flag

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

GitLab Runner 14.0 removes the `FF_USE_GO_CLOUD_WITH_CACHE_ARCHIVER` feature flag. Refer to [issue #27175](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/27175) for details.

### `secret_detection_default_branch` job

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
- To discuss this change or learn more, see the [deprecation issue](https://gitlab.com/gitlab-org/gitlab/-/issues/297269).
</div>

To ensure Secret Detection was scanning both default branches and feature branches, we introduced two separate secret detection CI jobs (`secret_detection_default_branch` and `secret_detection`) in our managed [`Secret-Detection.gitlab-ci.yml`](https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/ci/templates/Security/Secret-Detection.gitlab-ci.yml) template. These two CI jobs created confusion and complexity in the CI rules logic. This deprecation moves the `rule` logic into the `script` section, which then determines how the `secret_detection` job is run (historic, on a branch, commits, etc).
If you override or maintain custom versions of `SAST.gitlab-ci.yml` or `Secret-Detection.gitlab-ci.yml`, you must update your CI templates. We strongly encourage [inheriting and overriding our managed CI templates](https://docs.gitlab.com/ee/user/application_security/secret_detection/#custom-settings-example) to future-proof your CI templates. GitLab 14.0 no longer supports the old `secret_detection_default_branch` job.

### `trace` parameter in `jobs` API

<div class="deprecation-notes">
- Announced in: GitLab <span class="milestone"></span>
- This is a [breaking change](https://docs.gitlab.com/ee/development/deprecation_guidelines/). Review the details carefully before upgrading.
</div>

GitLab Runner was updated in GitLab 13.4 to internally stop passing the `trace` parameter to the `/api/jobs/:id` endpoint. GitLab 14.0 deprecates the `trace` parameter entirely for all other requests of this endpoint. Make sure your [GitLab Runner version matches your GitLab version](https://docs.gitlab.com/runner/#gitlab-runner-versions) to ensure consistent behavior.
