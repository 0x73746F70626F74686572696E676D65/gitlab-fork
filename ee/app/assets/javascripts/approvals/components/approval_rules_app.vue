<script>
import { GlButton, GlCard, GlIcon, GlLoadingIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { __ } from '~/locale';
import showToast from '~/vue_shared/plugins/global_toast';
import DrawerRuleCreate from './rule_drawer/create_rule.vue';
import ModalRuleRemove from './rule_modal/remove_rule.vue';

export default {
  name: 'ApprovalRulesApp',
  components: {
    DrawerRuleCreate,
    ModalRuleRemove,
    GlButton,
    GlCard,
    GlIcon,
    GlLoadingIcon,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
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
  computed: {
    ...mapState({
      settings: 'settings',
      rules: (state) => state.approvals.rules,
      pagination: (state) => state.approvals.rulesPagination,
      isLoading: (state) => state.approvals.isLoading,
      drawerOpen: (state) => state.approvals.drawerOpen,
      hasLoaded: (state) => state.approvals.hasLoaded,
      targetBranch: (state) => state.approvals.targetBranch,
    }),
    removeModalId() {
      return `${this.settings.prefix}-approvals-remove-modal`;
    },
    checkShowResetButton() {
      return this.targetBranch && this.settings.canEdit && this.settings.allowMultiRule;
    },
    rulesLength() {
      return this.isMrEdit || this.isBranchRulesEdit ? this.rules.length : this.pagination.total;
    },
    canAddApprovalRule() {
      if (this.isBranchRulesEdit) {
        return this.glFeatures.editBranchRules;
      }

      return this.settings.canEdit && this.settings.allowMultiRule;
    },
  },
  mounted() {
    if (!this.isBranchRulesEdit) {
      this.fetchRules({ targetBranch: this.targetBranch });
    }
  },
  methods: {
    ...mapActions(['fetchRules', 'undoRulesChange']),
    ...mapActions({ openCreateDrawer: 'openCreateDrawer' }),
    ...mapActions({ closeCreateDrawer: 'closeCreateDrawer' }),
    resetToProjectDefaults() {
      const { targetBranch } = this;

      return this.fetchRules({ targetBranch, resetToDefault: true }).then(() => {
        showToast(__('Approval rules reset to project defaults'), {
          action: {
            text: __('Undo'),
            onClick: (_, toast) => {
              this.undoRulesChange();
              toast.hide();
            },
          },
        });
      });
    },
    handleAddRule() {
      this.openCreateDrawer();
    },
  },
};
</script>

<template>
  <gl-card
    class="gl-new-card"
    header-class="gl-new-card-header"
    body-class="gl-new-card-body gl-px-0"
    footer-class="gl-new-card-footer"
    data-testid="mr-approval-rules"
  >
    <template #header>
      <div class="gl-new-card-title-wrapper">
        <h5 class="gl-new-card-title">
          {{ __('Approval rules') }}
          <span class="gl-new-card-count">
            <gl-icon name="approval" class="gl-mr-2" />
            <span data-testid="rules-count">{{ rulesLength }}</span>
          </span>
        </h5>
      </div>
      <div v-if="canAddApprovalRule" class="gl-new-card-actions">
        <gl-button
          :class="{ 'gl-mr-3': targetBranch, 'gl-mr-0': !targetBranch }"
          :disabled="isLoading"
          category="secondary"
          size="small"
          data-testid="add-approval-rule"
          @click="handleAddRule()"
        >
          {{ __('Add approval rule') }}
        </gl-button>
      </div>
    </template>

    <gl-loading-icon v-if="!hasLoaded" size="sm" class="gl-m-5" />
    <template v-else>
      <slot name="rules"></slot>
      <div v-if="checkShowResetButton" class="border-bottom py-3 px-3">
        <div class="gl-display-flex">
          <gl-button
            v-if="targetBranch"
            :disabled="isLoading"
            size="small"
            data-testid="reset-to-defaults"
            @click="resetToProjectDefaults"
          >
            {{ __('Reset to project defaults') }}
          </gl-button>
        </div>
      </div>
    </template>
    <template v-if="$scopedSlots.footer" #footer>
      <slot name="footer"></slot>
    </template>
    <drawer-rule-create
      :is-mr-edit="isMrEdit"
      :is-branch-rules-edit="isBranchRulesEdit"
      :is-open="drawerOpen"
      v-on="$listeners"
      @close="closeCreateDrawer"
    />
    <modal-rule-remove :modal-id="removeModalId" />
  </gl-card>
</template>
