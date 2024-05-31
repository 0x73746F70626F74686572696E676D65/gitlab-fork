<script>
import { GlButton, GlSprintf, GlTableLite } from '@gitlab/ui';
import { sprintf, __ } from '~/locale';

export default {
  components: {
    GlButton,
    GlSprintf,
    GlTableLite,
  },
  props: {
    group: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      showingOptional: false,
    };
  },
  computed: {
    filteredRules() {
      return this.group.rules
        .filter(({ approvalsRequired }) => {
          return this.showingOptional ? true : approvalsRequired;
        })
        .sort((a, b) => b.approvalsRequired - a.approvalsRequired);
    },
    optionalRulesLength() {
      return this.group.rules.filter(({ approvalsRequired }) => !approvalsRequired).length;
    },
  },
  methods: {
    toggleOptionalRules() {
      this.showingOptional = !this.showingOptional;
    },
    getApprovalsLeftText(rule) {
      return sprintf(__('%{approvals} of %{approvalRequired}'), {
        approvals: rule.approvedBy.nodes.length,
        approvalRequired: rule.approvalsRequired,
      });
    },
  },
  fields: [
    {
      key: 'rule_name',
      thClass: 'gl-text-secondary! gl-font-sm! !gl-font-semibold gl-border-t-0! w-60p',
      class: 'gl-px-0! gl-py-4!',
    },
    {
      key: 'rule_approvals',
      thClass: 'gl-text-secondary! gl-font-sm! !gl-font-semibold gl-border-t-0! w-30p',
      class: 'gl-px-0! gl-py-4!',
    },
  ],
};
</script>

<template>
  <div class="gl-mb-2">
    <gl-table-lite :items="filteredRules" :fields="$options.fields" class="gl-mb-0!">
      <template #head(rule_name)>{{ group.label }}</template>
      <template #head(rule_approvals)>{{ __('Approvals') }}</template>

      <template #cell(rule_name)="{ item }">{{ item.name }}</template>
      <template #cell(rule_approvals)="{ item }">{{ getApprovalsLeftText(item) }}</template>
    </gl-table-lite>
    <div v-if="optionalRulesLength" class="gl-py-3 gl-border-b">
      <gl-button
        category="tertiary"
        size="small"
        :icon="showingOptional ? 'chevron-up' : 'chevron-right'"
        data-testid="optional-rules-toggle"
        @click="toggleOptionalRules(group)"
      >
        <gl-sprintf :message="__('%{count} optional %{label}.')">
          <template #count>{{ optionalRulesLength }}</template>
          <template #label>{{ group.label.toLowerCase() }}</template>
        </gl-sprintf>
      </gl-button>
    </div>
  </div>
</template>
