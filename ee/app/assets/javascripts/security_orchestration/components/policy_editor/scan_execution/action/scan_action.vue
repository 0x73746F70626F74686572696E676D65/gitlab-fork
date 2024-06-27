<script>
import { isEmpty } from 'lodash';
import { GlCollapsibleListbox, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  REPORT_TYPE_DAST,
  REPORT_TYPE_DEPENDENCY_SCANNING,
  REPORT_TYPE_CONTAINER_SCANNING,
} from '~/vue_shared/security_reports/constants';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { isProject, isGroup } from 'ee/security_orchestration/components/utils';
import SectionLayout from '../../section_layout.vue';
import { ACTION_AND_LABEL, RULE_MODE_SCANNERS } from '../../constants';
import ScanFilterSelector from '../../scan_filter_selector.vue';
import {
  DEFAULT_SCANNER,
  SCANNER_HUMANIZED_TEMPLATE,
  SCANNER_HUMANIZED_TEMPLATE_ALT,
  POLICY_ACTION_BUILDER_TAGS_ERROR_KEY,
  POLICY_ACTION_BUILDER_DAST_PROFILES_ERROR_KEY,
} from '../constants';
import { buildScannerAction } from '../lib';
import { CI_VARIABLE, FILTERS, TEMPLATE } from './scan_filters/constants';
import CiVariablesSelectors from './scan_filters/ci_variables_selectors.vue';
import TemplateSelector from './scan_filters/template_selector.vue';
import GroupDastProfileSelector from './scan_filters/group_dast_profile_selector.vue';
import ProjectDastProfileSelector from './scan_filters/project_dast_profile_selector.vue';
import RunnerTagsFilter from './scan_filters/runner_tags_filter.vue';

