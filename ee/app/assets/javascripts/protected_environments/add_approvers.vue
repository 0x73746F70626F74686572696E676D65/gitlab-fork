<script>
import {
  GlFormGroup,
  GlCollapse,
  GlAvatar,
  GlButton,
  GlIcon,
  GlLink,
  GlFormInput,
  GlSprintf,
  GlTooltipDirective as GlTooltip,
  GlToggle,
} from '@gitlab/ui';
import { uniqueId } from 'lodash';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import Api from 'ee/api';
import { getUser } from '~/rest_api';
import { s__ } from '~/locale';
import AccessDropdown from '~/projects/settings/components/access_dropdown.vue';
import { ACCESS_LEVELS, INHERITED_GROUPS, NON_INHERITED_GROUPS } from './constants';

const mapUserToApprover = (user) => ({
  name: user.name,
  entityName: user.name,
  webUrl: user.web_url,
  avatarUrl: user.avatar_url,
  id: user.id,
  avatarShape: 'circle',
  approvals: 1,
  inputDisabled: true,
  type: 'user',
});

const mapGroupToApprover = (group) => ({
  name: group.full_name,
  entityName: group.name,
  webUrl: group.web_url,
  avatarUrl: group.avatar_url,
  id: group.id,
  avatarShape: 'rect',
  approvals: 1,
  groupInheritanceType: false,
  type: 'group',
});

const ID_FOR_TYPE = {
  user: 'user_id',
  group: 'group_id',
  access: 'access_level',
};

const MIN_APPROVALS_COUNT = 1;

const MAX_APPROVALS_COUNT = 5;

