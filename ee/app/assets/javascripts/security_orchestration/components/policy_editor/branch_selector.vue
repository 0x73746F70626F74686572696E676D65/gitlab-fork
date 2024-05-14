<script>
import { GlButton, GlDisclosureDropdown, GlListboxItem, GlTruncate, GlSprintf } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { getParameterValues } from '~/lib/utils/url_utility';
import { mapExceptionsListBoxItem } from 'ee/security_orchestration/components/policy_editor/utils';
import { POLICY_TYPE_COMPONENT_OPTIONS } from '../constants';
import BranchSelectorModal from './branch_selector_modal.vue';
import { BRANCH_TYPES_ITEMS } from './constants';

const BRANCH_SELECTOR_UNSELECTED = 'branch-selector-unselected';
const BRANCH_SELECTOR_SELECTED = 'branch-selector-selected';

export default {
  BRANCH_SELECTOR_UNSELECTED,
  BRANCH_SELECTOR_SELECTED,
  BRANCH_TYPES_ITEMS,
  name: 'BranchSelector',
  i18n: {
    buttonAddBranchText: __('Add branches'),
    buttonAddProtectedText: __('Add protected branches'),
    buttonClearAllText: __('Clear all'),
    header: s__('SecurityOrchestration|Exception branches'),
    noBranchesText: s__('SecurityOrchestration|There are no exception branches yet.'),
    noBranchesAddText: s__(
      'SecurityOrchestration|%{boldStart}Add branches%{boldEnd} first before selection.',
    ),
    toggleText: s__('SecurityOrchestration|Choose exception branches'),
  },
  components: {
    BranchSelectorModal,
    GlButton,
    GlDisclosureDropdown,
    GlListboxItem,
    GlTruncate,
    GlSprintf,
  },
  props: {
    isGroup: {
      type: Boolean,
      required: false,
      default: false,
    },
    selectedExceptions: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      branches: this.selectedExceptions.map(mapExceptionsListBoxItem),
    };
  },
  computed: {
    isMergeRequestApprovalPolicy() {
      const [value] = getParameterValues('type');
      return value === POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter;
    },
    addButtonText() {
      return this.isMergeRequestApprovalPolicy
        ? this.$options.i18n.buttonAddProtectedText
        : this.$options.i18n.buttonAddBranchText;
    },
    mappedToYamlFormatBranches() {
      return this.branches.map(({ name, fullPath }) => {
        if (fullPath) {
          return {
            name,
            full_path: fullPath,
          };
        }

        return name;
      });
    },
    hasBranches() {
      return this.branches?.length > 0;
    },
    toggleText() {
      return this.branches.map(({ name }) => name).join(', ') || this.$options.i18n.toggleText;
    },
  },
  methods: {
    finishEditing() {
      this.$emit('select-branches', this.mappedToYamlFormatBranches);
      this.$refs.dropdown.close();
    },
    showModal() {
      this.$refs.modal.showModalWindow();
    },
    selectBranches(branches) {
      this.branches = branches;
      this.$refs.dropdown.open();
    },
    unselectBranch({ name, fullPath }) {
      this.branches = this.branches.filter(
        (branch) => branch.name !== name || branch.fullPath !== fullPath,
      );
    },
    onResetButtonClicked() {
      this.branches = [];
      this.$emit('select-branches', []);
    },
  },
};
</script>

<template>
  <div>
    <gl-disclosure-dropdown
      ref="dropdown"
      toggle-class="gl-max-w-34"
      :toggle-text="toggleText"
      @hidden="finishEditing"
    >
      <template #header>
        <div class="gl-display-flex gl-align-items-center gl-p-4 gl-min-h-8 gl-border-b">
          <div class="gl-flex-grow-1 gl-font-weight-bold gl-font-sm gl-pr-2">
            {{ $options.i18n.header }}
          </div>

          <gl-button
            v-if="hasBranches"
            category="tertiary"
            class="gl-focus-inset-border-2-blue-400! gl-flex-shrink-0 gl-font-sm! gl-px-2! gl-py-0! gl-w-auto! gl-m-0! gl-max-w-1/2 gl-text-overflow-ellipsis"
            data-testid="reset-button"
            @click="onResetButtonClicked"
          >
            {{ $options.i18n.buttonClearAllText }}
          </gl-button>
        </div>
      </template>

      <div class="gl-w-full">
        <template v-if="!hasBranches">
          <div
            class="gl-pl-4 gl-pr-4 gl-pt-2 gl-font-base security-policies-popover-content-height"
            data-testid="empty-state"
          >
            <p class="gl-mb-2">{{ $options.i18n.noBranchesText }}</p>
            <p>
              <gl-sprintf :message="$options.i18n.noBranchesAddText">
                <template #bold="{ content }">
                  <strong>{{ content }}</strong>
                </template>
              </gl-sprintf>
            </p>
          </div>
        </template>
        <template v-else>
          <gl-listbox-item
            v-for="(item, index) in branches"
            :key="`${item.name}_${index}`"
            is-check-centered
            is-selected
            @select="unselectBranch(item)"
          >
            <gl-truncate :text="item.name" />
            <p v-if="item.fullPath" class="gl-text-gray-700 gl-font-sm gl-m-0 gl-mt-1">
              <gl-truncate position="middle" :text="item.fullPath" />
            </p>
          </gl-listbox-item>
        </template>
      </div>

      <template #footer>
        <div class="gl-py-2 gl-px-2 gl-display-flex gl-border-t">
          <gl-button data-testid="add-button" category="tertiary" size="small" @click="showModal">
            {{ addButtonText }}
          </gl-button>
        </div>
      </template>
    </gl-disclosure-dropdown>

    <branch-selector-modal
      ref="modal"
      :branches="branches"
      :has-validation="isGroup"
      :for-protected-branches="isMergeRequestApprovalPolicy"
      @add-branches="selectBranches"
    />
  </div>
</template>
