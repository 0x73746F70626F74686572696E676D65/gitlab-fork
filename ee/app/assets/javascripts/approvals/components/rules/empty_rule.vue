<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions } from 'vuex';
import { __ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { TABLE_HEADERS } from '../../constants';
import RuleInput from './rule_input.vue';
import EmptyRuleName from './empty_rule_name.vue';
import RuleBranches from './rule_branches.vue';

export default {
  components: {
    RuleInput,
    EmptyRuleName,
    RuleBranches,
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  i18n: {
    addApprovalRule: __('Add approval rule'),
  },
  TABLE_HEADERS,
  mixins: [glFeatureFlagsMixin()],
  props: {
    rule: {
      type: Object,
      required: true,
    },
    allowMultiRule: {
      type: Boolean,
      required: true,
    },
    eligibleApproversDocsPath: {
      type: String,
      required: false,
      default: '',
    },
    isMrEdit: {
      type: Boolean,
      default: true,
      required: false,
    },
    canEdit: {
      type: Boolean,
      required: true,
    },
    isBranchRulesEdit: {
      type: Boolean,
      default: false,
      required: false,
    },
  },
  computed: {
    showProtectedBranch() {
      return !this.isMrEdit && this.allowMultiRule;
    },
  },
  methods: {
    ...mapActions({ openCreateDrawer: 'openCreateDrawer' }),
    handleAddRule() {
      this.openCreateDrawer();
    },
  },
};
</script>

<template>
  <tr>
    <td colspan="2" :data-label="$options.TABLE_HEADERS.name">
      <empty-rule-name :eligible-approvers-docs-path="eligibleApproversDocsPath" />
    </td>
    <td
      v-if="showProtectedBranch && !isBranchRulesEdit"
      :data-label="$options.TABLE_HEADERS.branches"
    >
      <rule-branches :rule="rule" />
    </td>
    <td class="gl-py-5!" :data-label="$options.TABLE_HEADERS.approvalsRequired">
      <rule-input :rule="rule" :is-mr-edit="isMrEdit" :is-branch-rules-edit="isBranchRulesEdit" />
    </td>
    <td class="gl-md-pl-0! gl-md-pr-0!" :data-label="$options.TABLE_HEADERS.actions">
      <div class="!-gl-my-3 gl-px-5 gl-text-right">
        <gl-button
          v-if="!allowMultiRule && canEdit"
          v-gl-tooltip
          :title="$options.i18n.addApprovalRule"
          :aria-label="$options.i18n.addApprovalRule"
          category="tertiary"
          icon="plus"
          data-testid="add-approval-rule"
          @click="handleAddRule()"
        />
      </div>
    </td>
  </tr>
</template>
