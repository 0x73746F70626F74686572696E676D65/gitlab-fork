<script>
import { GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import { getSecurityPolicyListUrl } from '~/editor/extensions/source_editor_security_policy_schema_ext';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { isPolicyInherited, policyHasNamespace, isGroup } from '../utils';
import {
  DEFAULT_DESCRIPTION_LABEL,
  DESCRIPTION_TITLE,
  ENABLED_LABEL,
  GROUP_TYPE_LABEL,
  INHERITED_LABEL,
  INHERITED_SHORT_LABEL,
  NOT_ENABLED_LABEL,
  PROJECT_TYPE_LABEL,
  SOURCE_TITLE,
  STATUS_TITLE,
  TYPE_TITLE,
} from './constants';
import ScopeInfoRow from './scope_info_row.vue';
import InfoRow from './info_row.vue';

export default {
  components: {
    GlIcon,
    GlLink,
    GlSprintf,
    InfoRow,
    ScopeInfoRow,
  },
  i18n: {
    policyTypeTitle: TYPE_TITLE,
    descriptionTitle: DESCRIPTION_TITLE,
    defaultDescription: DEFAULT_DESCRIPTION_LABEL,
    sourceTitle: SOURCE_TITLE,
    statusTitle: STATUS_TITLE,
    inheritedLabel: INHERITED_LABEL,
    inheritedShortLabel: INHERITED_SHORT_LABEL,
    groupTypeLabel: GROUP_TYPE_LABEL,
    projectTypeLabel: PROJECT_TYPE_LABEL,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: { namespaceType: {} },
  props: {
    description: {
      type: String,
      required: false,
      default: '',
    },
    policyScope: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    policy: {
      type: Object,
      required: false,
      default: null,
    },
    type: {
      type: String,
      required: true,
    },
  },
  computed: {
    showScopeInfoBox() {
      return isGroup(this.namespaceType) || this.glFeatures.securityPoliciesPolicyScopeProject;
    },
    isInherited() {
      return isPolicyInherited(this.policy.source);
    },
    policyHasNamespace() {
      return policyHasNamespace(this.policy.source);
    },
    sourcePolicyListUrl() {
      return getSecurityPolicyListUrl({ namespacePath: this.policy.source.namespace.fullPath });
    },
    statusLabel() {
      return this.policy?.enabled ? ENABLED_LABEL : NOT_ENABLED_LABEL;
    },
    typeLabel() {
      if (isGroup(this.namespaceType)) {
        return this.$options.i18n.groupTypeLabel;
      }
      return this.$options.i18n.projectTypeLabel;
    },
  },
};
</script>

<template>
  <div>
    <slot name="summary"></slot>

    <info-row data-testid="policy-type" :label="$options.i18n.policyTypeTitle">
      {{ type }}
    </info-row>

    <info-row :label="$options.i18n.descriptionTitle">
      <div v-if="description" data-testid="custom-description-text">
        {{ description }}
      </div>
      <div v-else class="gl-text-gray-500" data-testid="default-description-text">
        {{ $options.i18n.defaultDescription }}
      </div>
    </info-row>

    <scope-info-row v-if="showScopeInfoBox" :policy-scope="policyScope" />

    <info-row :label="$options.i18n.sourceTitle">
      <div data-testid="policy-source">
        <gl-sprintf
          v-if="isInherited && policyHasNamespace"
          :message="$options.i18n.inheritedLabel"
        >
          <template #namespace>
            <gl-link :href="sourcePolicyListUrl" target="_blank">
              {{ policy.source.namespace.name }}
            </gl-link>
          </template>
        </gl-sprintf>
        <span v-else-if="isInherited && !policyHasNamespace">{{
          $options.i18n.inheritedShortLabel
        }}</span>
        <span v-else>{{ typeLabel }}</span>
      </div>
    </info-row>

    <slot name="additional-details"></slot>

    <info-row :label="$options.i18n.statusTitle">
      <div v-if="policy.enabled" class="gl-text-green-500" data-testid="enabled-status-text">
        <gl-icon name="check-circle-filled" class="gl-mr-3" />{{ statusLabel }}
      </div>
      <div v-else class="gl-text-gray-500" data-testid="not-enabled-status-text">
        {{ statusLabel }}
      </div>
    </info-row>
  </div>
</template>
