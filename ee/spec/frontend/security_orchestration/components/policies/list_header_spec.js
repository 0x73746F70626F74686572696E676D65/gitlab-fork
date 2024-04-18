import { GlButton, GlSprintf } from '@gitlab/ui';
import { nextTick } from 'vue';
import BreakingChangesBanner from 'ee/security_orchestration/components/policies/banners/breaking_changes_banner.vue';
import ExperimentFeaturesBanner from 'ee/security_orchestration/components/policies/banners/experiment_features_banner.vue';
import InvalidPoliciesBanner from 'ee/security_orchestration/components/policies/banners/invalid_policies_banner.vue';
import ListHeader from 'ee/security_orchestration/components/policies/list_header.vue';
import ProjectModal from 'ee/security_orchestration/components/policies/project_modal.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { NEW_POLICY_BUTTON_TEXT } from 'ee/security_orchestration/components/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('List Header Component', () => {
  let wrapper;

  const documentationPath = '/path/to/docs';
  const newPolicyPath = '/path/to/new/policy/page';
  const projectLinkSuccessText = 'Project was linked successfully.';

  const findErrorAlert = () => wrapper.findByTestId('error-alert');
  const findScanNewPolicyModal = () => wrapper.findComponent(ProjectModal);
  const findHeader = () => wrapper.findByRole('heading');
  const findMoreInformationLink = () => wrapper.findComponent(GlButton);
  const findEditPolicyProjectButton = () => wrapper.findByTestId('edit-project-policy-button');
  const findViewPolicyProjectButton = () => wrapper.findByTestId('view-project-policy-button');
  const findNewPolicyButton = () => wrapper.findByTestId('new-policy-button');
  const findSubheader = () => wrapper.findByTestId('policies-subheader');
  const findExperimentFeaturesBanner = () => wrapper.findComponent(ExperimentFeaturesBanner);
  const findBreakingChangesBanner = () => wrapper.findComponent(BreakingChangesBanner);
  const findInvalidPoliciesBanner = () => wrapper.findComponent(InvalidPoliciesBanner);

  const linkSecurityPoliciesProject = async () => {
    findScanNewPolicyModal().vm.$emit('project-updated', {
      text: projectLinkSuccessText,
      variant: 'success',
    });
    await nextTick();
  };

  const createWrapper = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(ListHeader, {
      propsData: {
        hasInvalidPolicies: false,
        ...props,
      },
      provide: {
        documentationPath,
        newPolicyPath,
        assignedPolicyProject: null,
        disableScanPolicyUpdate: false,
        disableSecurityPolicyProject: false,
        namespaceType: NAMESPACE_TYPES.PROJECT,
        ...provide,
      },
      stubs: {
        GlButton,
        GlSprintf,
      },
    });
  };

  describe('project owner', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('displays "New policy" button with correct text and link', () => {
      expect(findNewPolicyButton().exists()).toBe(true);
      expect(findNewPolicyButton().text()).toBe(NEW_POLICY_BUTTON_TEXT);
      expect(findNewPolicyButton().attributes('href')).toBe(newPolicyPath);
      expect(findExperimentFeaturesBanner().exists()).toBe(false);
    });

    it.each`
      status        | component                       | findFn                         | exists
      ${'does'}     | ${'edit policy project button'} | ${findEditPolicyProjectButton} | ${true}
      ${'does not'} | ${'view policy project button'} | ${findViewPolicyProjectButton} | ${false}
      ${'does not'} | ${'alert component'}            | ${findErrorAlert}              | ${false}
      ${'does'}     | ${'header'}                     | ${findHeader}                  | ${true}
      ${'does not'} | ${'invalid policies banner'}    | ${findInvalidPoliciesBanner}   | ${false}
    `('$status display the $component', ({ findFn, exists }) => {
      expect(findFn().exists()).toBe(exists);
    });

    it('mounts the scan new policy modal', () => {
      expect(findScanNewPolicyModal().exists()).toBe(true);
    });

    it('displays scan new policy modal when the action button is clicked', async () => {
      await findEditPolicyProjectButton().trigger('click');

      expect(findScanNewPolicyModal().props().visible).toBe(true);
    });

    describe('linking security policies project', () => {
      beforeEach(async () => {
        await linkSecurityPoliciesProject();
      });

      it('displays the alert component when scan new modal policy emits event', () => {
        expect(findErrorAlert().text()).toBe(projectLinkSuccessText);
        expect(wrapper.emitted('update-policy-list')).toStrictEqual([
          [
            {
              hasPolicyProject: undefined,
              shouldUpdatePolicyList: true,
            },
          ],
        ]);
      });

      it('hides the previous alert when scan new modal policy is processing a new link', async () => {
        findScanNewPolicyModal().vm.$emit('updating-project');
        await nextTick();
        expect(findErrorAlert().exists()).toBe(false);
      });
    });
  });

  describe('subheader', () => {
    it.each`
      namespaceType              | expectedText
      ${NAMESPACE_TYPES.GROUP}   | ${'Enforce security policies for this group.'}
      ${NAMESPACE_TYPES.PROJECT} | ${'Enforce security policies for this project.'}
    `('displays the subheader for $namespaceType', ({ namespaceType, expectedText }) => {
      createWrapper({ provide: { namespaceType } });
      expect(findSubheader().text()).toMatchInterpolatedText(expectedText);
      expect(findMoreInformationLink().attributes('href')).toBe(documentationPath);
    });
  });

  describe('alerts', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('hides shows breaking change alert by default', () => {
      expect(findBreakingChangesBanner().exists()).toBe(true);
    });

    it('displays the invalid policies banner when there are invalid policies', () => {
      createWrapper({ props: { hasInvalidPolicies: true } });
      expect(findInvalidPoliciesBanner().exists()).toBe(true);
    });
  });

  describe('project user', () => {
    it('does not display "New policy" button', () => {
      createWrapper({
        provide: {
          assignedPolicyProject: { id: '1' },
          disableSecurityPolicyProject: true,
          disableScanPolicyUpdate: true,
        },
      });

      expect(findNewPolicyButton().exists()).toBe(false);
    });

    describe('with a security policy project', () => {
      beforeEach(() => {
        createWrapper({
          provide: { assignedPolicyProject: { id: '1' }, disableSecurityPolicyProject: true },
        });
      });

      it.each`
        status        | component                       | findFn                         | exists
        ${'does not'} | ${'edit policy project button'} | ${findEditPolicyProjectButton} | ${false}
        ${'does'}     | ${'view policy project button'} | ${findViewPolicyProjectButton} | ${true}
      `('$status display the $component', ({ findFn, exists }) => {
        expect(findFn().exists()).toBe(exists);
      });
    });

    describe('without a security policy project', () => {
      beforeEach(() => {
        createWrapper({
          provide: { disableSecurityPolicyProject: true },
        });
      });

      it.each`
        component                       | findFn
        ${'edit policy project button'} | ${findEditPolicyProjectButton}
        ${'view policy project button'} | ${findViewPolicyProjectButton}
      `('does not display the $component', ({ findFn }) => {
        expect(findFn().exists()).toBe(false);
      });
    });
  });

  describe('experiments promotion banner', () => {
    it.each`
      compliancePipelineInPolicies | expectedResult
      ${true}                      | ${true}
      ${false}                     | ${false}
    `(
      'renders experiments promotion banner',
      ({ compliancePipelineInPolicies, expectedResult }) => {
        createWrapper({
          provide: {
            glFeatures: {
              compliancePipelineInPolicies,
            },
          },
        });

        expect(findExperimentFeaturesBanner().exists()).toBe(expectedResult);
      },
    );
  });
});
