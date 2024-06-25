<script>
import { GlAlert, GlLink, GlSprintf, GlKeysetPagination } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { fetchPolicies } from '~/lib/graphql';
import { s__ } from '~/locale';

import complianceFrameworks from './graphql/compliance_frameworks_list.query.graphql';
import FrameworksTable from './frameworks_table.vue';

const FRAMEWORK_LIMIT = 20;

export default {
  name: 'ComplianceProjectsReport',
  components: {
    GlAlert,
    GlLink,
    GlKeysetPagination,
    GlSprintf,
    FrameworksTable,
  },
  inject: {
    featurePipelineMaintenanceModeEnabled: {
      taype: Boolean,
      default: false,
    },
    migratePipelineToPolicyPath: {
      type: String,
      default: '#',
    },
    pipelineExecutionPolicyPath: {
      type: String,
      required: false,
      default: '#',
    },
  },
  props: {
    rootAncestor: {
      type: Object,
      required: true,
    },
    groupPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      hasQueryError: false,
      frameworks: { nodes: [] },
      searchString: '',
      maintenanceModeDismissed: false,
      cursor: {
        before: null,
        after: null,
      },
    };
  },
  apollo: {
    frameworks: {
      query: complianceFrameworks,
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      variables() {
        return {
          fullPath: this.rootAncestor.path,
          search: this.searchString,
          ...this.cursor,
          [this.cursor.before ? 'last' : 'first']: FRAMEWORK_LIMIT,
        };
      },
      update(data) {
        return data.namespace.complianceFrameworks;
      },
      error(e) {
        Sentry.captureException(e);
        this.hasQueryError = true;
      },
    },
  },
  computed: {
    isLoading() {
      return Boolean(this.$apollo.queries.frameworks.loading);
    },
    showMaintenanceModeAlert() {
      return this.featurePipelineMaintenanceModeEnabled && !this.maintenanceModeDismissed;
    },
  },
  methods: {
    onPrevPage() {
      this.cursor = {
        before: this.frameworks.pageInfo.startCursor,
        after: null,
      };
    },

    onNextPage() {
      this.cursor = {
        after: this.frameworks.pageInfo.endCursor,
        before: null,
      };
    },

    onSearch(searchString) {
      this.cursor = {
        before: null,
        after: null,
      };
      this.searchString = searchString;
    },
    handleOnDismissMaintenanceMode() {
      this.maintenanceModeDismissed = true;
    },
  },
  i18n: {
    deprecationWarning: {
      title: s__('ComplianceReport|Compliance pipelines are deprecated'),
      message: s__(
        'ComplianceReport|Avoid creating new compliance pipelines and use pipeline execution policy actions instead. %{linkStart}Pipeline execution policy%{linkEnd} actions provide the ability to enforce CI/CD jobs, execute security scans, and better manage compliance.',
      ),
      details: s__(
        'ComplianceReport|For more information, see %{linkStart}how to migrate from compliance pipelines to pipeline execution policy actions%{linkEnd}.',
      ),
    },
    queryError: s__(
      'ComplianceReport|Unable to load the compliance framework report. Refresh the page and try again.',
    ),
  },
};
</script>

<template>
  <section class="gl-display-flex gl-flex-direction-column">
    <gl-alert
      v-if="showMaintenanceModeAlert"
      variant="warning"
      class="gl-my-3"
      data-testid="maintenance-mode-alert"
      :dismissible="true"
      :title="$options.i18n.deprecationWarning.title"
      @dismiss="handleOnDismissMaintenanceMode"
    >
      <p>
        <gl-sprintf :message="$options.i18n.deprecationWarning.message">
          <template #link="{ content }">
            <gl-link :href="pipelineExecutionPolicyPath" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>

      <gl-sprintf :message="$options.i18n.deprecationWarning.details">
        <template #link="{ content }">
          <gl-link :href="migratePipelineToPolicyPath" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>

    <gl-alert
      v-if="hasQueryError"
      variant="danger"
      class="gl-my-3"
      :dismissible="false"
      data-testid="query-error-alert"
    >
      {{ $options.i18n.queryError }}
    </gl-alert>

    <template v-else>
      <frameworks-table
        :root-ancestor="rootAncestor"
        :group-path="groupPath"
        :is-loading="isLoading"
        :frameworks="frameworks.nodes"
        @search="onSearch"
      />

      <gl-keyset-pagination
        v-bind="frameworks.pageInfo"
        class="gl-align-self-center gl-mt-6"
        @prev="onPrevPage"
        @next="onNextPage"
      />
    </template>
  </section>
</template>
