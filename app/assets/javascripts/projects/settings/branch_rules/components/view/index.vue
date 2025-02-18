<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions } from 'vuex';
import {
  GlSprintf,
  GlLink,
  GlLoadingIcon,
  GlCard,
  GlButton,
  GlModal,
  GlModalDirective,
} from '@gitlab/ui';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { sprintf, n__, s__ } from '~/locale';
import {
  getParameterByName,
  mergeUrlParams,
  visitUrl,
  setUrlParams,
} from '~/lib/utils/url_utility';
import { helpPagePath } from '~/helpers/help_page_helper';
import branchRulesQuery from 'ee_else_ce/projects/settings/branch_rules/queries/branch_rules_details.query.graphql';
import { createAlert } from '~/alert';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import editBranchRuleMutation from 'ee_else_ce/projects/settings/branch_rules/mutations/edit_branch_rule.mutation.graphql';
import deleteBranchRuleMutation from '../../mutations/branch_rule_delete.mutation.graphql';
import { getAccessLevels, getAccessLevelInputFromEdges } from '../../../utils';
import BranchRuleModal from '../../../components/branch_rule_modal.vue';
import Protection from './protection.vue';
import RuleDrawer from './rule_drawer.vue';
import ProtectionToggle from './protection_toggle.vue';
import {
  I18N,
  ALL_BRANCHES_WILDCARD,
  BRANCH_PARAM_NAME,
  PROTECTED_BRANCHES_HELP_PATH,
  CODE_OWNERS_HELP_PATH,
  PUSH_RULES_HELP_PATH,
  DELETE_RULE_MODAL_ID,
  EDIT_RULE_MODAL_ID,
} from './constants';

const protectedBranchesHelpDocLink = helpPagePath(PROTECTED_BRANCHES_HELP_PATH);
const codeOwnersHelpDocLink = helpPagePath(CODE_OWNERS_HELP_PATH);
const pushRulesHelpDocLink = helpPagePath(PUSH_RULES_HELP_PATH);

