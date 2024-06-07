<script>
import { intersection } from 'lodash';
import { GlIcon, GlLink, GlLoadingIcon, GlSprintf, GlTable, GlTooltipDirective } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { getSecurityPolicyListUrl } from '~/editor/extensions/source_editor_security_policy_schema_ext';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { DATE_ONLY_FORMAT } from '~/lib/utils/datetime_utility';
import { getParameterByName, setUrlParams, updateHistory } from '~/lib/utils/url_utility';
import { extractTypeParameter } from 'ee/security_orchestration/components/policies/utils';
import { getPolicyType } from '../../utils';
import DrawerWrapper from '../policy_drawer/drawer_wrapper.vue';
import { isPolicyInherited, policyHasNamespace, isGroup, isProject } from '../utils';
import {
  POLICY_SOURCE_OPTIONS,
  POLICY_TYPE_FILTER_OPTIONS,
  PIPELINE_EXECUTION_FILTER_OPTION,
  POLICY_TYPES_WITH_INHERITANCE,
} from './constants';
import BreakingChangesIcon from './breaking_changes_icon.vue';
import SourceFilter from './filters/source_filter.vue';
import TypeFilter from './filters/type_filter.vue';
import EmptyState from './empty_state.vue';
import ListComponentScope from './list_component_scope.vue';

const getPoliciesWithType = (policies, policyType) =>
  policies.map((policy) => ({
    ...policy,
    policyType,
  }));

