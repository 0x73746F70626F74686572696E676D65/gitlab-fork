<script>
import { GlAccordion, GlAccordionItem, GlSprintf, GlLink } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState } from 'vuex';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { helpPagePath } from '~/helpers/help_page_helper';
import { __, n__, sprintf, s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ApprovalRulesApp from 'ee/approvals/components/approval_rules_app.vue';
import MrRules from './mr_rules.vue';
import MrRulesHiddenInputs from './mr_rules_hidden_inputs.vue';

export default {
  components: {
    GlAccordion,
    GlAccordionItem,
    GlSprintf,
    GlLink,
    ApprovalRulesApp,
    MrRules,
    MrRulesHiddenInputs,
  },
  directives: {
    SafeHtml,
  },
  mixins: [glFeatureFlagsMixin()],
  computed: {
    ...mapState({
      rules: (state) => state.approvals.rules,
      canOverride: (state) => state.settings.canOverride,
      canUpdateApprovers: (state) => state.settings.canUpdateApprovers,
      showCodeOwnerTip: (state) => state.settings.showCodeOwnerTip,
    }),
    accordionTitle() {
      return s__('ApprovalRule|Approval rules');
    },
    hasOptionalRules() {
      return this.rules.every((r) => r.approvalsRequired === 0);
    },
    requiredRules() {
      return this.rules.reduce((acc, rule) => {
        if (rule.approvalsRequired > 0) {
          acc.push(rule);
        }

        return acc;
      }, []);
    },
    collapsedSummary() {
      const rulesLength = this.requiredRules.length;
      const firstRule = this.requiredRules[0];

      if (this.hasOptionalRules) {
        return __('Approvals are optional.');
      }
      if (rulesLength === 1 && firstRule.ruleType === 'any_approver') {
        return sprintf(
          n__(
            '%{strong_start}%{count} member%{strong_end} must approve to merge. Anyone with role Developer or higher can approve.',
            '%{strong_start}%{count} members%{strong_end} must approve to merge. Anyone with role Developer or higher can approve.',
            firstRule.approvalsRequired,
          ),
          {
            strong_start: '<strong>',
            strong_end: '</strong>',
            count: firstRule.approvalsRequired,
          },
          false,
        );
      }
      if (rulesLength === 1 && firstRule.ruleType !== 'any_approver') {
        return sprintf(
          n__(
            '%{strong_start}%{count} eligible member%{strong_end} must approve to merge.',
            '%{strong_start}%{count} eligible members%{strong_end} must approve to merge.',
            firstRule.approvalsRequired,
          ),
          {
            strong_start: '<strong>',
            strong_end: '</strong>',
            count: firstRule.approvalsRequired,
          },
          false,
        );
      }
      if (rulesLength > 1) {
        return sprintf(
          n__(
            '%{strong_start}%{count} approval rule%{strong_end} requires eligible members to approve before merging.',
            '%{strong_start}%{count} approval rules%{strong_end} require eligible members to approve before merging.',
            rulesLength,
          ),
          {
            strong_start: '<strong>',
            strong_end: '</strong>',
            count: rulesLength,
          },
          false,
        );
      }

      return null;
    },
  },
  codeOwnerHelpPage: helpPagePath('user/project/code_owners'),
};
</script>

<template>
  <div class="gl-mt-2">
    <p
      v-safe-html="collapsedSummary"
      class="gl-mb-0 gl-text-gray-500"
      data-testid="collapsedSummaryText"
    ></p>

    <gl-accordion :header-level="3">
      <gl-accordion-item :title="accordionTitle">
        <approval-rules-app>
          <template #rules>
            <mr-rules />
            <mr-rules-hidden-inputs />
          </template>
          <template v-if="canUpdateApprovers && showCodeOwnerTip" #footer>
            <div class="form-text text-muted" data-testid="codeowners-tip">
              <gl-sprintf
                :message="
                  __(
                    'Tip: Add a %{linkStart}CODEOWNERS%{linkEnd} to automatically add approvers based on file paths and file types.',
                  )
                "
              >
                <template #link="{ content }">
                  <gl-link :href="$options.codeOwnerHelpPage" target="_blank">{{
                    content
                  }}</gl-link>
                </template>
              </gl-sprintf>
            </div>
          </template>
        </approval-rules-app>
      </gl-accordion-item>
    </gl-accordion>
  </div>
</template>
