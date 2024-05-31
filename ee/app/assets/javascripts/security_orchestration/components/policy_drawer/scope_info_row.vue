<script>
import {
  DEFAULT_PROJECT_TEXT,
  SCOPE_TITLE,
} from 'ee/security_orchestration/components/policy_drawer/constants';
import ScopeDefaultLabel from 'ee/security_orchestration/components/scope_default_label.vue';
import {
  policyScopeHasComplianceFrameworks,
  policyScopeHasExcludingProjects,
  policyScopeHasIncludingProjects,
  policyScopeProjects,
  policyScopeComplianceFrameworks,
  isGroup,
  isProject,
} from 'ee/security_orchestration/components/utils';
import getSppLinkedProjectsNamespaces from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_namespaces.graphql';
import LoaderWithMessage from '../loader_with_message.vue';
import ComplianceFrameworksToggleList from './compliance_frameworks_toggle_list.vue';
import ProjectsToggleList from './projects_toggle_list.vue';
import InfoRow from './info_row.vue';

export default {
  name: 'ScopeInfoRow',
  components: {
    ComplianceFrameworksToggleList,
    InfoRow,
    LoaderWithMessage,
    ProjectsToggleList,
    ScopeDefaultLabel,
  },
  i18n: {
    scopeTitle: SCOPE_TITLE,
    defaultProjectText: DEFAULT_PROJECT_TEXT,
  },
  inject: ['namespaceType', 'namespacePath'],
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
        return this.isGroup;
      },
    },
  },
  props: {
    policyScope: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    return {
      linkedSppItems: [],
    };
  },
  computed: {
    isGroup() {
      return isGroup(this.namespaceType);
    },
    isProject() {
      return isProject(this.namespaceType);
    },
    policyScopeHasComplianceFrameworks() {
      return policyScopeHasComplianceFrameworks(this.policyScope);
    },
    policyScopeHasIncludingProjects() {
      return policyScopeHasIncludingProjects(this.policyScope);
    },
    policyScopeHasExcludingProjects() {
      return policyScopeHasExcludingProjects(this.policyScope);
    },
    policyHasProjects() {
      return this.policyScopeHasIncludingProjects || this.policyScopeHasExcludingProjects;
    },
    policyScopeProjects() {
      return policyScopeProjects(this.policyScope);
    },
    policyScopeComplianceFrameworks() {
      return policyScopeComplianceFrameworks(this.policyScope);
    },
    hasMultipleProjectsLinked() {
      return this.linkedSppItems.length > 1;
    },
    showDefaultText() {
      return this.isProject && !this.hasMultipleProjectsLinked;
    },
    showLoader() {
      return this.$apollo.queries.linkedSppItems?.loading && this.isProject;
    },
  },
};
</script>

<template>
  <info-row :label="$options.i18n.scopeTitle" data-testid="policy-scope">
    <loader-with-message v-if="showLoader" />
    <template v-else>
      <p v-if="showDefaultText" class="gl-m-0" data-testid="default-project-text">
        {{ $options.i18n.defaultProjectText }}
      </p>
      <div v-else class="gl-inline-flex gl-gap-3 gl-flex-wrap">
        <template v-if="policyScopeHasComplianceFrameworks">
          <compliance-frameworks-toggle-list
            :compliance-frameworks="policyScopeComplianceFrameworks"
          />
        </template>
        <template v-else-if="policyHasProjects">
          <projects-toggle-list
            :is-group="isGroup"
            :including="policyScopeHasIncludingProjects"
            :projects="policyScopeProjects.projects"
          />
        </template>
        <div v-else data-testid="default-scope-text">
          <scope-default-label
            :is-group="isGroup"
            :policy-scope="policyScope"
            :linked-items="linkedSppItems"
          />
        </div>
      </div>
    </template>
  </info-row>
</template>
