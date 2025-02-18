<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { sprintf, __, s__ } from '~/locale';
import { parseBoolean } from '~/lib/utils/common_utils';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { MATCH_ON_INCLUSION_LICENSE } from 'ee/security_orchestration/components/policy_editor/constants';
import { EXCEPT, MATCHING } from '../../lib/rules';
import { UNKNOWN_LICENSE } from './constants';

export default {
  i18n: {
    headerText: __('Choose an option'),
    label: s__('ScanResultPolicy|License is:'),
    licenseType: s__('ScanResultPolicy|Select license types'),
    matchTypeToggleText: s__('ScanResultPolicy|matching type'),
    selectAllLabel: s__('ScanResultPolicy|Select all'),
    clearAllLabel: s__('ScanResultPolicy|Clear all'),
    licenseTypeHeader: s__('ScanResultPolicy|Select licenses'),
  },
  matchTypeOptions: [
    {
      value: 'true',
      text: MATCHING,
    },
    {
      value: 'false',
      text: EXCEPT,
    },
  ],
  components: {
    SectionLayout,
    GlCollapsibleListbox,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['parsedSoftwareLicenses'],
  props: {
    initRule: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      searchTerm: '',
    };
  },
  computed: {
    allLicenses() {
      return [...this.parsedSoftwareLicenses, UNKNOWN_LICENSE];
    },
    filteredLicenses() {
      if (this.searchTerm) {
        return this.allLicenses.filter(({ value }) => {
          return value.toLowerCase().includes(this.searchTerm.toLowerCase());
        });
      }

      return this.allLicenses;
    },
    licenseTypes: {
      get() {
        return this.initRule.license_types;
      },
      set(values) {
        this.triggerChanged({ license_types: values });
      },
    },
    matchType: {
      get() {
        return this.initRule?.[MATCH_ON_INCLUSION_LICENSE]?.toString();
      },
      set(value) {
        this.triggerChanged({ [MATCH_ON_INCLUSION_LICENSE]: parseBoolean(value) });
      },
    },
    matchTypeToggleText() {
      return this.matchType ? '' : this.$options.i18n.matchTypeToggleText;
    },
    toggleText() {
      let toggleText = this.$options.i18n.licenseType;
      const selectedValues = [this.licenseTypes].flat();

      if (selectedValues.length === 1) {
        toggleText = this.allLicenses.find(({ value }) => value === selectedValues[0]).text;
      }

      if (selectedValues.length > 1) {
        toggleText = sprintf(s__('ScanResultPolicy|%{count} licenses'), {
          count: selectedValues.length,
        });
      }

      return toggleText;
    },
  },
  methods: {
    filterList(searchTerm) {
      this.searchTerm = searchTerm;
    },
    triggerChanged(value) {
      this.$emit('changed', value);
    },
    resetLicenseTypes() {
      this.triggerChanged({
        license_types: [],
      });
    },
    selectAllLicenseTypes() {
      const licensesValues = this.filteredLicenses.map(({ value }) => value);
      this.triggerChanged({ license_types: licensesValues });
    },
  },
};
</script>

<template>
  <section-layout class="gl-w-full gl-pt-3" :show-remove-button="false">
    <template #selector>
      <label class="gl-mb-0 gl-mr-4" :title="$options.i18n.label">{{ $options.i18n.label }}</label>
      <slot>
        <gl-collapsible-listbox
          v-model="matchType"
          class="gl-display-inline! gl-w-auto gl-align-middle"
          :items="$options.matchTypeOptions"
          :toggle-text="matchTypeToggleText"
          data-testid="match-type-select"
        />
        <gl-collapsible-listbox
          v-model="licenseTypes"
          class="gl-align-middle gl-display-inline!"
          :items="filteredLicenses"
          :toggle-text="toggleText"
          :header-text="$options.i18n.licenseTypeHeader"
          :show-select-all-button-label="$options.i18n.selectAllLabel"
          :reset-button-label="$options.i18n.clearAllLabel"
          searchable
          multiple
          data-testid="license-type-select"
          @search="filterList"
          @select-all="selectAllLicenseTypes"
          @reset="resetLicenseTypes"
        />
      </slot>
    </template>
  </section-layout>
</template>
