<script>
import { isEmpty } from 'lodash';
import {
  GlAlert,
  GlCollapsibleListbox,
  GlFormCheckbox,
  GlIcon,
  GlLink,
  GlSprintf,
  GlTooltipDirective,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { isProject, isGroup } from 'ee/security_orchestration/components/utils';
import PolicyPopover from 'ee/security_orchestration/components/policy_popover.vue';
import getSppLinkedProjectsNamespaces from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_namespaces.graphql';
import LoaderWithMessage from '../../loader_with_message.vue';
import GroupProjectsDropdown from '../../group_projects_dropdown.vue';
import ComplianceFrameworkDropdown from './compliance_framework_dropdown.vue';
import ScopeSectionAlert from './scope_section_alert.vue';
import {
  PROJECTS_WITH_FRAMEWORK,
  PROJECT_SCOPE_TYPE_LISTBOX_ITEMS,
  PROJECT_SCOPE_TYPE_TEXTS,
  EXCEPTION_TYPE_LISTBOX_ITEMS,
  EXCEPTION_TYPE_TEXTS,
  WITHOUT_EXCEPTIONS,
  SPECIFIC_PROJECTS,
  EXCEPT_PROJECTS,
  ALL_PROJECTS_IN_GROUP,
  INCLUDING,
  EXCLUDING,
  COMPLIANCE_FRAMEWORKS_KEY,
  PROJECTS_KEY,
} from './constants';

export default {
  COMPLIANCE_FRAMEWORK_PATH: helpPagePath('user/group/compliance_frameworks.md'),
  SCOPE_HELP_PATH: helpPagePath('user/application_security/policies/index.md'),
  PROJECT_SCOPE_TYPE_LISTBOX_ITEMS,
  EXCEPTION_TYPE_LISTBOX_ITEMS,
  i18n: {
    policyScopeLoadingText: s__('SecurityOrchestration|Fetching the scope information.'),
    policyScopeErrorText: s__(
      'SecurityOrchestration|Failed to fetch the scope information. Please refresh the page to try again.',
    ),
    policyScopeFrameworkCopyProject: s__(
      'SecurityOrchestration|Apply this policy to current project.',
    ),
    defaultModeTitle: s__('SecurityOrchestration|Use default mode for scoping'),
    defaultModeDescription: s__(
      'SecurityOrchestration|Enforce policy on all groups, subgroups, and projects linked to the security policy project. %{linkStart}How does scoping work?%{linkEnd}',
    ),
    defaultModePopover: s__('SecurityOrchestration|Turn off default mode to edit scope.'),
    policyScopeFrameworkCopy: s__(
      `SecurityOrchestration|Apply this policy to %{projectScopeType}named %{frameworkSelector}`,
    ),
    policyScopeProjectCopy: s__(
      `SecurityOrchestration|Apply this policy to %{projectScopeType} %{exceptionType} %{projectSelector}`,
    ),
    groupProjectErrorDescription: s__('SecurityOrchestration|Failed to load group projects'),
    complianceFrameworkErrorDescription: s__(
      'SecurityOrchestration|Failed to load compliance frameworks',
    ),
    complianceFrameworkPopoverTitle: __('Information'),
    complianceFrameworkPopoverContent: s__(
      'SecurityOrchestration|A compliance framework is a label to identify that your project has certain compliance requirements. %{linkStart}Learn more%{linkEnd}.',
    ),
  },
  name: 'ScopeSection',
  components: {
    ComplianceFrameworkDropdown,
    GlAlert,
    GlCollapsibleListbox,
    GlFormCheckbox,
    GlIcon,
    GlLink,
    GlSprintf,
    GroupProjectsDropdown,
    LoaderWithMessage,
    PolicyPopover,
    ScopeSectionAlert,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
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
          securityPolicyProjectLinkedProjects: { nodes: linkedProjects = [] },
          securityPolicyProjectLinkedNamespaces: { nodes: linkedNamespaces = [] },
        } = data?.project || {};

        const items = [...linkedProjects, ...linkedNamespaces];

        if (
          isEmpty(this.policyScope) &&
          items.length > 1 &&
          !this.isGroupLevel &&
          !this.hasExistingPolicy
        ) {
          this.setDefaultScope();
        }

        return items;
      },
      error() {
        this.showLinkedSppItemsError = true;
      },
      skip() {
        return this.isGroupLevel;
      },
    },
  },
  inject: ['existingPolicy', 'namespacePath', 'rootNamespacePath', 'namespaceType'],
  props: {
    policyScope: {
      type: Object,
      required: true,
      default: () => ({}),
    },
  },
  data() {
    let selectedProjectScopeType = ALL_PROJECTS_IN_GROUP;
    let selectedExceptionType = WITHOUT_EXCEPTIONS;
    let projectsPayloadKey = EXCLUDING;

    const { projects = [] } = this.policyScope || {};

    if (projects?.excluding && projects.excluding.length > 0) {
      selectedExceptionType = EXCEPT_PROJECTS;
    }

    if (this.policyScope?.compliance_frameworks) {
      selectedProjectScopeType = PROJECTS_WITH_FRAMEWORK;
    }

    if (projects?.including) {
      selectedProjectScopeType = SPECIFIC_PROJECTS;
      projectsPayloadKey = INCLUDING;
    }

    return {
      useDefaultScope: isEmpty(this.policyScope),
      selectedProjectScopeType,
      selectedExceptionType,
      projectsPayloadKey,
      showAlert: false,
      errorDescription: '',
      linkedSppItems: [],
      showLinkedSppItemsError: false,
      isFormDirty: false,
    };
  },
  computed: {
    hasExistingPolicy() {
      return Boolean(this.existingPolicy);
    },
    isGroupLevel() {
      return isGroup(this.namespaceType);
    },
    isProjectLevel() {
      return isProject(this.namespaceType);
    },
    groupProjectsFullPath() {
      return this.isGroupLevel ? this.namespacePath : this.rootNamespacePath;
    },
    hasMultipleProjectsLinked() {
      return this.linkedSppItems.length > 1;
    },
    disableScopeSelector() {
      return (
        this.isProjectLevel &&
        this.hasMultipleProjectsLinked &&
        this.hasExistingPolicy &&
        this.useDefaultScope
      );
    },
    showDefaultScopeSelector() {
      return this.isProjectLevel && this.hasExistingPolicy;
    },
    projectIds() {
      /**
       * Protection from manual yam input as objects
       * @type {*|*[]}
       */
      const projects = Array.isArray(this.policyScope?.projects?.[this.projectsPayloadKey])
        ? this.policyScope?.projects?.[this.projectsPayloadKey]
        : [];

      return projects?.map(({ id }) => convertToGraphQLId(TYPENAME_PROJECT, id)) || [];
    },
    complianceFrameworksIds() {
      /**
       * Protection from manual yam input as objects
       * @type {*|*[]}
       */
      const frameworks = Array.isArray(this.policyScope?.compliance_frameworks)
        ? this.policyScope?.compliance_frameworks
        : [];
      return frameworks?.map(({ id }) => id) || [];
    },
    selectedProjectScopeText() {
      return PROJECT_SCOPE_TYPE_TEXTS[this.selectedProjectScopeType];
    },
    selectedExceptionTypeText() {
      return EXCEPTION_TYPE_TEXTS[this.selectedExceptionType];
    },
    showScopeSelector() {
      return this.isGroupLevel || this.hasMultipleProjectsLinked;
    },
    showExceptionTypeDropdown() {
      return this.selectedProjectScopeType === ALL_PROJECTS_IN_GROUP;
    },
    showGroupProjectsDropdown() {
      return (
        (this.showExceptionTypeDropdown && this.selectedExceptionType === EXCEPT_PROJECTS) ||
        this.selectedProjectScopeType === SPECIFIC_PROJECTS
      );
    },
    payloadKey() {
      return this.selectedProjectScopeType === PROJECTS_WITH_FRAMEWORK
        ? COMPLIANCE_FRAMEWORKS_KEY
        : PROJECTS_KEY;
    },
    policyScopeCopy() {
      return this.selectedProjectScopeType === PROJECTS_WITH_FRAMEWORK
        ? this.$options.i18n.policyScopeFrameworkCopy
        : this.$options.i18n.policyScopeProjectCopy;
    },
    showLoader() {
      return this.$apollo.queries.linkedSppItems?.loading && !this.isGroupLevel;
    },
    isProjectsWithoutExceptions() {
      return this.selectedExceptionType === WITHOUT_EXCEPTIONS;
    },
    projectsEmpty() {
      return this.projectIds.length === 0;
    },
    complianceFrameworksEmpty() {
      return this.complianceFrameworksIds.length === 0;
    },
    complianceFrameworksValidState() {
      return this.complianceFrameworksEmpty && this.isFormDirty;
    },
  },
  methods: {
    resetPolicyScope() {
      const internalPayload =
        this.payloadKey === COMPLIANCE_FRAMEWORKS_KEY ? [] : { [this.projectsPayloadKey]: [] };
      const payload = {
        [this.payloadKey]: internalPayload,
      };

      this.$emit('changed', payload);
    },
    selectProjectScopeType(scopeType) {
      this.isFormDirty = false;

      this.selectedProjectScopeType = scopeType;
      this.projectsPayloadKey =
        this.selectedProjectScopeType === ALL_PROJECTS_IN_GROUP ? EXCLUDING : INCLUDING;
      this.resetPolicyScope();
    },
    selectExceptionType(type) {
      this.isFormDirty = false;

      this.selectedExceptionType = type;
      this.resetPolicyScope();
    },
    setSelectedProjectIds(projects) {
      this.isFormDirty = true;
      const projectsIds = projects.map(({ id }) => ({ id: getIdFromGraphQLId(id) }));
      const payload = { projects: { [this.projectsPayloadKey]: projectsIds } };

      this.triggerChanged(payload);
    },
    setSelectedFrameworkIds(ids) {
      this.isFormDirty = true;

      const payload = ids.map((id) => ({ id }));
      this.triggerChanged({ compliance_frameworks: payload });
    },
    triggerChanged(value) {
      this.$emit('changed', { ...this.policyScope, ...value });
    },
    setShowAlert(errorDescription) {
      this.showAlert = true;
      this.errorDescription = errorDescription;
    },
    setDefaultScope() {
      this.triggerChanged({ projects: { excluding: [] } });
    },
    setDefaultSelectorValues() {
      this.selectedProjectScopeType = ALL_PROJECTS_IN_GROUP;
      this.selectedExceptionType = WITHOUT_EXCEPTIONS;
      this.projectsPayloadKey = EXCLUDING;
    },
    updateScopeSelection(value) {
      if (value) {
        this.$emit('remove');
        this.setDefaultSelectorValues();
      } else {
        this.setDefaultScope();
      }
    },
  },
};
</script>

