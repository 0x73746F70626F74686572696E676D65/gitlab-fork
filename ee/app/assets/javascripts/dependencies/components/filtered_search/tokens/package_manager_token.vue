<script>
import {
  GlIcon,
  GlFilteredSearchToken,
  GlFilteredSearchSuggestion,
  GlLoadingIcon,
  GlIntersperse,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';

export default {
  components: {
    GlIcon,
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
    GlLoadingIcon,
    GlIntersperse,
  },
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      searchTerm: '',
      packageManagers: [],
      selectedPackageManagers: [],
      isLoading: true,
    };
  },
  computed: {
    filteredPackageManagers() {
      if (!this.searchTerm) {
        return this.packageManagers;
      }

      const nameIncludesSearchTerm = (packageManager) =>
        packageManager.name.toLowerCase().includes(this.searchTerm);
      const isSelected = (packageManager) =>
        this.selectedPackageManagerNames.includes(packageManager.name);

      return this.packageManagers.filter(
        (packageManager) => nameIncludesSearchTerm(packageManager) || isSelected(packageManager),
      );
    },
    selectedPackageManagerNames() {
      return this.selectedPackageManagers.map(({ name }) => name);
    },
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-ui/-/issues/2381
        data: this.active ? null : this.selectedPackageManagerNames,
      };
    },
  },
  created() {
    this.fetchPackageMangers();
  },
  methods: {
    async fetchPackageMangers() {
      try {
        this.isLoading = true;
        // Note: This is just a placeholder. Adding the actual fetch logic will be addressed in a separate issue:
        // https://gitlab.com/gitlab-org/gitlab/-/issues/442556
        // There is also a BE dependency that needs to be resolved, before we can fetch the actual data:
        // https://gitlab.com/gitlab-org/gitlab/-/issues/454302
        this.packageManagers = await new Promise((resolve) => {
          resolve([
            { id: 'gid://gitlab/Packager/1', name: 'bundler' },
            { id: 'gid://gitlab/Packager/2', name: 'npm' },
            { id: 'gid://gitlab/Packager/3', name: 'crate' },
          ]);
        });
      } catch {
        createAlert({
          message: this.$options.i18n.fetchErrorMessage,
        });
      } finally {
        this.isLoading = false;
      }
    },
    isPackageManagerSelected(packageManager) {
      return this.selectedPackageManagers.some((c) => c.id === packageManager.id);
    },
    toggleSelectedPackageManager(packageManager) {
      if (this.isPackageManagerSelected(packageManager)) {
        this.selectedPackageManagers = this.selectedPackageManagers.filter(
          (c) => c.id !== packageManager.id,
        );
      } else {
        this.selectedPackageManagers.push(packageManager);
      }
    },
    handleInput(token) {
      this.$emit('input', { ...token, data: this.selectedPackageManagerNames });
    },
    setSearchTerm(token) {
      // the data can be either a string or an array, in which case we don't want to perform the search
      if (typeof token.data === 'string') {
        this.searchTerm = token.data.toLowerCase();
      }
    },
  },
  i18n: {
    fetchErrorMessage: s__(
      'Dependencies|There was an error fetching the package managers for this group. Please try again later.',
    ),
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :multi-select-values="selectedPackageManagerNames"
    :value="tokenValue"
    v-on="{ ...$listeners, input: handleInput }"
    @select="toggleSelectedPackageManager"
    @input="setSearchTerm"
  >
    <template #view>
      <gl-intersperse data-testid="selected-package-managers">
        <span
          v-for="selectedPackageManagerName in selectedPackageManagerNames"
          :key="selectedPackageManagerName"
          >{{ selectedPackageManagerName }}</span
        >
      </gl-intersperse>
    </template>
    <template #suggestions>
      <gl-loading-icon v-if="isLoading" size="sm" />
      <template v-else>
        <gl-filtered-search-suggestion
          v-for="packageManager in filteredPackageManagers"
          :key="packageManager.name"
          :value="packageManager"
        >
          <div class="flex items-center">
            <gl-icon
              v-if="config.multiSelect"
              name="check"
              class="gl-mr-3 gl-flex-shrink-0 gl-text-gray-700"
              :class="{
                'gl-invisible': !selectedPackageManagerNames.includes(packageManager.name),
              }"
            />
            {{ packageManager.name }}
          </div>
        </gl-filtered-search-suggestion>
      </template>
    </template>
  </gl-filtered-search-token>
</template>
