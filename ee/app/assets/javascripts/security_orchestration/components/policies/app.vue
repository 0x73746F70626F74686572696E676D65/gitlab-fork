<script>
import ListHeader from './list_header.vue';
import ListComponent from './list_component.vue';

export default {
  components: {
    ListHeader,
    ListComponent,
  },
  inject: ['assignedPolicyProject'],
  data() {
    return {
      hasInvalidPolicies: false,
      hasPolicyProject: Boolean(this.assignedPolicyProject?.id),
      shouldUpdatePolicyList: false,
    };
  },
  methods: {
    handleHasInvalidPolicies(hasInvalidPolicies) {
      this.hasInvalidPolicies = hasInvalidPolicies;
    },
    handleUpdatePolicyList({ hasPolicyProject, shouldUpdatePolicyList = false }) {
      if (hasPolicyProject !== undefined) {
        this.hasPolicyProject = hasPolicyProject;
      }

      this.shouldUpdatePolicyList = shouldUpdatePolicyList;
    },
  },
};
</script>
<template>
  <div>
    <list-header
      :has-invalid-policies="hasInvalidPolicies"
      @update-policy-list="handleUpdatePolicyList"
    />
    <list-component
      :has-policy-project="hasPolicyProject"
      :should-update-policy-list="shouldUpdatePolicyList"
      @has-invalid-policies="handleHasInvalidPolicies"
      @update-policy-list="handleUpdatePolicyList"
    />
  </div>
</template>
