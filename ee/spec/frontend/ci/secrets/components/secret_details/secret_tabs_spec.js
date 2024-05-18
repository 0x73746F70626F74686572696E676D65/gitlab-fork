import { GlTabs } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { EDIT_ROUTE_NAME, DETAILS_ROUTE_NAME, AUDIT_LOG_ROUTE_NAME } from 'ee/ci/secrets/constants';
import SecretTabs from 'ee/ci/secrets/components/secret_details/secret_tabs.vue';

describe('SecretTabs component', () => {
  let wrapper;
  const mockRouter = {
    push: jest.fn(),
  };
  const defaultProps = {
    secretId: 123,
  };

  const findEditSecretButton = () => wrapper.findByTestId('edit-secret-button');
  const findTabs = () => wrapper.findComponent(GlTabs);

  const createComponent = (routeName) => {
    wrapper = shallowMountExtended(SecretTabs, {
      propsData: {
        ...defaultProps,
        routeName,
      },
      stubs: {
        RouterView: true,
      },
      mocks: {
        $router: mockRouter,
        $route: { name: routeName },
      },
    });
  };

  describe.each`
    description                  | routeName               | tabIndex
    ${'details tab is active'}   | ${DETAILS_ROUTE_NAME}   | ${0}
    ${'audit log tab is active'} | ${AUDIT_LOG_ROUTE_NAME} | ${1}
  `(`when $description`, ({ routeName, tabIndex }) => {
    beforeEach(() => {
      createComponent(routeName);
    });

    it('shows a link to the edit secret page', () => {
      findEditSecretButton().vm.$emit('click');
      expect(mockRouter.push).toHaveBeenCalledWith({
        name: EDIT_ROUTE_NAME,
        params: { id: defaultProps.secretId },
      });
    });

    it('highlights the correct tab', () => {
      expect(findTabs().props('value')).toBe(tabIndex);
    });
  });
});
