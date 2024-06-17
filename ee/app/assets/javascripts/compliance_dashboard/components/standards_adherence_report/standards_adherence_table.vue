<script>
import { GlAlert, GlDisclosureDropdown } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  mapStandardsAdherenceQueryToFilters,
  convertProjectIdsToGraphQl,
} from 'ee/compliance_dashboard/utils';
import getProjectsInComplianceStandardsAdherence from 'ee/compliance_dashboard/graphql/compliance_projects_in_standards_adherence.query.graphql';
import { ALLOWED_FILTER_TOKENS, NONE, CHECKS, PROJECTS, STANDARDS } from './constants';
import AdherencesBaseTable from './base_table.vue';
import Filters from './filters.vue';
import GroupAdherences from './group_adherences.vue';

export default {
  name: 'ComplianceStandardsAdherenceTable',
  components: {
    GlAlert,
    GlDisclosureDropdown,
    Filters,
    AdherencesBaseTable,
    GroupAdherences,
  },
  props: {
    groupPath: {
      type: String,
      required: true,
    },
    globalProjectId: {
      type: Number,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      hasFilterValueError: false,
      hasRawTextError: false,
      projects: {
        list: [],
      },
      filters: {},
      selected: NONE,
    };
  },
  apollo: {
    projects: {
      query: getProjectsInComplianceStandardsAdherence,
      variables() {
        return {
          fullPath: this.groupPath,
        };
      },
      update(data) {
        const nodes = data?.group?.projects.nodes || [];
        return {
          list: nodes,
        };
      },
    },
  },
  computed: {
    graphQLGlobalProjectId() {
      return this.globalProjectId && convertProjectIdsToGraphQl([this.globalProjectId])[0];
    },

    projectsForFilter() {
      return this.globalProjectId ? null : this.projects.list;
    },

    dropdownItems() {
      return [
        {
          text: NONE,
        },
        {
          text: CHECKS,
        },
        ...(!this.globalProjectId ? [{ text: PROJECTS }] : []),
        {
          text: STANDARDS,
        },
      ];
    },
  },
  methods: {
    onFiltersChanged(filters) {
      this.hasFilterValueError = false;
      this.hasRawTextError = false;

      const availableProjectIDs = this.projects.list.map((item) => item.id);

      filters.forEach((filter) => {
        if (
          filter.type === 'standard' &&
          !ALLOWED_FILTER_TOKENS.standards.includes(filter.value.data)
        ) {
          this.hasFilterValueError = true;
        }
        if (filter.type === 'check' && !ALLOWED_FILTER_TOKENS.checks.includes(filter.value.data)) {
          this.hasFilterValueError = true;
        }
        if (filter.type === 'project' && !availableProjectIDs.includes(filter.value.data)) {
          this.hasFilterValueError = true;
        }
        if (!filter.type) {
          this.hasRawTextError = true;
        }
      });

      if (!this.hasFilterValueError) {
        this.filters = mapStandardsAdherenceQueryToFilters(filters);
      }
    },
    clearFilters() {
      this.filters = {};
    },
    onGroupSelected(selected) {
      this.selected = selected.text;

      this.$router.push({
        query: {
          ...this.$route.query,
          before: undefined,
          after: undefined,
        },
      });
    },
  },
  i18n: {
    rawFiltersNotSupported: s__(
      'ComplianceStandardsAdherence|Raw text search is not currently supported. Please use the available filters.',
    ),
    invalidFilterValue: s__(
      'ComplianceStandardsAdherence|Raw filter values is not currently supported. Please use available values.',
    ),
    groupByText: s__('ComplianceStandardsAdherence|Group by'),
    filterByText: s__('ComplianceStandardsAdherence|Filter by'),
  },
  NONE,
  CHECKS,
  PROJECTS,
};
</script>

<template>
  <section>
    <gl-alert v-if="hasFilterValueError" variant="warning" class="gl-mt-3" :dismissible="false">
      {{ $options.i18n.invalidFilterValue }}
    </gl-alert>
    <gl-alert v-if="hasRawTextError" variant="warning" class="gl-mt-3" :dismissible="false">
      {{ $options.i18n.rawFiltersNotSupported }}
    </gl-alert>
    <div class="gl-display-flex gl-md-flex-direction-row row-content-block gl-border-0">
      <div class="gl-display-flex gl-flex-direction-column">
        <label data-testid="dropdown-label" class="gl-leading-normal">
          {{ $options.i18n.groupByText }}
        </label>
        <gl-disclosure-dropdown
          class="gl-mr-6 gl-lg-mb-0"
          :items="dropdownItems"
          :toggle-text="selected"
          @action="onGroupSelected"
        />
      </div>
      <div class="gl-display-flex gl-flex-direction-column gl-flex-grow-2">
        <label for="target-branch-input" class="gl-leading-normal">
          {{ $options.i18n.filterByText }}
        </label>
        <filters
          class="gl-mb-2 gl-lg-mb-0"
          :projects="projectsForFilter"
          :group-path="groupPath"
          @submit="onFiltersChanged"
          @clear="clearFilters"
        />
      </div>
    </div>
    <div v-if="selected !== $options.NONE">
      <group-adherences
        :group-path="groupPath"
        :filters="filters"
        :selected="selected"
        :projects="projects.list"
      />
    </div>
    <div v-else>
      <adherences-base-table
        :group-path="groupPath"
        :filters="filters"
        :project-id="graphQLGlobalProjectId"
      />
    </div>
  </section>
</template>

<style>
.gl-accordion-item-header {
  .gl-button-text {
    font-weight: bold;
    color: black;
    font-size: 14px;
    margin-left: 10px;

    .gl-dark & {
      color: var(--gl-text-color);
    }
  }
}
</style>
