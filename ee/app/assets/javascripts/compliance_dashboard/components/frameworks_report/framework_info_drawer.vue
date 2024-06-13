<script>
import {
  GlDrawer,
  GlBadge,
  GlButton,
  GlLabel,
  GlLink,
  GlSprintf,
  GlTooltip,
  GlTruncate,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { isTopLevelGroup } from '../../utils';

export default {
  name: 'FrameworkInfoDrawer',
  components: {
    GlBadge,
    GlDrawer,
    GlButton,
    GlLabel,
    GlLink,
    GlSprintf,
    GlTooltip,
    GlTruncate,
  },
  inject: ['groupSecurityPoliciesPath'],
  props: {
    groupPath: {
      type: String,
      required: true,
    },
    framework: {
      type: Object,
      required: false,
      default: null,
    },
    rootAncestor: {
      type: Object,
      required: true,
    },
  },
  emits: ['edit', 'close'],
  computed: {
    editDisabled() {
      return !isTopLevelGroup(this.groupPath, this.rootAncestor.path);
    },
    showDrawer() {
      return Boolean(this.framework);
    },
    getContentWrapperHeight() {
      return getContentWrapperHeight();
    },
    frameworkSettingsPath() {
      return this.framework.webUrl;
    },
    defaultFramework() {
      return Boolean(this.framework.default);
    },
    associatedProjectsTitle() {
      return `${this.$options.i18n.associatedProjects} (${this.framework.projects.nodes.length})`;
    },
    policies() {
      return [
        ...this.framework.scanExecutionPolicies.nodes,
        ...this.framework.scanResultPolicies.nodes,
      ];
    },
    policiesTitle() {
      return `${this.$options.i18n.policies} (${this.policies.length})`;
    },
  },
  methods: {
    getPolicyEditUrl(policy) {
      const { urlParameter } = Object.values(POLICY_TYPE_COMPONENT_OPTIONS).find(
        // eslint-disable-next-line no-underscore-dangle
        (o) => o.typeName === policy.__typename,
      );

      return `${this.groupSecurityPoliciesPath}/${policy.name}/edit?type=${urlParameter}`;
    },
  },
  DRAWER_Z_INDEX,
  i18n: {
    defaultFramework: s__('ComplianceFrameworksReport|Default'),
    editFramework: s__('ComplianceFrameworksReport|Edit framework'),
    editFrameworkButtonMessage: s__(
      'ComplianceFrameworks|The compliance framework must be edited in top-level group %{linkStart}namespace%{linkEnd}',
    ),
    frameworkDescription: s__('ComplianceFrameworksReport|Description'),
    associatedProjects: s__('ComplianceFrameworksReport|Associated Projects'),
    policies: s__('ComplianceFrameworksReport|Policies'),
  },
};
</script>

<template>
  <gl-drawer
    :open="showDrawer"
    :header-height="getContentWrapperHeight"
    :z-index="$options.DRAWER_Z_INDEX"
    @close="$emit('close')"
  >
    <template v-if="framework" #title>
      <div style="max-width: 350px">
        <h3 class="gl-mt-0">
          <gl-truncate :text="framework.name" with-tooltip />
          <gl-label
            v-if="defaultFramework"
            class="gl-vertical-align-top gl-mt-2"
            :background-color="framework.color"
            :title="$options.i18n.defaultFramework"
          />
        </h3>
        <gl-tooltip
          v-if="editDisabled"
          :target="() => $refs.editButton"
          placement="left"
          boundary="viewport"
        >
          <gl-sprintf :message="$options.i18n.editFrameworkButtonMessage">
            <template #link>
              <gl-link :href="rootAncestor.complianceCenterPath">
                {{ rootAncestor.name }}
              </gl-link>
            </template>
          </gl-sprintf>
        </gl-tooltip>
        <span ref="editButton" class="gl-inline-block">
          <gl-button
            :disabled="editDisabled"
            category="primary"
            variant="confirm"
            @click="$emit('edit', framework)"
          >
            {{ $options.i18n.editFramework }}
          </gl-button>
        </span>
      </div>
    </template>

    <template v-if="framework" #default>
      <div>
        <div>
          <h5 data-testid="sidebar-description-title" class="gl-mt-0">
            {{ $options.i18n.frameworkDescription }}
          </h5>
          <span data-testid="sidebar-description">
            {{ framework.description }}
          </span>
        </div>
        <div class="gl-my-5" data-testid="sidebar-projects">
          <h5
            v-if="framework.projects.nodes.length"
            data-testid="sidebar-projects-title"
            class="gl-mt-0"
          >
            {{ associatedProjectsTitle }}
          </h5>
          <ul class="gl-pl-6">
            <li
              v-for="associatedProject in framework.projects.nodes"
              :key="associatedProject.id"
              class="gl-mt-1"
            >
              <gl-link :href="associatedProject.webUrl">{{ associatedProject.name }}</gl-link>
            </li>
          </ul>
        </div>
        <div class="gl-my-5" data-testid="sidebar-policies">
          <h5 data-testid="sidebar-policies-title" class="gl-mt-0">
            {{ policiesTitle }}
          </h5>
          <div v-if="policies.length">
            <div
              v-for="(policy, idx) in policies"
              :key="idx"
              class="gl-m-4 gl-display-flex gl-flex-direction-column gl-align-items-flex-start"
            >
              <gl-link :href="getPolicyEditUrl(policy)">{{ policy.name }}</gl-link>
              <gl-badge
                v-if="policy.source.namespace.fullPath !== groupPath"
                variant="muted"
                size="sm"
              >
                {{ policy.source.namespace.name }}
              </gl-badge>
            </div>
          </div>
        </div>
      </div>
    </template>
  </gl-drawer>
</template>
