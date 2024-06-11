<script>
import { s__ } from '~/locale';
import getSppLinkedProjectsNamespaces from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_namespaces.graphql';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { createAlert } from '~/alert';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { getParameterByName } from '~/lib/utils/url_utility';
import { extractSourceParameter } from 'ee/security_orchestration/components/policies/utils';
import { isGroup } from '../utils';
import projectScanExecutionPoliciesQuery from '../../graphql/queries/project_scan_execution_policies.query.graphql';
import groupScanExecutionPoliciesQuery from '../../graphql/queries/group_scan_execution_policies.query.graphql';
import projectScanResultPoliciesQuery from '../../graphql/queries/project_scan_result_policies.query.graphql';
import groupScanResultPoliciesQuery from '../../graphql/queries/group_scan_result_policies.query.graphql';
import projectPipelineExecutionPoliciesQuery from '../../graphql/queries/project_pipeline_execution_policies.query.graphql';
import groupPipelineExecutionPoliciesQuery from '../../graphql/queries/group_pipeline_execution_policies.query.graphql';
import ListHeader from './list_header.vue';
import ListComponent from './list_component.vue';

const NAMESPACE_QUERY_DICT = {
  scanExecution: {
    [NAMESPACE_TYPES.PROJECT]: projectScanExecutionPoliciesQuery,
    [NAMESPACE_TYPES.GROUP]: groupScanExecutionPoliciesQuery,
  },
  scanResult: {
    [NAMESPACE_TYPES.PROJECT]: projectScanResultPoliciesQuery,
    [NAMESPACE_TYPES.GROUP]: groupScanResultPoliciesQuery,
  },
  pipelineExecution: {
    [NAMESPACE_TYPES.PROJECT]: projectPipelineExecutionPoliciesQuery,
    [NAMESPACE_TYPES.GROUP]: groupPipelineExecutionPoliciesQuery,
  },
};

const createPolicyFetchError = ({ gqlError, networkError }) => {
  const error =
    gqlError?.message ||
    networkError?.message ||
    s__('SecurityOrchestration|Something went wrong, unable to fetch policies');
  createAlert({
    message: error,
  });
};

export default {
  components: {
    ListHeader,
    ListComponent,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['assignedPolicyProject', 'namespacePath', 'namespaceType'],
  apollo: {
    linkedSppItems: {
      query: getSppLinkedProjectsNamespaces,
      variables() {
        return {
          fullPath: this.namespacePath,
        };
      },
      update(data) {
        const {
          securityPolicyProjectLinkedProjects: { nodes: linkedProjects = [] } = {},
          securityPolicyProjectLinkedNamespaces: { nodes: linkedNamespaces = [] } = {},
        } = data?.project || {};

        return [...linkedProjects, ...linkedNamespaces];
      },
      skip() {
        return isGroup(this.namespaceType);
      },
    },
    scanExecutionPolicies: {
      query() {
        return NAMESPACE_QUERY_DICT.scanExecution[this.namespaceType];
      },
      variables() {
        return {
          fullPath: this.namespacePath,
          relationship: this.selectedPolicySource,
        };
      },
      update(data) {
        return data?.namespace?.scanExecutionPolicies?.nodes ?? [];
      },
      error: createPolicyFetchError,
    },
    scanResultPolicies: {
      query() {
        return NAMESPACE_QUERY_DICT.scanResult[this.namespaceType];
      },
      variables() {
        return {
          fullPath: this.namespacePath,
          relationship: this.selectedPolicySource,
        };
      },
      update(data) {
        return data?.namespace?.scanResultPolicies?.nodes ?? [];
      },
      result({ data }) {
        const policies = data?.namespace?.scanResultPolicies?.nodes ?? [];
        this.hasInvalidPolicies = policies.some((policy) =>
          policy.deprecatedProperties.some((prop) => prop !== 'scan_result_policy'),
        );
      },
      error: createPolicyFetchError,
    },
    pipelineExecutionPolicies: {
      query() {
        return NAMESPACE_QUERY_DICT.pipelineExecution[this.namespaceType];
      },
      variables() {
        return {
          fullPath: this.namespacePath,
          relationship: this.selectedPolicySource,
        };
      },
      update(data) {
        return data?.namespace?.pipelineExecutionPolicies?.nodes ?? [];
      },
      error: createPolicyFetchError,
      skip() {
        return !this.pipelineExecutionPolicyEnabled;
      },
    },
  },
  data() {
    const selectedPolicySource = extractSourceParameter(getParameterByName('source'));

    return {
      hasInvalidPolicies: false,
      hasPolicyProject: Boolean(this.assignedPolicyProject?.id),
      selectedPolicySource,
      shouldUpdatePolicyList: false,
      linkedSppItems: [],
      pipelineExecutionPolicies: [],
      scanExecutionPolicies: [],
      scanResultPolicies: [],
    };
  },
  computed: {
    isLoadingLinkedSpps() {
      return this.$apollo.queries.linkedSppItems?.loading;
    },
    isLoadingPolicies() {
      return (
        this.$apollo.queries.scanExecutionPolicies.loading ||
        this.$apollo.queries.scanResultPolicies.loading
      );
    },
    pipelineExecutionPolicyEnabled() {
      return this.glFeatures.pipelineExecutionPolicyType;
    },
  },
  methods: {
    handleClearedSelected() {
      this.shouldUpdatePolicyList = false;
    },
    handleUpdatePolicyList({ hasPolicyProject, shouldUpdatePolicyList = false }) {
      if (hasPolicyProject !== undefined) {
        this.hasPolicyProject = hasPolicyProject;
      }

      this.shouldUpdatePolicyList = shouldUpdatePolicyList;

      this.$apollo.queries.scanExecutionPolicies.refetch();
      this.$apollo.queries.scanResultPolicies.refetch();
    },
    handleUpdatePolicySource(selectedPolicySource) {
      this.selectedPolicySource = selectedPolicySource;
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
      :is-loading-linked-spps="isLoadingLinkedSpps"
      :is-loading-policies="isLoadingPolicies"
      :selected-policy-source="selectedPolicySource"
      :linked-spp-items="linkedSppItems"
      :scan-execution-policies="scanExecutionPolicies"
      :scan-result-policies="scanResultPolicies"
      :pipeline-execution-policies="pipelineExecutionPolicies"
      @cleared-selected="handleClearedSelected"
      @update-policy-source="handleUpdatePolicySource"
    />
  </div>
</template>