export default {
  ACTION_AND_LABEL,
  CI_VARIABLE,
  FILTERS,
  SCANNERS: RULE_MODE_SCANNERS,
  TEMPLATE,
  POLICY_ACTION_BUILDER_DAST_PROFILES_ERROR_KEY,
  POLICY_ACTION_BUILDER_TAGS_ERROR_KEY,
  components: {
    GlCollapsibleListbox,
    GlSprintf,
    SectionLayout,
    CiVariablesSelectors,
    ProjectDastProfileSelector,
    GroupDastProfileSelector,
    RunnerTagsFilter,
    ScanFilterSelector,
    TemplateSelector,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['namespacePath', 'namespaceType'],
  props: {
    initAction: {
      type: Object,
      required: true,
    },
    actionIndex: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  data() {
    return {
      filters: {
        [CI_VARIABLE]: false,
      },
      selectedScanner: this.initAction.scan || DEFAULT_SCANNER,
    };
  },
  computed: {
    actionScannerList() {
      return Object.entries(RULE_MODE_SCANNERS).map(([value, text]) => ({
        value,
        text,
      }));
    },
    ciVariables() {
      return this.initAction.variables || {};
    },
    isCIVariableSelectorSelected() {
      return (
        this.isFilterSelected(this.$options.CI_VARIABLE) || Object.keys(this.ciVariables).length > 0
      );
    },
    isDast() {
      return this.selectedScanner === REPORT_TYPE_DAST;
    },
    selectedScannerText() {
      return RULE_MODE_SCANNERS[this.selectedScanner];
    },
    isFirstAction() {
      return this.actionIndex === 0;
    },
    isGroup() {
      return isGroup(this.namespaceType);
    },
    isProject() {
      return isProject(this.namespaceType);
    },
    hasTemplateSelector() {
      return (
        this.glFeatures.scanExecutionPoliciesWithLatestTemplates ||
        this.glFeatures.scanExecutionPoliciesWithLatestTemplatesGroup
      );
    },
    siteProfile() {
      return this.initAction.site_profile?.trim() ?? '';
    },
    scannerProfile() {
      return this.initAction.scanner_profile?.trim() ?? '';
    },
    tags() {
      return this.initAction.tags || [];
    },
    scannerHumanizedMessage() {
      const isScanningReport = [
        REPORT_TYPE_CONTAINER_SCANNING,
        REPORT_TYPE_DEPENDENCY_SCANNING,
      ].includes(this.selectedScanner);

      return isScanningReport ? SCANNER_HUMANIZED_TEMPLATE_ALT : SCANNER_HUMANIZED_TEMPLATE;
    },
  },
  methods: {
    isFilterSelected(filter) {
      return this.filters[filter];
    },
    emitFilterChanges(filter) {
      const updatedAction = { ...this.initAction };
      if (filter === CI_VARIABLE) delete updatedAction.variables;
      if (filter === TEMPLATE) delete updatedAction.template;
      this.$emit('changed', updatedAction);
    },
    removeFilter(filter) {
      const newFilters = { ...this.filters };
      delete newFilters[filter];
      this.filters = newFilters;
      this.emitFilterChanges(filter);
    },
    removeYamlProperty(property) {
      const updatedAction = { ...this.initAction };
      delete updatedAction[property];
      this.$emit('changed', updatedAction);
    },
    selectFilter(filter) {
      this.filters = {
        ...this.filters,
        [filter]: true,
      };

      if (filter === CI_VARIABLE) {
        this.triggerChanged({ variables: { '': '' } });
      }
    },
    setSelectedScanner({
      scanner = this.selectedScanner,
      siteProfile = this.siteProfile,
      scannerProfile = this.scannerProfile,
    }) {
      const updatedAction = buildScannerAction({
        scanner,
        siteProfile,
        scannerProfile,
        id: this.initAction.id,
      });

      const { tags, variables } = this.initAction;

      if (tags) {
        updatedAction.tags = [...tags];
      }

      if (scanner !== this.selectedScanner) {
        this.selectedScanner = scanner;
        this.filters = {};
      } else if (!isEmpty(variables)) {
        updatedAction.variables = { ...variables };
      }

      this.$emit('changed', updatedAction);
    },
    triggerChanged(value) {
      this.$emit('changed', { ...this.initAction, ...value });
    },
  },
  i18n: {
    scannersHeaderText: s__('ScanExecutionPolicy|Select a scanner'),
  },
};
</script>

<template>
  <div>
    <div
      v-if="!isFirstAction"
      class="gl-text-gray-500 gl-mb-4 gl-ml-5"
      data-testid="action-and-label"
    >
      {{ $options.ACTION_AND_LABEL }}
    </div>
    <section-layout class="gl-pb-0" :show-remove-button="false">
      <template #content>
        <section-layout class="gl-w-full gl-bg-white" @remove="$emit('remove')">
          <template #content>
            <gl-sprintf :message="scannerHumanizedMessage">
              <template #scan>
                <gl-collapsible-listbox
                  data-testid="scan-type-selector"
                  :items="actionScannerList"
                  :header-text="$options.i18n.scannersHeaderText"
                  :selected="selectedScanner"
                  :toggle-text="selectedScannerText"
                  @select="setSelectedScanner({ scanner: $event })"
                />
              </template>
            </gl-sprintf>
          </template>
        </section-layout>
      </template>
    </section-layout>
    <section-layout class="gl-pt-3" :show-remove-button="false">
      <template #content>
        <project-dast-profile-selector
          v-if="isProject && isDast"
          :full-path="namespacePath"
          :saved-scanner-profile-name="scannerProfile"
          :saved-site-profile-name="siteProfile"
          @error="$emit('parsing-error', $options.POLICY_ACTION_BUILDER_DAST_PROFILES_ERROR_KEY)"
          @profiles-selected="setSelectedScanner"
        />

        <group-dast-profile-selector
          v-if="isGroup && isDast"
          :saved-scanner-profile-name="scannerProfile"
          :saved-site-profile-name="siteProfile"
          @set-profile="setSelectedScanner"
        />

        <runner-tags-filter
          :selected="tags"
          @remove="removeYamlProperty('tags')"
          @input="triggerChanged"
          @error="$emit('parsing-error', $options.POLICY_ACTION_BUILDER_TAGS_ERROR_KEY)"
        />

        <template-selector
          v-if="hasTemplateSelector"
          :selected="initAction.template"
          @input="triggerChanged"
          @remove="removeFilter($options.TEMPLATE)"
        />

        <ci-variables-selectors
          v-if="isCIVariableSelectorSelected"
          class="gl-bg-white"
          :scan-type="initAction.scan"
          :selected="initAction.variables"
          @remove="removeFilter($options.CI_VARIABLE)"
          @input="triggerChanged"
        />

        <scan-filter-selector
          class="gl-w-full gl-bg-white"
          :filters="$options.FILTERS"
          :selected="filters"
          @select="selectFilter"
        />
      </template>
    </section-layout>
  </div>
</template>
