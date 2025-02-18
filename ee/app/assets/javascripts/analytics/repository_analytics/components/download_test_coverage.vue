<script>
import { GlAlert, GlButton, GlCollapsibleListbox, GlModal, GlModalDirective } from '@gitlab/ui';
import { pikadayToString } from '~/lib/utils/datetime_utility';
import { mergeUrlParams } from '~/lib/utils/url_utility';
import { __, sprintf } from '~/locale';
import { downloadi18n as i18n, lastXDays } from '../constants';
import SelectProjectsDropdown from './select_projects_dropdown.vue';

export default {
  name: 'DownloadTestCoverage',
  components: {
    GlAlert,
    GlButton,
    GlCollapsibleListbox,
    GlModal,
    SelectProjectsDropdown,
  },
  directives: {
    GlModalDirective,
  },
  inject: {
    groupAnalyticsCoverageReportsPath: {
      default: '',
    },
  },
  data() {
    return {
      hasError: false,
      allProjectsSelected: false,
      selectedDateRange: this.$options.dateRangeOptions[2],
      selectedProjectIds: [],
    };
  },
  computed: {
    cancelModalButton() {
      return {
        text: __('Cancel'),
      };
    },
    csvReportPath() {
      const today = new Date();
      const endDate = pikadayToString(today);
      today.setDate(today.getDate() - this.selectedDateRange.value);
      const startDate = pikadayToString(today);

      const queryParams = {
        start_date: startDate,
        end_date: endDate,
      };

      // not including a project_ids param is the same as selecting all the projects
      if (!this.allProjectsSelected && this.selectedProjectIds.length) {
        queryParams.project_ids = this.selectedProjectIds;
      }

      return mergeUrlParams(queryParams, this.groupAnalyticsCoverageReportsPath, {
        spreadArrays: true,
      });
    },
    downloadCSVModalButton() {
      return {
        text: this.$options.i18n.downloadCSVModalButton,
        attributes: {
          variant: 'confirm',
          href: this.csvReportPath,
          rel: 'nofollow',
          download: '',
          disabled: this.isDownloadButtonDisabled,
          'data-testid': 'group-code-coverage-download-button',
        },
      };
    },
    isDownloadButtonDisabled() {
      return !this.allProjectsSelected && !this.selectedProjectIds.length;
    },
  },
  methods: {
    clickDateRange(dateRangeValue) {
      this.selectedDateRange = this.$options.dateRangeOptions.find(
        ({ value }) => value === dateRangeValue,
      );
    },
    clickSelectAllProjects() {
      this.$refs.projectsDropdown.clickSelectAllProjects();
    },
    dismissError() {
      this.hasError = false;
    },
    projectsQueryError() {
      this.hasError = true;
    },
    selectAllProjects() {
      this.allProjectsSelected = true;
      this.selectedProjectIds = [];
    },
    selectProject(ids) {
      this.allProjectsSelected = false;
      this.selectedProjectIds = ids;
    },
  },
  i18n,
  dateRangeOptions: [
    { value: 7, text: __('Last week') },
    { value: 14, text: sprintf(__('Last 2 weeks')) },
    { value: 30, text: sprintf(lastXDays, { days: 30 }) },
    { value: 60, text: sprintf(lastXDays, { days: 60 }) },
    { value: 90, text: sprintf(lastXDays, { days: 90 }) },
  ],
};
</script>

<template>
  <div class="gl-w-full gl-sm-w-auto gl-sm-ml-3">
    <gl-button
      v-gl-modal-directive="'download-csv-modal'"
      category="primary"
      variant="confirm"
      class="gl-w-full gl-sm-w-auto"
      data-testid="group-code-coverage-modal-button"
      :aria-label="$options.i18n.downloadCSVButton"
      >{{ $options.i18n.downloadCSVButton }}</gl-button
    >

    <gl-modal
      modal-id="download-csv-modal"
      :title="$options.i18n.downloadTestCoverageHeader"
      no-fade
      :action-primary="downloadCSVModalButton"
      :action-cancel="cancelModalButton"
    >
      <gl-alert v-if="hasError" variant="danger" @dismiss="dismissError">{{
        $options.i18n.queryErrorMessage
      }}</gl-alert>
      <div>{{ $options.i18n.downloadCSVModalDescription }}</div>
      <div class="gl-my-4">
        <label class="gl-block col-form-label-sm col-form-label">
          {{ $options.i18n.projectDropdownHeader }}
        </label>

        <div class="gl-display-inline-block gl-w-1/2">
          <select-projects-dropdown
            ref="projectsDropdown"
            @projects-query-error="projectsQueryError"
            @select-all-projects="selectAllProjects"
            @select-project="selectProject"
          />
        </div>

        <gl-button
          class="gl-ml-2"
          variant="link"
          data-testid="group-code-coverage-select-all-projects-button"
          @click="clickSelectAllProjects()"
          >{{ $options.i18n.projectSelectAll }}</gl-button
        >
      </div>

      <div class="gl-my-4">
        <label class="gl-block col-form-label-sm col-form-label">
          {{ $options.i18n.dateRangeHeader }}
        </label>
        <gl-collapsible-listbox
          block
          toggle-class="gl-w-1/2"
          :header-text="$options.i18n.dateRangeHeader"
          :items="$options.dateRangeOptions"
          :selected="selectedDateRange.value"
          :toggle-text="selectedDateRange.text"
          @select="clickDateRange"
        />
      </div>
    </gl-modal>
  </div>
</template>
