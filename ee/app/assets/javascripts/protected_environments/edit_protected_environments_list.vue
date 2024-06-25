<script>
import {
  GlAvatar,
  GlButton,
  GlFormGroup,
  GlFormInput,
  GlIcon,
  GlTooltipDirective as GlTooltip,
  GlToggle,
} from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions, mapGetters } from 'vuex';
import { s__, __ } from '~/locale';
import AccessDropdown from '~/projects/settings/components/access_dropdown.vue';
import ShowMore from '~/vue_shared/components/show_more.vue';
import { ACCESS_LEVELS, DEPLOYER_RULE_KEY, APPROVER_RULE_KEY, INHERITED_GROUPS } from './constants';
import EditProtectedEnvironmentRulesCard from './edit_protected_environment_rules_card.vue';
import AddRuleModal from './add_rule_modal.vue';
import AddApprovers from './add_approvers.vue';
import ProtectedEnvironments from './protected_environments.vue';

export default {
  components: {
    GlAvatar,
    GlButton,
    GlFormGroup,
    GlFormInput,
    GlIcon,
    GlToggle,
    AccessDropdown,
    ProtectedEnvironments,
    EditProtectedEnvironmentRulesCard,
    AddRuleModal,
    AddApprovers,
    ShowMore,
  },
  directives: {
    GlTooltip,
  },
  inject: { accessLevelsData: { default: [] } },
  data() {
    return { isAddingRule: false, addingEnvironment: null, addingRule: '' };
  },
  computed: {
    ...mapState(['projectId', 'loading', 'protectedEnvironments', 'editingRules']),
    ...mapGetters(['getUsersForRule']),
    isAddingDeploymentRule() {
      return this.addingRule === DEPLOYER_RULE_KEY;
    },
    addRuleModalTitle() {
      return this.isAddingDeploymentRule
        ? this.$options.i18n.addDeploymentRuleModalTitle
        : this.$options.i18n.addApprovalRuleModalTitle;
    },
  },
  mounted() {
    this.fetchProtectedEnvironments();
  },
  methods: {
    ...mapActions([
      'fetchProtectedEnvironments',
      'deleteRule',
      'setRule',
      'saveRule',
      'editRule',
      'updateRule',
      'unprotectEnvironment',
      'updateApproverInheritance',
    ]),
    canDeleteDeployerRules(env) {
      return env[DEPLOYER_RULE_KEY].length > 1;
    },
    addRule({ environment, ruleKey }) {
      this.addingEnvironment = environment;
      this.addingRule = ruleKey;
      this.isAddingRule = true;
    },
    isUserRule({ user_id: userId }) {
      return userId != null;
    },
    isGroupRule({ group_id: groupId }) {
      return groupId != null;
    },
    isUsingGroupInheritance({ group_inheritance_type: type }) {
      return type === INHERITED_GROUPS;
    },
  },
  i18n: {
    deployersHeader: s__('ProtectedEnvironments|Allowed to deploy'),
    approversHeader: s__('ProtectedEnvironments|Allowed to approve'),
    approvalsHeader: s__('ProtectedEnvironments|Approvals required'),
    usersHeader: s__('ProtectedEnvironments|Users'),
    addDeployerText: s__('ProtectedEnvironments|Add deployment rules'),
    addApproverText: s__('ProtectedEnvironments|Add approval rules'),
    deployerDeleteButtonTitle: s__('ProtectedEnvironments|Delete deployer rule'),
    approverDeleteButtonTitle: s__('ProtectedEnvironments|Delete approver rule'),
    addDeploymentRuleModalTitle: s__('ProtectedEnvironments|Create deployment rule'),
    addApprovalRuleModalTitle: s__('ProtectedEnvironments|Create approval rule'),
    addModalText: __('Set a group, access level or users who are required to deploy.'),
    addDeployerLabel: s__('ProtectedEnvironments|Allowed to deploy'),
    approvalCount: s__('ProtectedEnvironments|Required approval count'),
    editApproverButton: s__('ProtectedEnvironments|Edit'),
    saveApproverButton: s__('ProtectedEnvironments|Save'),
    accessDropdownLabel: s__('ProtectedEnvironments|Select users'),
    inheritanceLabel: s__('ProtectedEnvironments|Enable group inheritance'),
    inheritanceTooltip: s__(
      'ProtectedEnvironments|If a group is invited to the current project, its parent and members inherit the permissions of the invited group.',
    ),
  },
  ACCESS_LEVELS,
  DEPLOYER_RULE_KEY,
  APPROVER_RULE_KEY,
  AVATAR_LIMIT: 5,
};
</script>
<template>
  <div data-testid="protected-environments-list">
    <add-rule-modal
      v-model="isAddingRule"
      :title="addRuleModalTitle"
      @saveRule="saveRule({ environment: addingEnvironment, ruleKey: addingRule })"
    >
      <template v-if="isAddingDeploymentRule" #add-rule-form>
        <p>{{ $options.i18n.addModalText }}</p>
        <gl-form-group
          :label="$options.i18n.addDeployerLabel"
          label-for="update-deployer-dropdown"
          data-testid="create-deployer-dropdown"
        >
          <access-dropdown
            id="update-deployer-dropdown"
            class="gl-w-3/10"
            :label="$options.i18n.accessDropdownLabel"
            :access-levels-data="accessLevelsData"
            groups-with-project-access
            :access-level="$options.ACCESS_LEVELS.DEPLOY"
            @hidden="setRule({ environment: addingEnvironment, newRules: $event })"
          />
        </gl-form-group>
      </template>
      <template v-else #add-rule-form>
        <add-approvers
          :project-id="projectId"
          @change="setRule({ environment: addingEnvironment, newRules: $event })"
        />
      </template>
    </add-rule-modal>

    <protected-environments :environments="protectedEnvironments" @unprotect="unprotectEnvironment">
      <template #default="{ environment }">
        <edit-protected-environment-rules-card
          :loading="loading"
          :add-button-text="$options.i18n.addDeployerText"
          :environment="environment"
          :rule-key="$options.DEPLOYER_RULE_KEY"
          :data-testid="`protected-environment-${environment.name}-deployers`"
          class="gl-rounded-top-base gl-border gl-border-b-initial"
          @addRule="addRule"
        >
          <template #card-header>
            <span class="gl-w-3/10">{{ $options.i18n.deployersHeader }}</span>
            <span class="">{{ $options.i18n.usersHeader }}</span>
          </template>
          <template #rule="{ rule, ruleKey }">
            <span class="gl-w-3/10" data-testid="rule-description">
              {{ rule.access_level_description }}
            </span>

            <div class="gl-w-1/2">
              <show-more
                #default="{ item }"
                :limit="$options.AVATAR_LIMIT"
                :items="getUsersForRule(rule, ruleKey)"
              >
                <gl-avatar
                  :key="item.id"
                  v-gl-tooltip
                  :src="item.avatar_url"
                  :title="item.name"
                  :size="24"
                  class="gl-mr-2"
                />
              </show-more>
            </div>

            <gl-button
              v-if="canDeleteDeployerRules(environment)"
              v-gl-tooltip
              category="secondary"
              variant="danger"
              icon="remove"
              :loading="loading"
              :title="$options.i18n.deployerDeleteButtonTitle"
              :aria-label="$options.i18n.deployerDeleteButtonTitle"
              class="gl-ml-auto"
              @click="deleteRule({ environment, rule, ruleKey })"
            />
          </template>
        </edit-protected-environment-rules-card>
        <edit-protected-environment-rules-card
          :loading="loading"
          :add-button-text="$options.i18n.addApproverText"
          :environment="environment"
          :rule-key="$options.APPROVER_RULE_KEY"
          :data-testid="`protected-environment-${environment.name}-approvers`"
          class="gl-rounded-bottom-left-base gl-rounded-bottom-right-base gl-border"
          @addRule="addRule"
        >
          <template #card-header>
            <span class="gl-w-3/10">{{ $options.i18n.approversHeader }}</span>
            <span class="gl-w-2/10">{{ $options.i18n.usersHeader }}</span>
            <span class="gl-w-2/10">{{ $options.i18n.approvalsHeader }}</span>
            <div class="gl-w-3/10">
              <span>{{ $options.i18n.inheritanceLabel }}</span>
              <gl-icon
                v-gl-tooltip
                :title="$options.i18n.inheritanceTooltip"
                :aria-label="$options.i18n.inheritanceTooltip"
                name="question-o"
                class="gl-ml-2"
              />
            </div>
          </template>
          <template #rule="{ rule, ruleKey }">
            <span class="gl-w-3/10" data-testid="rule-description">
              {{ rule.access_level_description }}
            </span>

            <div class="gl-w-2/10">
              <show-more
                #default="{ item }"
                :limit="$options.AVATAR_LIMIT"
                :items="getUsersForRule(rule, ruleKey)"
              >
                <gl-avatar
                  :key="item.id"
                  v-gl-tooltip
                  :src="item.avatar_url"
                  :title="item.name"
                  :size="24"
                  class="gl-mr-2"
                />
              </show-more>
            </div>

            <template v-if="editingRules[rule.id]">
              <gl-form-group
                :label-for="`approval-count-${rule.id}`"
                :label="$options.i18n.approvalCount"
                label-sr-only
                class="gl-w-2/10 gl-mb-0"
              >
                <gl-form-input
                  :id="`approval-count-${rule.id}`"
                  v-model="editingRules[rule.id].required_approvals"
                  :name="`approval-count-${rule.id}`"
                  class="gl-text-center"
                />
              </gl-form-group>

              <gl-toggle
                v-if="isGroupRule(rule)"
                :id="`approval-inheritance-${rule.id}`"
                :label="$options.i18n.inheritanceLabel"
                :name="`approval-inheritance-${rule.id}`"
                :value="isUsingGroupInheritance(editingRules[rule.id])"
                label-position="hidden"
                class="gl-ml-11 gl-align-items-center"
                @change="updateApproverInheritance({ rule, value: $event })"
              />
              <span v-else></span>
              <gl-button
                class="gl-ml-auto gl-mr-4"
                @click="updateRule({ rule, environment, ruleKey })"
              >
                {{ $options.i18n.saveApproverButton }}
              </gl-button>
            </template>
            <template v-else>
              <span class="gl-w-2/10 gl-text-center">{{ rule.required_approvals }}</span>

              <gl-toggle
                v-if="isGroupRule(rule)"
                :label="$options.i18n.inheritanceLabel"
                :name="`approval-inheritance-${rule.id}`"
                :value="isUsingGroupInheritance(rule)"
                class="gl-ml-11 gl-align-items-center"
                label-position="hidden"
                disabled
              />
              <span v-else></span>

              <gl-button
                v-if="!isUserRule(rule)"
                class="gl-ml-auto gl-mr-4"
                @click="editRule(rule)"
              >
                {{ $options.i18n.editApproverButton }}
              </gl-button>
            </template>

            <gl-button
              v-gl-tooltip
              category="secondary"
              variant="danger"
              icon="remove"
              :class="{ 'gl-ml-auto': isUserRule(rule) }"
              :loading="loading"
              :title="$options.i18n.approverDeleteButtonTitle"
              :aria-label="$options.i18n.approverDeleteButtonTitle"
              @click="deleteRule({ environment, rule, ruleKey })"
            />
          </template>
        </edit-protected-environment-rules-card>
      </template>
    </protected-environments>
  </div>
</template>
