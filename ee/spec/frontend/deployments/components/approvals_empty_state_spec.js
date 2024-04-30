import { shallowMount } from '@vue/test-utils';
import { GlIcon, GlButton } from '@gitlab/ui';
import ApprovalsEmptyState from 'ee/deployments/components/approvals_empty_state.vue';
import ApprovalsEmptyStateCE from '~/deployments/components/approvals_empty_state.vue';

const PROTECTED_ENVIRONMENTS_SETTINGS_PATH = '/settings/ci_cd#js-protected-environments-settings';

describe('~/deployments/components/approvals_empty_state.vue', () => {
  let wrapper;

  const createComponent = ({
    approvalSummary = { rules: [] },
    protectedEnvironmentsAvailable = true,
  } = {}) => {
    wrapper = shallowMount(ApprovalsEmptyState, {
      propsData: { approvalSummary },
      provide: {
        protectedEnvironmentsAvailable,
        protectedEnvironmentsSettingsPath: PROTECTED_ENVIRONMENTS_SETTINGS_PATH,
      },
    });
  };

  const findCEComponent = () => wrapper.findComponent(ApprovalsEmptyStateCE);
  const findIcon = () => wrapper.findComponent(GlIcon);
  const findButton = () => wrapper.findComponent(GlButton);

  describe('when has no rules set up for the deployment approvals', () => {
    describe('when protected environments features is available', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders approvals empty state with default data', () => {
        expect(findCEComponent().props()).toEqual({
          bannerTitle: 'Set up deployment approvals to get more our of your deployments',
          buttonText: 'Set up Deployment Approvals',
          buttonLink: PROTECTED_ENVIRONMENTS_SETTINGS_PATH,
          illustration: 'file-mock',
        });
      });

      it('renders the correct table header slot', () => {
        expect(findIcon().props('name')).toBe('approval');
        expect(findCEComponent().text()).toContain('Set up deployment approvals to get started');
      });

      it('renders the correct banner actions slot', () => {
        expect(findButton().attributes('href')).toBe('/help/ci/environments/deployment_approvals');
        expect(findButton().text()).toBe('Learn more');
      });
    });

    describe('when protected environments features is not available', () => {
      it('renders approvals empty state with default data', () => {
        createComponent({ protectedEnvironmentsAvailable: false });

        expect(findCEComponent().props()).not.toEqual({
          bannerTitle: 'Set up deployment approvals to get more our of your deployments',
          buttonText: 'Set up Deployment Approvals',
          buttonLink: PROTECTED_ENVIRONMENTS_SETTINGS_PATH,
          illustration: 'file-mock',
        });
      });
    });
  });

  describe('when has rules set up for the deployment approvals', () => {
    beforeEach(() => {
      createComponent({
        approvalSummary: {
          rules: [
            { group: null },
            { user: null },
            {
              accessLevel: {
                stringValue: 'MAINTAINER',
              },
            },
            { approvedCount: 0 },
            { requiredApprovals: 2 },
            { pendingApprovalCount: 2 },
            { approvals: [] },
            { canApprove: true },
          ],
        },
      });
    });

    it("doesn't render approvals empty state", () => {
      expect(findCEComponent().exists()).toBe(false);
    });
  });
});
