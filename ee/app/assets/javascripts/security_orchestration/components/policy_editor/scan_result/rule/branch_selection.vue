<script>
import { GlCollapsibleListbox, GlFormInput } from '@gitlab/ui';
import { n__, s__ } from '~/locale';
import { isProject } from 'ee/security_orchestration/components/utils';
import { slugifyToArray } from '../../utils';
import {
  ALL_PROTECTED_BRANCHES,
  BRANCHES_KEY,
  BRANCH_TYPE_KEY,
  SCAN_EXECUTION_BRANCH_TYPE_OPTIONS,
  SPECIFIC_BRANCHES,
} from '../../constants';
import ProtectedBranchesDropdown from '../../protected_branches_dropdown.vue';

export default {
  components: {
    GlCollapsibleListbox,
    GlFormInput,
    ProtectedBranchesDropdown,
  },
  inject: ['namespaceId', 'namespaceType'],
  props: {
    initRule: {
      type: Object,
      required: true,
    },
    branchTypes: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  i18n: {
    groupLevelBranchInput: s__('SecurityOrchestration|group level branch input'),
    groupLevelBranchSelector: s__('SecurityOrchestration|group level branch selector'),
  },
  data() {
    let selectedBranchType = ALL_PROTECTED_BRANCHES.value;
    const isEmptyRule = !this.initRule.type || this.initRule.type === '';

    if (this.initRule.branch_type) {
      selectedBranchType = this.initRule.branch_type;
    }

    if (!isEmptyRule && this.initRule.branches) {
      selectedBranchType = SPECIFIC_BRANCHES.value;
    }

    return {
      showProtectedBranchesError: false,
      selected: selectedBranchType,
    };
  },
  computed: {
    branchesText() {
      return n__('branch', 'branches', this.branchesToAdd.length);
    },
    enteredBranches: {
      get() {
        return this.initRule.branches?.join() || '';
      },
      set(value) {
        const branches = slugifyToArray(value).filter((branch) => branch !== '*');
        this.triggerChanged({ branches });
      },
    },
    showBranchesLabel() {
      if (!Array.isArray(this.initRule.branches)) {
        return false;
      }

      return Boolean(this.initRule.branches?.length) || this.showInput;
    },
    branchesToAdd: {
      get() {
        return this.initRule.branches;
      },
      set(values) {
        this.triggerChanged({ branches: values || null });
      },
    },
    displayBranchSelector() {
      return isProject(this.namespaceType);
    },
    showInput() {
      return this.selected === SPECIFIC_BRANCHES.value;
    },
    defaultBranchTypeItems() {
      return this.branchTypes.length > 0
        ? this.branchTypes
        : SCAN_EXECUTION_BRANCH_TYPE_OPTIONS(this.namespaceType);
    },
  },
  methods: {
    handleSelect(value) {
      this.selected = value;
      if (value === ALL_PROTECTED_BRANCHES.value) {
        this.branchesToAdd = [];
      }

      /**
       * Either branch of branch_type property
       * is simultaneously allowed on rule object
       * Based on value we remove one and
       * set another and vice versa
       */
      let addedProperty;
      let removedProperty;
      if (value === SPECIFIC_BRANCHES.value) {
        addedProperty = { [BRANCHES_KEY]: [] };
        removedProperty = BRANCH_TYPE_KEY;
      } else {
        addedProperty = { [BRANCH_TYPE_KEY]: value };
        removedProperty = BRANCHES_KEY;
      }

      const updatedRule = { ...this.initRule, ...addedProperty };
      delete updatedRule[removedProperty];

      this.$emit('set-branch-type', updatedRule);
    },
    triggerChanged(value) {
      this.$emit('changed', { ...this.initRule, ...value });
    },
    handleError({ hasErrored, error }) {
      this.showProtectedBranchesError = hasErrored;
      this.$emit('error', error);
    },
  },
};
</script>

<template>
  <div class="gl-display-flex gl-align-items-center gl-gap-3">
    <label for="group-level-branch-selector" class="gl-sr-only">
      {{ $options.i18n.groupLevelBranchSelector }}
    </label>
    <gl-collapsible-listbox
      id="group-level-branch-selector"
      :items="defaultBranchTypeItems"
      :selected="selected"
      @select="handleSelect"
    />

    <template v-if="displayBranchSelector">
      <protected-branches-dropdown
        v-if="showInput"
        v-model="branchesToAdd"
        class="gl-max-w-26"
        :has-error="showProtectedBranchesError"
        :selected="branchesToAdd"
        :select-all-empty="true"
        :project-id="namespaceId"
        @error="handleError"
      />
    </template>
    <template v-else>
      <span v-if="showInput" class="gl-display-flex">
        <label for="group-level-branch-input" class="gl-sr-only">
          {{ $options.i18n.groupLevelBranchInput }}
        </label>
        <gl-form-input
          id="group-level-branch-input"
          v-model="enteredBranches"
          class="gl-display-inline gl-w-30"
          type="text"
        />
      </span>
    </template>
    <span v-if="showBranchesLabel" data-testid="branches-label">{{ branchesText }}</span>
  </div>
</template>
