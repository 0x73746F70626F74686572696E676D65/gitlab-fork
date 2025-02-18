<script>
// eslint-disable-next-line no-restricted-imports
import { mapState } from 'vuex';
import { GlDrawer, GlButton } from '@gitlab/ui';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { __ } from '~/locale';
import RuleForm from '../rules/rule_form.vue';

const I18N = {
  addApprovalRule: __('Add approval rule'),
  editApprovalRule: __('Edit approval rule'),
  saveChanges: __('Save changes'),
  cancel: __('Cancel'),
};

export default {
  DRAWER_Z_INDEX,
  I18N,
  components: {
    GlDrawer,
    RuleForm,
    GlButton,
  },
  props: {
    isOpen: {
      type: Boolean,
      required: true,
    },
    isMrEdit: {
      type: Boolean,
      default: true,
      required: false,
    },
    isBranchRulesEdit: {
      type: Boolean,
      default: false,
      required: false,
    },
  },
  data() {
    return { isLoading: false };
  },
  computed: {
    ...mapState({
      rule: (state) => state.approvals.editRule,
    }),
    title() {
      return !this.rule || this.defaultRuleName ? I18N.addApprovalRule : I18N.editApprovalRule;
    },
    defaultRuleName() {
      return this.rule?.defaultRuleName;
    },
    getDrawerHeaderHeight() {
      return getContentWrapperHeight();
    },
  },
  methods: {
    async submit() {
      this.isLoading = true;
      await this.$refs.form.submit();
      this.isLoading = false;
    },
  },
};
</script>

<template>
  <gl-drawer
    :header-height="getDrawerHeaderHeight"
    :z-index="$options.DRAWER_Z_INDEX"
    :open="isOpen"
    @ok.prevent="submit"
    v-on="$listeners"
  >
    <template #title>
      <h2 class="gl-font-size-h2 gl-mt-0">{{ title }}</h2>
    </template>

    <template #header>
      <gl-button
        variant="confirm"
        data-testid="save-approval-rule-button"
        :loading="isLoading"
        @click="submit"
      >
        {{ $options.I18N.saveChanges }}
      </gl-button>
      <gl-button variant="confirm" category="secondary" @click="$emit('close')">
        {{ $options.I18N.cancel }}
      </gl-button>
    </template>
    <template #default>
      <rule-form
        ref="form"
        :init-rule="rule"
        :is-mr-edit="isMrEdit"
        :is-branch-rules-edit="isBranchRulesEdit"
        :default-rule-name="defaultRuleName"
        v-on="$listeners"
      />
    </template>
  </gl-drawer>
</template>
