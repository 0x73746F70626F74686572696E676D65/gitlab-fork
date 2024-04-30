import { nextTick } from 'vue';
import ListHeader from 'ee/security_orchestration/components/policies/list_header.vue';
import ListComponent from 'ee/security_orchestration/components/policies/list_component.vue';
import App from 'ee/security_orchestration/components/policies/app.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('App', () => {
  let wrapper;

  const findPoliciesHeader = () => wrapper.findComponent(ListHeader);
  const findPoliciesList = () => wrapper.findComponent(ListComponent);

  const createWrapper = (assignedPolicyProject = null) => {
    wrapper = shallowMountExtended(App, { provide: { assignedPolicyProject } });
  };

  describe('default', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the policies list correctly', () => {
      expect(findPoliciesList().props('shouldUpdatePolicyList')).toBe(false);
      expect(findPoliciesList().props('hasPolicyProject')).toBe(false);
    });

    it('renders the policy header correctly', () => {
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toBe(false);
    });

    it.each`
      component         | emitFn                | emitData                                                    | finalPropStates
      ${'PolicyHeader'} | ${findPoliciesHeader} | ${{ shouldUpdatePolicyList: true, hasPolicyProject: true }} | ${true}
      ${'PolicyList'}   | ${findPoliciesList}   | ${{ shouldUpdatePolicyList: false }}                        | ${false}
    `(
      'updates the policy list when a change is made from the $component component',
      async ({ emitFn, emitData, finalPropStates }) => {
        expect(findPoliciesList().props('shouldUpdatePolicyList')).toBe(false);
        expect(findPoliciesList().props('hasPolicyProject')).toBe(false);
        emitFn().vm.$emit('update-policy-list', emitData);
        await nextTick();
        expect(findPoliciesList().props('shouldUpdatePolicyList')).toBe(finalPropStates);
        expect(findPoliciesList().props('hasPolicyProject')).toBe(finalPropStates);
      },
    );

    it('updates hasInvalidPolicies when a change is made from the PolicyHeader component', async () => {
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toBe(false);
      await findPoliciesList().vm.$emit('has-invalid-policies', true);
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toBe(true);
    });
  });

  it('renders correctly when a policy project is linked', async () => {
    createWrapper({ id: '1' });
    await nextTick();

    expect(findPoliciesList().props('hasPolicyProject')).toBe(true);
  });
});
