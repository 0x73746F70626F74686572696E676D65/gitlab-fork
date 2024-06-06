<script>
import { s__, __ } from '~/locale';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { BOT_MESSAGE_TYPE, fromYaml } from '../../policy_editor/scan_result/lib';
import { SUMMARY_TITLE } from '../constants';
import InfoRow from '../info_row.vue';
import DrawerLayout from '../drawer_layout.vue';
import ToggleList from '../toggle_list.vue';
import Approvals from './policy_approvals.vue';
import Settings from './policy_settings.vue';
import { humanizeRules } from './utils';

export default {
  i18n: {
    fallbackTitle: s__('SecurityOrchestration|Fallback behavior in case of policy failure'),
    summary: SUMMARY_TITLE,
    scanResult: s__('SecurityOrchestration|Merge request approval'),
  },
  components: {
    ToggleList,
    DrawerLayout,
    InfoRow,
    Approvals,
    Settings,
  },
  props: {
    policy: {
      type: Object,
      required: true,
    },
  },
  computed: {
    actions() {
      return this.parsedYaml?.actions;
    },
    description() {
      return this.parsedYaml?.description;
    },
    fallbackBehaviorText() {
      switch (this.parsedYaml?.fallback_behavior?.fail) {
        case 'open':
          return s__(
            'ScanResultPolicy|Fail open: Allow the merge request to proceed, even if not all criteria are met',
          );
        case 'closed':
          return s__(
            'ScanResultPolicy|Fail closed: Block the merge request until all criteria are met',
          );
        default:
          return null;
      }
    },
    humanizedRules() {
      return humanizeRules(this.parsedYaml?.rules);
    },
    parsedYaml() {
      try {
        return fromYaml({ manifest: this.policy.yaml });
      } catch (e) {
        return null;
      }
    },
    requireApproval() {
      return this.actions?.find((action) => action.type === 'require_approval');
    },
    policyScope() {
      return this.policy?.policyScope;
    },
    approvers() {
      return [
        ...this.policy.allGroupApprovers,
        ...this.policy.roleApprovers.map((r) => {
          return {
            GUEST: __('Guest'),
            REPORTER: __('Reporter'),
            DEVELOPER: __('Developer'),
            MAINTAINER: __('Maintainer'),
            OWNER: __('Owner'),
          }[r];
        }),
        ...this.policy.userApprovers,
      ];
    },
    settings() {
      return this.parsedYaml?.approval_settings || {};
    },
    shouldRenderBotMessage() {
      return !this.actions?.some(({ type, enabled }) => type === BOT_MESSAGE_TYPE && !enabled);
    },
  },
  methods: {
    capitalizedCriteriaMessage(message) {
      return capitalizeFirstCharacter(message.trim());
    },
    showBranchExceptions(exceptions) {
      return exceptions?.length > 0;
    },
  },
};
</script>

<template>
  <drawer-layout
    key="scan_result_policy"
    :description="description"
    :policy="policy"
    :policy-scope="policyScope"
    :type="$options.i18n.scanResult"
  >
    <template v-if="parsedYaml" #summary>
      <info-row data-testid="policy-summary" :label="$options.i18n.summary">
        <approvals :action="requireApproval" :approvers="approvers" />
        <div
          v-for="(
            { summary, branchExceptions, criteriaMessage, criteriaList }, idx
          ) in humanizedRules"
          :key="idx"
          class="gl-pt-5"
        >
          {{ summary }}
          <toggle-list
            v-if="showBranchExceptions(branchExceptions)"
            class="gl-mb-2"
            :items="branchExceptions"
          />
          <p v-if="criteriaMessage" class="gl-mb-3">
            {{ capitalizedCriteriaMessage(criteriaMessage) }}
          </p>
          <ul class="gl-m-0">
            <li v-for="(criteria, criteriaIdx) in criteriaList" :key="criteriaIdx" class="gl-mt-2">
              {{ criteria }}
            </li>
          </ul>
          <div v-if="shouldRenderBotMessage" class="gl-mt-5" data-testid="policy-bot-message">
            {{ s__('SecurityOrchestration|Send a bot message when the conditions match.') }}
          </div>
          <settings :settings="settings" />
        </div>
      </info-row>
    </template>

    <template #additional-details>
      <info-row
        v-show="fallbackBehaviorText"
        :label="$options.i18n.fallbackTitle"
        data-testid="additional-details"
      >
        {{ fallbackBehaviorText }}
      </info-row>
    </template>
  </drawer-layout>
</template>