export default {
  components: {
    BreakingChangesIcon,
    GlIcon,
    GlLink,
    GlLoadingIcon,
    GlSprintf,
    GlTable,
    EmptyState,
    ListComponentScope,
    SourceFilter,
    TypeFilter,
    DrawerWrapper,
    TimeAgoTooltip,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['customCiToggleEnabled', 'namespacePath', 'namespaceType', 'disableScanPolicyUpdate'],
  props: {
    hasPolicyProject: {
      type: Boolean,
      required: false,
      default: false,
    },
    isLoadingLinkedSpps: {
      type: Boolean,
      required: false,
      default: false,
    },
    isLoadingPolicies: {
      type: Boolean,
      required: false,
      default: false,
    },
    selectedPolicySource: {
      type: String,
      required: false,
      default: POLICY_SOURCE_OPTIONS.ALL.value,
    },
    linkedSppItems: {
      type: Array,
      required: false,
      default: () => [],
    },
    shouldUpdatePolicyList: {
      type: Boolean,
      required: false,
      default: false,
    },
    pipelineExecutionPolicies: {
      type: Array,
      required: false,
      default: () => [],
    },
    scanExecutionPolicies: {
      type: Array,
      required: false,
      default: () => [],
    },
    scanResultPolicies: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    const selectedPolicyType = extractTypeParameter(
      getParameterByName('type'),
      this.customCiToggleEnabled,
    );

    return {
      selectedPolicy: null,
      selectedPolicyType,
    };
  },
  computed: {
    policyTypeFilterOptions() {
      return this.pipelineExecutionPolicyEnabled
        ? {
            ...POLICY_TYPE_FILTER_OPTIONS,
            ...PIPELINE_EXECUTION_FILTER_OPTION,
          }
        : POLICY_TYPE_FILTER_OPTIONS;
    },
    pipelineExecutionPolicyEnabled() {
      return this.customCiToggleEnabled && this.glFeatures.pipelineExecutionPolicyType;
    },
    showLoader() {
      return this.isLoadingLinkedSpps && this.isProject;
    },
    isProject() {
      return isProject(this.namespaceType);
    },
    isGroup() {
      return isGroup(this.namespaceType);
    },
    allPolicyTypes() {
      return {
        [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]: this.scanExecutionPolicies,
        [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]: this.scanResultPolicies,
        ...(this.pipelineExecutionPolicyEnabled
          ? {
              [PIPELINE_EXECUTION_FILTER_OPTION.PIPELINE_EXECUTION.value]: this
                .pipelineExecutionPolicies,
            }
          : {}),
      };
    },
    policies() {
      let policyTypes =
        this.selectedPolicyType === POLICY_TYPE_FILTER_OPTIONS.ALL.value
          ? Object.keys(this.allPolicyTypes)
          : [this.selectedPolicyType];

      if (this.selectedPolicySource === POLICY_SOURCE_OPTIONS.INHERITED.value) {
        policyTypes = intersection(policyTypes, POLICY_TYPES_WITH_INHERITANCE);
      }

      const policies = policyTypes.map((type) =>
        getPoliciesWithType(this.allPolicyTypes[type], this.policyTypeFilterOptions[type].text),
      );

      return policies.flat();
    },
    hasSelectedPolicy() {
      return Boolean(this.selectedPolicy);
    },
    typeLabel() {
      if (this.isGroup) {
        return this.$options.i18n.groupTypeLabel;
      }
      return this.$options.i18n.projectTypeLabel;
    },
    policyType() {
      // eslint-disable-next-line no-underscore-dangle
      return this.selectedPolicy ? getPolicyType(this.selectedPolicy.__typename) : '';
    },
    hasExistingPolicies() {
      return !(
        this.selectedPolicyType === POLICY_TYPE_FILTER_OPTIONS.ALL.value &&
        this.selectedPolicySource === POLICY_SOURCE_OPTIONS.ALL.value &&
        !this.policies.length
      );
    },
    fields() {
      return [
        {
          key: 'status',
          label: '',
          thClass: 'gl-w-3',
          tdAttr: { 'data-testid': 'policy-status-cell' },
        },
        {
          key: 'name',
          label: __('Name'),
          thClass: 'gl-w-3/10',
          sortable: true,
        },
        {
          key: 'policyType',
          label: s__('SecurityOrchestration|Policy type'),
          sortable: true,
          tdAttr: { 'data-testid': 'policy-type-cell' },
        },
        {
          key: 'source',
          label: s__('SecurityOrchestration|Source'),
          sortable: true,
          tdAttr: { 'data-testid': 'policy-source-cell' },
        },
        {
          key: 'scope',
          label: s__('SecurityOrchestration|Scope'),
          sortable: true,
          tdAttr: { 'data-testid': 'policy-scope-cell' },
        },
        {
          key: 'updatedAt',
          label: __('Last modified'),
          sortable: true,
        },
      ];
    },
  },
  watch: {
    shouldUpdatePolicyList(newShouldUpdatePolicyList) {
      if (newShouldUpdatePolicyList) {
        this.deselectPolicy();
      }
    },
  },
  methods: {
    showBreakingChangesIcon(deprecatedProperties) {
      return deprecatedProperties?.length > 0;
    },
    policyListUrlArgs(source) {
      return { namespacePath: source?.namespace?.fullPath || '' };
    },
    getPolicyText(source) {
      return source?.namespace?.name || '';
    },
    getSecurityPolicyListUrl,
    isPolicyInherited,
    policyHasNamespace,
    presentPolicyDrawer(rows) {
      if (rows.length === 0) return;

      const [selectedPolicy] = rows;
      this.selectedPolicy = null;

      /**
       * According to design spec drawer should be closed
       * and opened when drawer content changes
       * it forces drawer to close and open with new content
       */
      this.$nextTick(() => {
        this.selectedPolicy = selectedPolicy;
      });
    },
    deselectPolicy() {
      this.selectedPolicy = null;

      // Refs are required by BTable to manipulate the selection
      // issue: https://gitlab.com/gitlab-org/gitlab-ui/-/issues/1531
      const bTable = this.$refs.policiesTable.$children[0];
      bTable.clearSelected();

      if (this.shouldUpdatePolicyList) {
        this.$emit('cleared-selected');
      }
    },
    convertFilterValue(defaultValue, value) {
      return value === defaultValue ? undefined : value.toLowerCase();
    },
    setTypeFilter(type) {
      this.deselectPolicy();

      const value = this.convertFilterValue(POLICY_TYPE_FILTER_OPTIONS.ALL.value, type);
      updateHistory({
        url: setUrlParams({ type: value }),
        title: document.title,
        replace: true,
      });
      this.selectedPolicyType = type;
    },
    setSourceFilter(source) {
      this.deselectPolicy();

      const value = this.convertFilterValue(POLICY_SOURCE_OPTIONS.ALL.value, source);
      updateHistory({
        url: setUrlParams({ source: value }),
        title: document.title,
        replace: true,
      });
      this.$emit('update-policy-source', source);
    },
  },
  dateTimeFormat: DATE_ONLY_FORMAT,
  i18n: {
    inheritedLabel: s__('SecurityOrchestration|Inherited from %{namespace}'),
    inheritedShortLabel: s__('SecurityOrchestration|Inherited'),
    statusEnabled: __('Enabled'),
    statusDisabled: __('Disabled'),
    groupTypeLabel: s__('SecurityOrchestration|This group'),
    projectTypeLabel: s__('SecurityOrchestration|This project'),
  },
};
</script>

<template>
  <div>
    <div class="gl-pt-5 gl-px-5 gl-bg-gray-10">
      <div class="row gl-justify-content-space-between gl-align-items-center">
        <div class="col-12 col-sm-8 col-md-6 col-lg-5 row">
          <type-filter
            :value="selectedPolicyType"
            class="col-6"
            data-testid="policy-type-filter"
            @input="setTypeFilter"
          />
          <source-filter
            :value="selectedPolicySource"
            class="col-6"
            data-testid="policy-source-filter"
            @input="setSourceFilter"
          />
        </div>
      </div>
    </div>

    <gl-table
      ref="policiesTable"
      data-testid="policies-list"
      :busy="isLoadingPolicies"
      :items="policies"
      :fields="fields"
      sort-by="updatedAt"
      sort-desc
      stacked="md"
      show-empty
      hover
      selectable
      select-mode="single"
      selected-variant="primary"
      @row-selected="presentPolicyDrawer"
    >
      <template #cell(status)="{ item: { enabled, name, deprecatedProperties } }">
        <div class="gl-display-flex gl-gap-4">
          <gl-icon
            v-if="enabled"
            v-gl-tooltip="$options.i18n.statusEnabled"
            :aria-label="$options.i18n.statusEnabled"
            name="check-circle-filled"
            class="gl-text-green-700"
          />
          <span v-else class="gl-sr-only">{{ $options.i18n.statusDisabled }}</span>

          <breaking-changes-icon
            v-if="showBreakingChangesIcon(deprecatedProperties)"
            :id="name"
            :deprecated-properties="deprecatedProperties"
          />
        </div>
      </template>

      <template #cell(source)="{ value: source }">
        <span
          v-if="isPolicyInherited(source) && policyHasNamespace(source)"
          class="gl-whitespace-nowrap"
        >
          <gl-sprintf :message="$options.i18n.inheritedLabel">
            <template #namespace>
              <gl-link :href="getSecurityPolicyListUrl(policyListUrlArgs(source))" target="_blank">
                {{ getPolicyText(source) }}
              </gl-link>
            </template>
          </gl-sprintf>
        </span>
        <span v-else-if="isPolicyInherited(source) && !policyHasNamespace(source)">{{
          $options.i18n.inheritedShortLabel
        }}</span>
        <span v-else class="gl-whitespace-nowrap">{{ typeLabel }}</span>
      </template>

      <template #cell(scope)="{ item: { policyScope } }">
        <list-component-scope
          :policy-scope="policyScope"
          :linked-spp-items="linkedSppItems"
          :loading="showLoader"
        />
      </template>

      <template #cell(updatedAt)="{ value: updatedAt }">
        <time-ago-tooltip
          v-if="updatedAt"
          :time="updatedAt"
          :date-time-format="$options.dateTimeFormat"
        />
      </template>

      <template #table-busy>
        <gl-loading-icon size="lg" />
      </template>

      <template #empty>
        <empty-state
          :has-existing-policies="hasExistingPolicies"
          :has-policy-project="hasPolicyProject"
        />
      </template>
    </gl-table>

    <drawer-wrapper
      :open="hasSelectedPolicy"
      :policy="selectedPolicy"
      :policy-type="policyType"
      :disable-scan-policy-update="disableScanPolicyUpdate"
      data-testid="policyDrawer"
      @close="deselectPolicy"
    />
  </div>
</template>
