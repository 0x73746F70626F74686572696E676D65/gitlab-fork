import { GlAlert, GlDropdown, GlDropdownItem, GlSprintf } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SelectionSummary from 'ee/security_dashboard/components/shared/vulnerability_report/selection_summary.vue';
import eventHub from 'ee/security_dashboard/utils/event_hub';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import toast from '~/vue_shared/plugins/global_toast';
import { VULNERABILITY_STATE_OBJECTS } from 'ee/vulnerabilities/constants';

jest.mock('~/vue_shared/plugins/global_toast');

Vue.use(VueApollo);

describe('Selection Summary component', () => {
  let wrapper;

  const createApolloProvider = (...queries) => {
    return createMockApollo([...queries]);
  };

  const findForm = () => wrapper.find('form');
  const findGlAlert = () => wrapper.findComponent(GlAlert);
  const findStatusDropdown = () => wrapper.findComponent(GlDropdown);
  const findAllDropdownItems = () => wrapper.findAllComponents(GlDropdownItem);
  const findDropdownItem = (status) => wrapper.findByTestId(status);
  const findCancelButton = () => wrapper.find('[type="button"]');
  const findSubmitButton = () => wrapper.find('[type="submit"]');

  const isAllButtonsDisabled = () => {
    return (
      findSubmitButton().props('loading') &&
      findCancelButton().props('disabled') &&
      findStatusDropdown().props('disabled')
    );
  };

  const createComponent = ({ props = {}, apolloProvider } = {}) => {
    wrapper = shallowMountExtended(SelectionSummary, {
      apolloProvider,
      stubs: {
        GlAlert,
        GlSprintf,
      },
      propsData: {
        selectedVulnerabilities: [],
        ...props,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('with 1 vulnerability selected', () => {
    beforeEach(() => {
      createComponent({ props: { selectedVulnerabilities: [{ id: 'id_0' }] } });
    });

    it('renders correctly', () => {
      expect(findForm().text()).toContain('1 Selected');
    });

    describe('with selected state', () => {
      beforeEach(async () => {
        findAllDropdownItems().at(0).vm.$emit('click');
        await nextTick();
      });

      it('shows the submit and cancel buttons', () => {
        expect(findSubmitButton().exists()).toBe(true);
        expect(findCancelButton().exists()).toBe(true);
      });
    });

    describe('with no selected state', () => {
      it('does not show the submit and cancel buttons', () => {
        expect(findSubmitButton().exists()).toBe(false);
        expect(findCancelButton().exists()).toBe(false);
      });
    });
  });

  describe('with multiple vulnerabilities selected', () => {
    beforeEach(() => {
      createComponent({ props: { selectedVulnerabilities: [{ id: 'id_0' }, { id: 'id_1' }] } });
    });

    it('renders correctly', () => {
      expect(findForm().text()).toContain('2 Selected');
    });
  });

  describe('status dropdown', () => {
    it('shows the placeholder text when no status is selected', () => {
      createComponent();

      expect(findStatusDropdown().props('text')).toBe(
        wrapper.vm.$options.i18n.statusDropdownPlaceholder,
      );
    });

    it('shows expected dropdown items', () => {
      createComponent();

      const states = Object.values(VULNERABILITY_STATE_OBJECTS);

      expect(findAllDropdownItems()).toHaveLength(states.length);

      states.forEach((state) => {
        const dropdownText = findDropdownItem(state.action).text();
        expect(dropdownText).toContain(state.dropdownText);
        expect(dropdownText).toContain(state.dropdownDescription);
      });
    });

    it.each(Object.entries(VULNERABILITY_STATE_OBJECTS))(
      'shows the expected text in the dropdown button when %s is clicked',
      async (key, state) => {
        createComponent();

        const item = findDropdownItem(state.action);
        item.vm.$emit('click');
        await nextTick();

        // Check that only 1 item is checked.
        expect(findAllDropdownItems().wrappers.filter((x) => x.props('isChecked'))).toHaveLength(1);
        expect(item.props('isChecked')).toBe(true);
        expect(findStatusDropdown().props('text')).toBe(state.dropdownText);
      },
    );
  });

  describe.each(Object.entries(VULNERABILITY_STATE_OBJECTS))(
    'state dropdown change - %s',
    (key, { action, state, payload, mutation }) => {
      const selectedVulnerabilities = [
        { id: 'gid://gitlab/Vulnerability/54' },
        { id: 'gid://gitlab/Vulnerability/56' },
        { id: 'gid://gitlab/Vulnerability/58' },
      ];

      const submitForm = () => {
        findDropdownItem(action).vm.$emit('click');
        findForm().trigger('submit');
        return waitForPromises();
      };

      describe('when API call fails', () => {
        beforeEach(() => {
          const apolloProvider = createApolloProvider([
            mutation,
            jest.fn().mockRejectedValue({
              data: {
                [mutation.definitions[0].name.value]: {
                  errors: [
                    {
                      message: 'Something went wrong',
                    },
                  ],
                },
              },
            }),
          ]);

          createComponent({ apolloProvider, props: { selectedVulnerabilities } });
        });

        it(`does not emit vulnerability-updated event - ${action}`, async () => {
          await submitForm();
          expect(wrapper.emitted()['vulnerability-updated']).toBeUndefined();
        });

        it(`calls the toaster - ${action}`, async () => {
          await submitForm();
          expect(findGlAlert().text()).toBe(
            'Failed updating vulnerabilities with the following IDs: 54, 56, 58',
          );
        });
      });

      describe('when API call is successful', () => {
        const requestHandler = jest.fn().mockResolvedValue({
          data: {
            [mutation.definitions[0].name.value]: {
              errors: [],
              vulnerability: {
                id: selectedVulnerabilities[0].id,
                [`${state}At`]: '2020-09-16T11:13:26Z',
                state: state.toUpperCase(),
              },
            },
          },
        });

        beforeEach(() => {
          const apolloProvider = createApolloProvider([mutation, requestHandler]);

          createComponent({
            apolloProvider,
            props: { selectedVulnerabilities },
          });
        });

        it(`calls the mutation with the expected data and emits an update for each vulnerability - ${action}`, async () => {
          await submitForm();
          selectedVulnerabilities.forEach((v, i) => {
            expect(wrapper.emitted()['vulnerability-updated'][i][0]).toBe(v.id);
            expect(requestHandler).toHaveBeenCalledWith(
              expect.objectContaining({ id: v.id, ...payload }),
            );
          });
        });

        it(`calls the toaster - ${action}`, async () => {
          await submitForm();
          // Workaround for the detected state, which shows as "needs triage" in the UI but uses
          // "detected" behind the scenes.
          const stateString =
            state === VULNERABILITY_STATE_OBJECTS.detected.state ? 'needs triage' : state;

          expect(toast).toHaveBeenLastCalledWith(`3 vulnerabilities set to ${stateString}`);
        });

        it(`the submit button is unclickable during form submission - ${action}`, async () => {
          expect(findSubmitButton().exists()).toBe(false);
          submitForm();
          await nextTick();
          expect(isAllButtonsDisabled()).toBe(true);
          await waitForPromises();
          expect(isAllButtonsDisabled()).toBe(false);
        });

        it(`emits an event for the event hub - ${action}`, async () => {
          const spy = jest.fn();
          eventHub.$on('vulnerabilities-updated', spy);

          await submitForm();
          expect(spy).toHaveBeenCalled();
        });
      });
    },
  );
});