<template>
  <div>
    <scope-section-alert
      :compliance-frameworks-empty="complianceFrameworksEmpty"
      :is-dirty="isFormDirty"
      :is-projects-without-exceptions="isProjectsWithoutExceptions"
      :project-scope-type="selectedProjectScopeType"
      :project-empty="projectsEmpty"
    />

    <gl-alert v-if="showAlert" class="gl-mb-5" variant="danger" :dismissible="false">
      {{ errorDescription }}
    </gl-alert>

    <loader-with-message v-if="showLoader" />

    <div v-else class="gl-flex gl-gap-3 gl-items-center gl-flex-wrap gl-mt-2">
      <template v-if="showLinkedSppItemsError">
        <div data-testid="policy-scope-project-error" class="gl-flex gl-items-center gl-gap-3">
          <gl-icon class="gl-text-red-500" name="status_warning" />
          <p data-testid="policy-scope-project-error-text" class="gl-text-red-500 gl-m-0">
            {{ $options.i18n.policyScopeErrorText }}
          </p>
        </div>
      </template>

      <template v-else-if="showScopeSelector">
        <div
          :class="{ 'gl-text-gray-400': disableScopeSelector }"
          class="gl-flex gl-gap-3 gl-items-center gl-flex-wrap"
        >
          <gl-sprintf :message="policyScopeCopy">
            <template #projectScopeType>
              <gl-collapsible-listbox
                id="project-scope-type"
                v-gl-tooltip="{
                  title: $options.i18n.defaultModePopover,
                  disabled: !disableScopeSelector,
                }"
                data-testid="project-scope-type"
                :items="$options.PROJECT_SCOPE_TYPE_LISTBOX_ITEMS"
                :selected="selectedProjectScopeType"
                :toggle-text="selectedProjectScopeText"
                :disabled="disableScopeSelector"
                @select="selectProjectScopeType"
              />
            </template>

            <template #frameworkSelector>
              <div class="gl-inline-flex gl-items-center gl-flex-wrap gl-gap-3">
                <compliance-framework-dropdown
                  :disabled="disableScopeSelector"
                  :selected-framework-ids="complianceFrameworksIds"
                  :full-path="rootNamespacePath"
                  :show-error="complianceFrameworksValidState"
                  @framework-query-error="
                    setShowAlert($options.i18n.complianceFrameworkErrorDescription)
                  "
                  @select="setSelectedFrameworkIds"
                />

                <policy-popover
                  :content="$options.i18n.complianceFrameworkPopoverContent"
                  :href="$options.COMPLIANCE_FRAMEWORK_PATH"
                  :title="$options.i18n.complianceFrameworkPopoverTitle"
                  target="compliance-framework-icon"
                />
              </div>
            </template>

            <template #exceptionType>
              <gl-collapsible-listbox
                v-if="showExceptionTypeDropdown"
                data-testid="exception-type"
                :disabled="disableScopeSelector"
                :items="$options.EXCEPTION_TYPE_LISTBOX_ITEMS"
                :toggle-text="selectedExceptionTypeText"
                :selected="selectedExceptionType"
                @select="selectExceptionType"
              />
            </template>

            <template #projectSelector>
              <group-projects-dropdown
                v-if="showGroupProjectsDropdown"
                :disabled="disableScopeSelector"
                :group-full-path="groupProjectsFullPath"
                :selected="projectIds"
                :state="!projectsEmpty"
                @projects-query-error="setShowAlert($options.i18n.groupProjectErrorDescription)"
                @select="setSelectedProjectIds"
              />
            </template>
          </gl-sprintf>
        </div>
        <template v-if="showDefaultScopeSelector">
          <gl-form-checkbox
            v-model="useDefaultScope"
            class="gl-mt-3"
            data-testid="default-scope-selector"
            @change="updateScopeSelection"
          >
            {{ $options.i18n.defaultModeTitle }}
            <template #help>
              <gl-sprintf :message="$options.i18n.defaultModeDescription">
                <template #link="{ content }">
                  <gl-link :href="$options.SCOPE_HELP_PATH">{{ content }}</gl-link>
                </template>
              </gl-sprintf>
            </template>
          </gl-form-checkbox>
        </template>
      </template>
      <template v-else>
        <p data-testid="policy-scope-project-text" class="gl-mb-0">
          {{ $options.i18n.policyScopeFrameworkCopyProject }}
        </p>
      </template>
    </div>
  </div>
</template>