export default {
  ACCESS_LEVELS,
  components: {
    GlFormGroup,
    GlCollapse,
    GlAvatar,
    GlButton,
    GlIcon,
    GlLink,
    GlFormInput,
    GlSprintf,
    GlToggle,
    AccessDropdown,
  },
  directives: { GlTooltip },
  inject: {
    accessLevelsData: { default: [] },
    apiLink: {},
    docsLink: {},
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    approvalRules: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      approvers: [],
      approverInfo: this.approvalRules,
      uniqueId: uniqueId('deployment-approvers-'),
    };
  },
  computed: {
    hasSelectedApprovers() {
      return Boolean(this.approvers.length);
    },
  },
  watch: {
    async approvers() {
      try {
        this.$emit('error', '');
        this.approverInfo = await Promise.all(
          this.approvers.map((approver) => {
            if (approver.user_id) {
              return getUser(approver.user_id).then(({ data }) => mapUserToApprover(data));
            }

            if (approver.group_id) {
              return Api.group(approver.group_id).then(mapGroupToApprover);
            }

            return Promise.resolve({
              accessLevel: approver.access_level,
              id: approver.access_level,
              name: this.accessLevelsData.find(({ id }) => id === approver.access_level).text,
              approvals: 1,
              type: 'access',
            });
          }),
        );

        this.emitApprovalRules();
      } catch (e) {
        Sentry.captureException(e);
        this.$emit(
          'error',
          s__(
            'ProtectedEnvironments|An error occurred while fetching information on the selected approvers.',
          ),
        );
      }
    },
    approvalRules(rules, oldRules) {
      if (!rules.length && oldRules.length) {
        this.approvers = rules;
      }
    },
  },
  methods: {
    updateApprovers(permissions) {
      this.approvers = permissions;
    },
    updateApproverInfo(approver, approvals) {
      const i = this.approverInfo.indexOf(approver);
      this.approverInfo[i] = { ...approver, approvals };
      this.emitApprovalRules();
    },
    updateApproverInheritance(approver, groupInheritanceType) {
      const i = this.approverInfo.indexOf(approver);
      this.$set(this.approverInfo, i, { ...approver, groupInheritanceType });
      this.emitApprovalRules();
    },
    removeApprover({ type, id }) {
      const key = ID_FOR_TYPE[type];
      this.approvers = this.approvers.filter(({ [key]: i }) => id !== i);
    },
    isApprovalValid(approvals) {
      const count = parseFloat(approvals);
      return count >= MIN_APPROVALS_COUNT && count <= MAX_APPROVALS_COUNT;
    },
    approvalsId(index) {
      return `${this.uniqueId}-${index}`;
    },
    inheritanceId(index) {
      return `${this.uniqueId}-inheritance-${index}`;
    },
    emitApprovalRules() {
      const rules = this.approverInfo.map((info) => {
        switch (info.type) {
          case 'user':
            return { user_id: info.id, required_approvals: info.approvals };
          case 'group':
            return {
              group_id: info.id,
              required_approvals: info.approvals,
              group_inheritance_type: info.groupInheritanceType
                ? INHERITED_GROUPS
                : NON_INHERITED_GROUPS,
            };
          case 'access':
            return {
              access_level: info.accessLevel,
              required_approvals: info.approvals,
            };
          default:
            return {};
        }
      });
      this.$emit('change', rules);
    },
    isGroupRule(rule) {
      return rule.type === 'group';
    },
  },
  i18n: {
    approverLabel: s__('ProtectedEnvironment|Approvers'),
    approverHelp: s__(
      'ProtectedEnvironments|Set which groups, access levels, or users are required to approve. Groups and users must be members of the project.',
    ),
    approvalRulesLabel: s__('ProtectedEnvironments|Approval rules'),
    approvalsInvalid: s__('ProtectedEnvironments|Number of approvals must be between 1 and 5'),
    removeApprover: s__('ProtectedEnvironments|Remove approval rule'),
    unifiedRulesHelpText: s__(
      'ProtectedEnvironments|To configure unified approval rules, use the %{apiLinkStart}API%{apiLinkEnd}. Consider using %{docsLinkStart}multiple approval rules%{docsLinkEnd} instead.',
    ),
    accessDropdownLabel: s__('ProtectedEnvironments|Select users'),
    inheritanceLabel: s__('ProtectedEnvironments|Enable group inheritance'),
    inheritanceTooltip: s__(
      'ProtectedEnvironments|If a group is invited to the current project, its parent and members inherit the permissions of the invited group.',
    ),
  },
};
</script>
<template>
  <div>
    <gl-form-group
      data-testid="create-approver-dropdown"
      label-for="create-approver-dropdown"
      :label="$options.i18n.approverLabel"
    >
      <template #label-description>
        {{ $options.i18n.approverHelp }}
      </template>
      <access-dropdown
        id="create-approver-dropdown"
        :label="$options.i18n.accessDropdownLabel"
        :access-levels-data="accessLevelsData"
        :access-level="$options.ACCESS_LEVELS.DEPLOY"
        :disabled="disabled"
        :items="approvers"
        @select="updateApprovers"
      />
      <template #description>
        <gl-sprintf :message="$options.i18n.unifiedRulesHelpText">
          <template #apiLink="{ content }">
            <gl-link :href="apiLink">{{ content }}</gl-link>
          </template>
          <template #docsLink="{ content }">
            <gl-link :href="docsLink">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
    </gl-form-group>
    <gl-collapse :visible="hasSelectedApprovers">
      <span class="gl-font-bold">{{ $options.i18n.approvalRulesLabel }}</span>
      <div
        data-testid="approval-rules"
        class="protected-environment-approvers gl-display-grid gl-gap-5 gl-align-items-center"
      >
        <span class="protected-environment-approvers-label">{{ __('Approvers') }}</span>
        <span>{{ __('Approvals required') }}</span>
        <div class="gl-flex gl-gap-2">
          <span>{{ $options.i18n.inheritanceLabel }}</span>
          <gl-icon
            v-gl-tooltip
            :title="$options.i18n.inheritanceTooltip"
            :aria-label="$options.i18n.inheritanceTooltip"
            name="question-o"
          />
        </div>
        <span></span>
        <template v-for="(approver, index) in approverInfo">
          <gl-avatar
            v-if="approver.avatarShape"
            :key="`${index}-avatar`"
            :src="approver.avatarUrl"
            :size="24"
            :entity-id="approver.id"
            :entity-name="approver.entityName"
            :shape="approver.avatarShape"
          />
          <span v-else :key="`${index}-avatar`" class="gl-w-6"></span>
          <gl-link v-if="approver.webUrl" :key="`${index}-name`" :href="approver.webUrl">
            {{ approver.name }}
          </gl-link>
          <span v-else :key="`${index}-name`">{{ approver.name }}</span>

          <gl-form-group
            :key="`${index}-approvals`"
            :state="isApprovalValid(approver.approvals)"
            :label="$options.i18n.approverLabel"
            :label-for="approvalsId(index)"
            label-sr-only
            class="gl-mb-0"
          >
            <gl-form-input
              :id="approvalsId(index)"
              :value="approver.approvals"
              :disabled="approver.inputDisabled"
              :state="isApprovalValid(approver.approvals)"
              :name="`approval-count-${approver.name}`"
              type="number"
              @input="updateApproverInfo(approver, $event)"
            />
            <template #invalid-feedback>
              {{ $options.i18n.approvalsInvalid }}
            </template>
          </gl-form-group>

          <gl-toggle
            v-if="isGroupRule(approver)"
            :id="inheritanceId(index)"
            :key="`${index}-inheritance`"
            :label="$options.i18n.inheritanceLabel"
            :name="`approval-inheritance-${approver.name}`"
            :value="approver.groupInheritanceType"
            label-position="hidden"
            class="gl-align-items-center"
            @change="updateApproverInheritance(approver, $event)"
          />
          <span v-else :key="`${index}-inheritance`"></span>
          <gl-button
            :key="`${index}-remove`"
            v-gl-tooltip
            :title="$options.i18n.removeApprover"
            :aria-label="$options.i18n.removeApprover"
            icon="remove"
            :data-testid="`remove-approver-${approver.name}`"
            @click="removeApprover(approver)"
          />
        </template>
      </div>
    </gl-collapse>
  </div>
</template>
