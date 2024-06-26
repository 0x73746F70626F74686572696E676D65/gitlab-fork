<script>
import {
  GlBadge,
  GlButton,
  GlFormCheckbox,
  GlLoadingIcon,
  GlTable,
  GlTooltipDirective,
} from '@gitlab/ui';

import { sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import DrawerWrapper from 'ee/security_orchestration/components/policy_drawer/drawer_wrapper.vue';
import { getPolicyType } from 'ee/security_orchestration/utils';
import { i18n } from '../constants';
import complianceFrameworkPoliciesQuery from '../graphql/compliance_frameworks_policies.query.graphql';

import EditSection from './edit_section.vue';

function extractPolicies(policies) {
  return {
    policies: policies.nodes,
    hasNextPage: policies.pageInfo.hasNextPage,
    endCursor: policies.pageInfo.endCursor,
  };
}

export default {
  components: {
    DrawerWrapper,
    EditSection,

    GlBadge,
    GlButton,
    GlLoadingIcon,
    GlFormCheckbox,
    GlTable,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  provide() {
    return {
      // required for drawer component
      rootNamespacePath: this.fullPath,
    };
  },
  inject: ['disableScanPolicyUpdate'],
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    graphqlId: {
      type: String,
      required: true,
    },
  },

  data() {
    return {
      selectedPolicy: null,
      rawPolicies: {
        globalApprovalPolicies: [],
        globalScanExecutionPolicies: [],
        approvalPolicies: [],
        scanExecutionPolicies: [],
      },
      policiesLoaded: false,
      policiesLoadCursor: {
        approvalPoliciesGlobalAfter: null,
        scanExecutionPoliciesGlobalAfter: null,
        approvalPoliciesAfter: null,
        scanExecutionPoliciesAfter: null,
      },
    };
  },
  apollo: {
    rawGroupPolicies: {
      query: complianceFrameworkPoliciesQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          complianceFramework: this.graphqlId,
          ...this.policiesLoadCursor,
        };
      },
      update(data) {
        const {
          policies: pendingGlobalApprovalPolicies,
          hasNextPage: hasNextGlobalApprovalPolicies,
          endCursor: approvalPoliciesGlobalAfter,
        } = extractPolicies(data.namespace.approvalPolicies);
        const {
          policies: pendingGlobalScanExecutionPolicies,
          hasNextPage: hasNextGlobalScanExecutionPolicies,
          endCursor: scanExecutionPoliciesGlobalAfter,
        } = extractPolicies(data.namespace.scanExecutionPolicies);
        const {
          policies: pendingApprovalPolicies,
          hasNextPage: hasNextApprovalPolicies,
          endCursor: approvalPoliciesAfter,
        } = extractPolicies(data.namespace.complianceFrameworks.nodes[0].scanResultPolicies);
        const {
          policies: pendingScanExecutionPolicies,
          hasNextPage: hasNextScanExecutionPolicies,
          endCursor: scanExecutionPoliciesAfter,
        } = extractPolicies(data.namespace.complianceFrameworks.nodes[0].scanExecutionPolicies);

        this.policiesLoaded =
          !hasNextGlobalApprovalPolicies &&
          !hasNextGlobalScanExecutionPolicies &&
          !hasNextApprovalPolicies &&
          !hasNextScanExecutionPolicies;

        const newCursor = {
          approvalPoliciesGlobalAfter,
          scanExecutionPoliciesGlobalAfter,
          approvalPoliciesAfter,
          scanExecutionPoliciesAfter,
        };

        [
          'approvalPoliciesGlobalAfter',
          'scanExecutionPoliciesGlobalAfter',
          'approvalPoliciesAfter',
          'scanExecutionPoliciesAfter',
        ].forEach((cursorField) => {
          if (newCursor[cursorField]) {
            this.policiesLoadCursor[cursorField] = newCursor[cursorField];
          }
        });

        this.rawPolicies.approvalPolicies.push(...pendingApprovalPolicies);
        this.rawPolicies.scanExecutionPolicies.push(...pendingScanExecutionPolicies);
        this.rawPolicies.globalApprovalPolicies.push(...pendingGlobalApprovalPolicies);
        this.rawPolicies.globalScanExecutionPolicies.push(...pendingGlobalScanExecutionPolicies);
      },
      error(error) {
        this.errorMessage = this.$options.i18n.fetchError;
        Sentry.captureException(error);
      },
      skip() {
        return this.policiesLoaded;
      },
    },
  },

  computed: {
    policies() {
      const approvalPoliciesSet = new Set(this.rawPolicies.approvalPolicies.map((p) => p.name));
      const scanExecutionPoliciesSet = new Set(
        this.rawPolicies.scanExecutionPolicies.map((p) => p.name),
      );

      return [
        ...this.rawPolicies.globalApprovalPolicies.map((p) => ({
          ...p,
          isLinked: approvalPoliciesSet.has(p.name),
        })),
        ...this.rawPolicies.globalScanExecutionPolicies.map((p) => ({
          ...p,
          isLinked: scanExecutionPoliciesSet.has(p.name),
        })),
      ].sort((a, b) => (a.name > b.name ? 1 : -1));
    },

    description() {
      if (!this.policiesLoaded) {
        // zero-width-space to avoid jump
        return '\u200b';
      }

      const { length: count } = this.policies;
      const { length: linkedCount } = this.policies.filter((p) => p.isLinked);

      return [
        sprintf(i18n.policiesLinkedCount(linkedCount), { count: linkedCount }),
        sprintf(i18n.policiesTotalCount(count), { count }),
      ].join(' ');
    },

    policyType() {
      // eslint-disable-next-line no-underscore-dangle
      return this.selectedPolicy ? getPolicyType(this.selectedPolicy.__typename) : '';
    },
  },

  methods: {
    getTooltip(policy) {
      return policy.isLinked ? i18n.policiesLinkedTooltip : i18n.policiesUnlinkedTooltip;
    },

    presentPolicyDrawer(rows) {
      if (rows.length === 0) return;

      const [selectedPolicy] = rows;

      this.selectedPolicy = null;
      this.$nextTick(() => {
        this.selectedPolicy = selectedPolicy;
      });
    },

    deselectPolicy() {
      this.selectedPolicy = null;

      const bTable = this.$refs.policiesTable.$children[0];
      bTable.clearSelected();
    },
  },

  tableFields: [
    {
      key: 'linked',
      label: i18n.policiesTableFields.linked,
      thClass: 'gl-whitespace-nowrap gl-w-1/20',
      tdClass: 'gl-text-center',
    },
    {
      key: 'name',
      label: i18n.policiesTableFields.name,
    },
    {
      key: 'description',
      label: i18n.policiesTableFields.desc,
    },
    {
      key: 'edit',
      label: '',
      thClass: 'gl-w-1',
      tdClass: 'gl-text-right',
    },
  ],
  i18n,
};
</script>
<template>
  <edit-section :title="$options.i18n.policies" :description="description" expandable>
    <gl-table
      ref="policiesTable"
      :items="policies"
      :fields="$options.tableFields"
      :busy="$apollo.queries.rawGroupPolicies.loading"
      responsive
      stacked="md"
      hover
      selectable
      select-mode="single"
      selected-variant="primary"
      @row-selected="presentPolicyDrawer"
    >
      <template #cell(linked)="{ item }">
        <div v-gl-tooltip="getTooltip(item)" class="gl-w-5 gl-display-inline-block">
          <gl-form-checkbox :checked="item.isLinked" disabled />
        </div>
      </template>
      <template #cell(name)="{ item }">
        {{ item.name }}
        <div v-if="!item.enabled">
          <gl-badge variant="muted">
            {{ __('Disabled') }}
          </gl-badge>
        </div>
      </template>
      <template #cell(edit)="{ item }">
        <gl-button variant="link" size="small" icon="pencil" :href="item.editPath">
          {{ __('Edit') }}
        </gl-button>
      </template>

      <template #table-busy>
        <gl-loading-icon size="lg" />
      </template>
    </gl-table>
    <drawer-wrapper
      container-class=".content-wrapper"
      :open="Boolean(selectedPolicy)"
      :policy="selectedPolicy"
      :policy-type="policyType"
      :disable-scan-policy-update="disableScanPolicyUpdate"
      @close="deselectPolicy"
    />
  </edit-section>
</template>