export default {
  name: 'RuleView',
  i18n: I18N,
  deleteModalId: DELETE_RULE_MODAL_ID,
  protectedBranchesHelpDocLink,
  codeOwnersHelpDocLink,
  pushRulesHelpDocLink,
  directives: {
    GlModal: GlModalDirective,
  },
  editModalId: EDIT_RULE_MODAL_ID,
  components: {
    Protection,
    ProtectionToggle,
    GlSprintf,
    GlLink,
    GlLoadingIcon,
    GlCard,
    GlModal,
    GlButton,
    BranchRuleModal,
    RuleDrawer,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    projectPath: {
      default: '',
    },
    protectedBranchesPath: {
      default: '',
    },
    branchRulesPath: {
      default: '',
    },
    branchesPath: {
      default: '',
    },
    showStatusChecks: { default: false },
    showApprovers: { default: false },
    showCodeOwners: { default: false },
  },
  apollo: {
    project: {
      query: branchRulesQuery,
      variables() {
        return {
          projectPath: this.projectPath,
        };
      },
      update({ project: { branchRules, group } }) {
        const branchRule = branchRules.nodes.find((rule) => rule.name === this.branch);
        this.branchRule = branchRule;
        this.branchProtection = branchRule?.branchProtection;
        this.statusChecks = branchRule?.externalStatusChecks?.nodes || [];
        this.matchingBranchesCount = branchRule?.matchingBranchesCount;
        this.groupId = getIdFromGraphQLId(group?.id) || null;
        if (!this.showApprovers) return;
        // The approval rules app uses a separate endpoint to fetch the list of approval rules.
        // In future, we will update the GraphQL request to include the approval rules data.
        // Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/452330
        const approvalRules = branchRule?.approvalRules?.nodes.map((rule) => rule.name) || [];
        this.setRulesFilter(approvalRules);
        this.fetchRules();
      },
      error(error) {
        createAlert({ message: error });
      },
    },
  },
  data() {
    return {
      branch: getParameterByName(BRANCH_PARAM_NAME),
      branchProtection: {},
      statusChecks: [],
      branchRule: {},
      groupId: null,
      matchingBranchesCount: null,
      isAllowedToMergeDrawerOpen: false,
      isAllowedToPushAndMergeDrawerOpen: false,
      isRuleUpdating: false,
      isAllowForcePushLoading: false,
      isCodeOwnersLoading: false,
    };
  },
  computed: {
    forcePushAttributes() {
      const { allowForcePush } = this.branchProtection || {};
      const title = allowForcePush
        ? this.$options.i18n.allowForcePushTitle
        : this.$options.i18n.doesNotAllowForcePushTitle;

      if (!this.glFeatures.editBranchRules) {
        return { title, description: this.$options.i18n.forcePushIconDescription };
      }

      return {
        title,
        description: this.$options.i18n.forcePushDescriptionWithDocs,
      };
    },
    codeOwnersApprovalAttributes() {
      const { codeOwnerApprovalRequired } = this.branchProtection || {};
      const title = codeOwnerApprovalRequired
        ? this.$options.i18n.requiresCodeOwnerApprovalTitle
        : this.$options.i18n.doesNotRequireCodeOwnerApprovalTitle;

      if (!this.glFeatures.editBranchRules) {
        const description = codeOwnerApprovalRequired
          ? this.$options.i18n.requiresCodeOwnerApprovalDescription
          : this.$options.i18n.doesNotRequireCodeOwnerApprovalDescription;

        return { title, description };
      }

      return {
        title,
        description: this.$options.i18n.codeOwnerApprovalDescription,
      };
    },
    mergeAccessLevels() {
      const { mergeAccessLevels } = this.branchProtection || {};
      return this.getAccessLevels(mergeAccessLevels);
    },
    pushAccessLevels() {
      const { pushAccessLevels } = this.branchProtection || {};
      return this.getAccessLevels(pushAccessLevels);
    },
    allowedToMergeHeader() {
      return sprintf(this.$options.i18n.allowedToMergeHeader, {
        total: this.mergeAccessLevels?.total || 0,
      });
    },
    allowedToPushHeader() {
      return sprintf(this.$options.i18n.allowedToPushHeader, {
        total: this.pushAccessLevels?.total || 0,
      });
    },
    allBranches() {
      return this.branch === ALL_BRANCHES_WILDCARD;
    },
    matchingBranchesLinkHref() {
      return mergeUrlParams({ state: 'all', search: `^${this.branch}$` }, this.branchesPath);
    },
    matchingBranchesLinkTitle() {
      const total = this.matchingBranchesCount;
      const subject = n__('branch', 'branches', total);
      return sprintf(this.$options.i18n.matchingBranchesLinkTitle, { total, subject });
    },
    // needed to override EE component
    statusChecksHeader() {
      return '';
    },
    isPredefinedRule() {
      return (
        this.branch === this.$options.i18n.allBranches ||
        this.branch === this.$options.i18n.allProtectedBranches
      );
    },
    hasPushAccessLevelSet() {
      return this.pushAccessLevels?.total > 0;
    },
    accessLevelsDrawerTitle() {
      return this.isAllowedToMergeDrawerOpen
        ? s__('BranchRules|Edit allowed to merge')
        : s__('BranchRules|Edit allowed to push and merge');
    },
    accessLevelsDrawerData() {
      return this.isAllowedToMergeDrawerOpen ? this.mergeAccessLevels : this.pushAccessLevels;
    },
  },
  methods: {
    ...mapActions(['setRulesFilter', 'fetchRules']),
    getAccessLevels,
    getAccessLevelInputFromEdges,
    deleteBranchRule() {
      this.$apollo
        .mutate({
          mutation: deleteBranchRuleMutation,
          variables: {
            input: {
              id: this.branchRule.id,
            },
          },
        })
        .then(
          // eslint-disable-next-line consistent-return
          ({ data: { branchRuleDelete } = {} } = {}) => {
            const [error] = branchRuleDelete.errors;
            if (error) {
              return createAlert({
                message: error.message,
                captureError: true,
              });
            }
            visitUrl(this.branchRulesPath);
          },
        )
        .catch(() => {
          return createAlert({
            message: s__('BranchRules|Something went wrong while deleting branch rule.'),
            captureError: true,
          });
        });
    },
    openAllowedToMergeDrawer() {
      this.isAllowedToMergeDrawerOpen = true;
    },
    closeAccessLevelsDrawer() {
      this.isAllowedToMergeDrawerOpen = false;
      this.isAllowedToPushAndMergeDrawerOpen = false;
    },
    openAllowedToPushAndMergeDrawer() {
      this.isAllowedToPushAndMergeDrawerOpen = true;
    },
    onEnableForcePushToggle(isChecked) {
      this.isAllowForcePushLoading = true;
      const toastMessage = isChecked
        ? this.$options.i18n.allowForcePushEnabled
        : this.$options.i18n.allowForcePushDisabled;

      this.editBranchRule({
        branchProtection: { allowForcePush: isChecked },
        toastMessage,
      });
    },
    onEnableCodeOwnersToggle(isChecked) {
      this.isCodeOwnersLoading = true;
      const toastMessage = isChecked
        ? this.$options.i18n.codeOwnerApprovalEnabled
        : this.$options.i18n.codeOwnerApprovalDisabled;

      this.editBranchRule({
        branchProtection: { codeOwnerApprovalRequired: isChecked },
        toastMessage,
      });
    },
    onEditAccessLevels(accessLevels) {
      this.isRuleUpdating = true;

      if (this.isAllowedToMergeDrawerOpen) {
        this.editBranchRule({
          branchProtection: { mergeAccessLevels: accessLevels },
          toastMessage: s__('BranchRules|Allowed to merge updated'),
        });
      } else if (this.isAllowedToPushAndMergeDrawerOpen) {
        this.editBranchRule({
          branchProtection: { pushAccessLevels: accessLevels },
          toastMessage: s__('BranchRules|Allowed to push and merge updated'),
        });
      }
    },
    editBranchRule({ name = this.branchRule.name, branchProtection = null, toastMessage = '' }) {
      this.$apollo
        .mutate({
          mutation: editBranchRuleMutation,
          variables: {
            input: {
              id: this.branchRule.id,
              name,
              branchProtection: {
                allowForcePush: this.branchProtection.allowForcePush,
                codeOwnerApprovalRequired: this.branchProtection.codeOwnerApprovalRequired,
                pushAccessLevels: this.getAccessLevelInputFromEdges(
                  this.branchProtection.pushAccessLevels.edges,
                ),
                mergeAccessLevels: this.getAccessLevelInputFromEdges(
                  this.branchProtection.mergeAccessLevels.edges,
                ),
                ...(branchProtection || {}),
              },
            },
          },
        })
        .then(({ data: { branchRuleUpdate } }) => {
          if (branchRuleUpdate.errors.length) {
            createAlert({ message: this.$options.i18n.updateBranchRuleError });
            return;
          }

          const isRedirectNeeded = !branchProtection;
          if (isRedirectNeeded) {
            visitUrl(setUrlParams({ branch: name }));
          } else {
            this.closeAccessLevelsDrawer();
            this.$toast.show(toastMessage);
          }
        })
        .catch(() => {
          createAlert({ message: this.$options.i18n.updateBranchRuleError });
        })
        .finally(() => {
          this.isRuleUpdating = false;
          this.isAllowForcePushLoading = false;
          this.isCodeOwnersLoading = false;
        });
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-display-flex gl-justify-content-space-between gl-align-items-center">
      <h1 class="h3 gl-mb-5">{{ $options.i18n.pageTitle }}</h1>
      <gl-button
        v-if="glFeatures.editBranchRules && branchRule"
        v-gl-modal="$options.deleteModalId"
        data-testid="delete-rule-button"
        category="secondary"
        variant="danger"
        :disabled="$apollo.loading"
        >{{ $options.i18n.deleteRule }}
      </gl-button>
    </div>
    <gl-loading-icon v-if="$apollo.loading" size="lg" />
    <div v-else-if="!branchRule && !isPredefinedRule">{{ $options.i18n.noData }}</div>
    <div v-else>
      <gl-card
        class="gl-new-card"
        header-class="gl-new-card-header"
        body-class="gl-new-card-body gl-p-5"
        data-testid="rule-target-card"
      >
        <template #header>
          <strong>{{ $options.i18n.ruleTarget }}</strong>
          <gl-button
            v-if="glFeatures.editBranchRules && !isPredefinedRule"
            v-gl-modal="$options.editModalId"
            data-testid="edit-rule-name-button"
            size="small"
            >{{ $options.i18n.edit }}</gl-button
          >
        </template>
        <div v-if="allBranches" class="gl-mt-2" data-testid="all-branches">
          {{ $options.i18n.allBranches }}
        </div>
        <code v-else class="gl-bg-transparent p-0 gl-font-base" data-testid="branch">{{
          branch
        }}</code>
        <p v-if="matchingBranchesCount" class="gl-mt-3 gl-mb-0">
          <gl-link :href="matchingBranchesLinkHref">{{ matchingBranchesLinkTitle }}</gl-link>
        </p>
      </gl-card>

      <section v-if="!isPredefinedRule">
        <h2 class="h4 gl-mb-1 gl-mt-5">{{ $options.i18n.protectBranchTitle }}</h2>
        <gl-sprintf :message="$options.i18n.protectBranchDescription">
          <template #link="{ content }">
            <gl-link :href="$options.protectedBranchesHelpDocLink">
              {{ content }}
            </gl-link>
          </template>
        </gl-sprintf>

        <!-- Allowed to merge -->
        <protection
          :header="allowedToMergeHeader"
          :header-link-title="$options.i18n.manageProtectionsLinkTitle"
          :header-link-href="protectedBranchesPath"
          :roles="mergeAccessLevels.roles"
          :users="mergeAccessLevels.users"
          :groups="mergeAccessLevels.groups"
          :empty-state-copy="$options.i18n.allowedToMergeEmptyState"
          is-edit-available
          data-testid="allowed-to-merge-content"
          @edit="openAllowedToMergeDrawer"
        />

        <rule-drawer
          :is-open="isAllowedToMergeDrawerOpen || isAllowedToPushAndMergeDrawerOpen"
          :roles="accessLevelsDrawerData.roles"
          :users="accessLevelsDrawerData.users"
          :groups="accessLevelsDrawerData.groups"
          :is-loading="isRuleUpdating"
          :group-id="groupId"
          :title="accessLevelsDrawerTitle"
          @editRule="onEditAccessLevels"
          @close="closeAccessLevelsDrawer"
        />

        <!-- Allowed to push -->
        <protection
          class="gl-mt-3"
          :header="allowedToPushHeader"
          :header-link-title="$options.i18n.manageProtectionsLinkTitle"
          :header-link-href="protectedBranchesPath"
          :roles="pushAccessLevels.roles"
          :users="pushAccessLevels.users"
          :groups="pushAccessLevels.groups"
          :empty-state-copy="$options.i18n.allowedToPushEmptyState"
          :help-text="$options.i18n.allowedToPushDescription"
          is-edit-available
          data-testid="allowed-to-push-content"
          @edit="openAllowedToPushAndMergeDrawer"
        />

        <!-- Force push -->
        <protection-toggle
          v-if="hasPushAccessLevelSet"
          data-testid="force-push-content"
          data-test-id-prefix="force-push"
          :is-protected="branchProtection.allowForcePush"
          :label="$options.i18n.allowForcePushLabel"
          :icon-title="forcePushAttributes.title"
          :description="forcePushAttributes.description"
          :description-link="$options.pushRulesHelpDocLink"
          :is-loading="isAllowForcePushLoading"
          @toggle="onEnableForcePushToggle"
        />

        <!-- EE start -->
        <!-- Code Owners -->
        <protection-toggle
          v-if="showCodeOwners"
          data-testid="code-owners-content"
          data-test-id-prefix="code-owners"
          :is-protected="branchProtection.codeOwnerApprovalRequired"
          :label="$options.i18n.requiresCodeOwnerApprovalLabel"
          :icon-title="codeOwnersApprovalAttributes.title"
          :description="codeOwnersApprovalAttributes.description"
          :description-link="$options.codeOwnersHelpDocLink"
          :is-loading="isCodeOwnersLoading"
          @toggle="onEnableCodeOwnersToggle"
        />
      </section>

      <!-- Approvals -->
      <template v-if="showApprovers">
        <h2 class="h4 gl-mb-1 gl-mt-5">{{ $options.i18n.approvalsTitle }}</h2>
        <gl-sprintf :message="$options.i18n.approvalsDescription">
          <template #link="{ content }">
            <gl-link :href="$options.approvalsHelpDocLink">
              {{ content }}
            </gl-link>
          </template>
        </gl-sprintf>

        <!-- eslint-disable-next-line vue/no-undef-components -->
        <approval-rules-app
          :is-mr-edit="false"
          :is-branch-rules-edit="true"
          @submitted="$apollo.queries.project.refetch()"
        >
          <template #rules>
            <!-- eslint-disable-next-line vue/no-undef-components -->
            <project-rules :is-branch-rules-edit="true" />
          </template>
        </approval-rules-app>
      </template>

      <!-- Status checks -->
      <template v-if="showStatusChecks">
        <h2 class="h4 gl-mb-1 gl-mt-5">{{ $options.i18n.statusChecksTitle }}</h2>
        <gl-sprintf :message="$options.i18n.statusChecksDescription">
          <template #link="{ content }">
            <gl-link :href="$options.statusChecksHelpDocLink">
              {{ content }}
            </gl-link>
          </template>
        </gl-sprintf>

        <protection
          data-testid="status-checks-content"
          class="gl-mt-3"
          :header="statusChecksHeader"
          :header-link-title="$options.i18n.statusChecksLinkTitle"
          :header-link-href="statusChecksPath"
          :status-checks="statusChecks"
          :empty-state-copy="$options.i18n.statusChecksEmptyState"
        />
      </template>
      <!-- EE end -->
      <gl-modal
        v-if="glFeatures.editBranchRules"
        :ref="$options.deleteModalId"
        :modal-id="$options.deleteModalId"
        :title="$options.i18n.deleteRuleModalTitle"
        :ok-title="$options.i18n.deleteRuleModalDeleteText"
        ok-variant="danger"
        @ok="deleteBranchRule"
      >
        <p>{{ $options.i18n.deleteRuleModalText }}</p>
      </gl-modal>

      <branch-rule-modal
        v-if="glFeatures.editBranchRules"
        :id="$options.editModalId"
        :ref="$options.editModalId"
        :title="$options.i18n.updateTargetRule"
        :action-primary-text="$options.i18n.update"
        @primary="editBranchRule({ name: $event })"
      />
    </div>
  </div>
</template>
