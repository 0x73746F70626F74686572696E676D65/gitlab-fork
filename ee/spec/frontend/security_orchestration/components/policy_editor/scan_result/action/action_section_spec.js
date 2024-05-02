import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ActionSection from 'ee/security_orchestration/components/policy_editor/scan_result/action/action_section.vue';
import ApproverAction from 'ee/security_orchestration/components/policy_editor/scan_result/action/approver_action.vue';
import BotCommentAction from 'ee/security_orchestration/components/policy_editor/scan_result/action/bot_message_action.vue';
import {
  BOT_MESSAGE_TYPE,
  REQUIRE_APPROVAL_TYPE,
  DISABLED_BOT_MESSAGE_ACTION,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';

describe('ActionSection', () => {
  let wrapper;

  const defaultProps = {
    actionIndex: 0,
    initAction: { type: REQUIRE_APPROVAL_TYPE },
    existingApprovers: {},
  };
  const factory = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(ActionSection, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findActionSeperator = () => wrapper.findByTestId('action-and-label');
  const findApproverAction = () => wrapper.findComponent(ApproverAction);
  const findBotCommentAction = () => wrapper.findComponent(BotCommentAction);

  describe('general behavior', () => {
    it('renders the action seperator when the action index is > 0', () => {
      factory({ props: { actionIndex: 1 } });
      expect(findActionSeperator().exists()).toBe(true);
    });
  });

  describe('Approval Action', () => {
    beforeEach(() => {
      factory();
    });

    it('renders an approver action for that type of action', () => {
      expect(findApproverAction().exists()).toBe(true);
      expect(findBotCommentAction().exists()).toBe(false);
      expect(findActionSeperator().exists()).toBe(false);
    });

    describe('events', () => {
      it('passes through the "error" event', () => {
        findApproverAction().vm.$emit('error');
        expect(wrapper.emitted('error')).toEqual([[]]);
      });

      it('passes through the "update-approvers" event', () => {
        const event = 'event';
        findApproverAction().vm.$emit('updateApprovers', event);
        expect(wrapper.emitted('updateApprovers')).toEqual([[event]]);
      });

      it('passes through the "changed" event', () => {
        const event = 'event';
        findApproverAction().vm.$emit('changed', event);
        expect(wrapper.emitted('changed')).toEqual([[event]]);
      });

      it('passes through the "remove" event', () => {
        findApproverAction().vm.$emit('remove');
        expect(wrapper.emitted('remove')).toEqual([[]]);
      });
    });
  });

  describe('Bot Comment Action', () => {
    it('renders a bot comment action for that type of action', () => {
      factory({ props: { initAction: { type: BOT_MESSAGE_TYPE } } });
      expect(findBotCommentAction().exists()).toBe(true);
      expect(findApproverAction().exists()).toBe(false);
      expect(findActionSeperator().exists()).toBe(false);
    });

    it('emits "changed" on removal', () => {
      factory({ props: { initAction: { type: BOT_MESSAGE_TYPE } } });
      findBotCommentAction().vm.$emit('remove');
      expect(wrapper.emitted('changed')).toEqual([
        [expect.objectContaining(DISABLED_BOT_MESSAGE_ACTION)],
      ]);
    });
  });
});
