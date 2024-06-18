<script>
import { GlTab, GlTabs, GlTooltipDirective } from '@gitlab/ui';

import { helpPagePath } from '~/helpers/help_page_helper';

import Tracking from '~/tracking';
import {
  ROUTE_STANDARDS_ADHERENCE,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  ROUTE_VIOLATIONS,
  i18n,
} from '../constants';

import ReportHeader from './shared/report_header.vue';
import ReportsExport from './shared/export_disclosure_dropdown.vue';

const tabConfigs = {
  [ROUTE_STANDARDS_ADHERENCE]: {
    testId: 'standards-adherence-tab',
    title: i18n.standardsAdherenceTab,
  },
  [ROUTE_VIOLATIONS]: {
    testId: 'violations-tab',
    title: i18n.violationsTab,
  },
  [ROUTE_FRAMEWORKS]: {
    testId: 'frameworks-tab',
    title: i18n.frameworksTab,
  },
  [ROUTE_PROJECTS]: {
    testId: 'projects-tab',
    title: i18n.projectsTab,
  },
};

export default {
  name: 'ComplianceReportsApp',
  components: {
    GlTabs,
    GlTab,
    ReportHeader,
    ReportsExport,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [Tracking.mixin()],
  inject: [
    'mergeCommitsCsvExportPath',
    'projectFrameworksCsvExportPath',
    'violationsCsvExportPath',
    'adherencesCsvExportPath',
    'frameworksCsvExportPath',
  ],
  props: {
    availableTabs: {
      type: Array,
      required: true,
    },
  },
  computed: {
    tabs() {
      return this.availableTabs.map((tabName) => {
        const tabConfig = tabConfigs[tabName];
        return {
          title: tabConfig.title,
          titleAttributes: { 'data-testid': tabConfig.testId },
          target: tabName,
          // eslint-disable-next-line @gitlab/require-i18n-strings
          contentTestId: `${tabConfig.testId}-content`,
        };
      });
    },
    tabIndex() {
      return this.tabs.findIndex((tab) => tab.target === this.$route.name);
    },
  },
  methods: {
    goTo(name) {
      if (this.$route.name !== name) {
        this.$router.push({ name });
        this.track('click_report_tab', { label: name });
      }
    },
  },
  ROUTE_STANDARDS: ROUTE_STANDARDS_ADHERENCE,
  ROUTE_VIOLATIONS,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  i18n,
  documentationPath: helpPagePath('user/compliance/compliance_center/index.md'),
};
</script>
<template>
  <div>
    <report-header
      :heading="$options.i18n.heading"
      :subheading="$options.i18n.subheading"
      :documentation-path="$options.documentationPath"
    >
      <template #actions>
        <reports-export
          class="gl-float-right"
          :project-frameworks-csv-export-path="projectFrameworksCsvExportPath"
          :merge-commits-csv-export-path="mergeCommitsCsvExportPath"
          :violations-csv-export-path="violationsCsvExportPath"
          :adherences-csv-export-path="adherencesCsvExportPath"
          :frameworks-csv-export-path="frameworksCsvExportPath"
        />
      </template>
    </report-header>

    <gl-tabs :value="tabIndex" content-class="gl-p-0" lazy>
      <gl-tab
        v-for="tab in tabs"
        :key="tab.target"
        :title="tab.title"
        :title-link-attributes="tab.titleAttributes"
        :data-testid="tab.contentTestId"
        @click="goTo(tab.target)"
      />
    </gl-tabs>
    <router-view />
  </div>
</template>
