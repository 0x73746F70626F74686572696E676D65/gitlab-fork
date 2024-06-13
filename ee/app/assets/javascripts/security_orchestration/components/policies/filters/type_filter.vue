<script>
import { GlFormGroup, GlCollapsibleListbox } from '@gitlab/ui';
import { __ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { validateTypeFilter } from 'ee/security_orchestration/components/policies/utils';
import { POLICY_TYPE_FILTER_OPTIONS, PIPELINE_EXECUTION_FILTER_OPTION } from '../constants';

export default {
  name: 'PolicyTypeFilter',
  components: {
    GlFormGroup,
    GlCollapsibleListbox,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    value: {
      type: String,
      required: true,
      validator: (value) => validateTypeFilter(value),
    },
  },
  computed: {
    pipelineExecutionPolicyEnabled() {
      return this.glFeatures.pipelineExecutionPolicyType;
    },
    policyTypeFilterOptions() {
      return this.pipelineExecutionPolicyEnabled
        ? {
            ...POLICY_TYPE_FILTER_OPTIONS,
            ...PIPELINE_EXECUTION_FILTER_OPTION,
          }
        : POLICY_TYPE_FILTER_OPTIONS;
    },
    listboxItems() {
      return Object.values(this.policyTypeFilterOptions).map((option) => ({
        value: option.value,
        text: option.text,
      }));
    },

    selectedValueText() {
      return Object.values(this.policyTypeFilterOptions).find(({ value }) => value === this.value)
        .text;
    },
  },
  methods: {
    setPolicyType(value) {
      this.$emit('input', value);
    },
  },
  policyTypeFilterId: 'policy-type-filter',
  i18n: {
    label: __('Type'),
  },
};
</script>

<template>
  <gl-form-group
    :label="$options.i18n.label"
    label-size="sm"
    :label-for="$options.policyTypeFilterId"
  >
    <gl-collapsible-listbox
      :id="$options.policyTypeFilterId"
      class="gl-display-flex"
      toggle-class="gl-truncate"
      block
      :toggle-text="selectedValueText"
      :items="listboxItems"
      :selected="value"
      @select="setPolicyType"
    />
  </gl-form-group>
</template>
