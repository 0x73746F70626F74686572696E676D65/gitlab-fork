import { GlCollapsibleListbox } from '@gitlab/ui';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import ValueStreamSelect from 'ee/analytics/cycle_analytics/components/value_stream_select.vue';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import {
  valueStreams,
  defaultStageConfig,
  newValueStreamPath,
  editValueStreamPath,
} from '../mock_data';

Vue.use(Vuex);

describe('ValueStreamSelect', () => {
  let wrapper = null;
  let trackingSpy = null;

  const deleteValueStreamMock = jest.fn(() => Promise.resolve());
  const mockEvent = { preventDefault: jest.fn() };
  const mockToastShow = jest.fn();
  const streamName = 'Cool stream';
  const selectedValueStream = valueStreams[0];
  const deleteValueStreamError = 'Cannot delete default value stream';
  const editValueStreamPathWithId = editValueStreamPath.replace(':id', selectedValueStream.id);

  const fakeStore = ({ initialState = {} }) =>
    new Vuex.Store({
      state: {
        isCreatingValueStream: false,
        isDeletingValueStream: false,
        createValueStreamErrors: {},
        deleteValueStreamError: null,
        valueStreams: [],
        selectedValueStream: {},
        defaultStageConfig,
        ...initialState,
      },
      actions: {
        deleteValueStream: deleteValueStreamMock,
        setSelectedValueStream: jest.fn(),
      },
    });

  const createComponent = ({
    props = {},
    data = {},
    initialState = {},
    provide = {},
    mountFn = shallowMountExtended,
  } = {}) =>
    mountFn(ValueStreamSelect, {
      store: fakeStore({ initialState }),
      data() {
        return {
          ...data,
        };
      },
      propsData: {
        canEdit: true,
        ...props,
      },
      provide: {
        newValueStreamPath,
        editValueStreamPath,
        glFeatures: {
          vsaStandaloneSettingsPage: true,
        },
        ...provide,
      },
      mocks: {
        $toast: {
          show: mockToastShow,
        },
      },
      directives: {
        GlModalDirective: createMockDirective('gl-modal-directive'),
      },
    });

  const findModal = (modal) => wrapper.findByTestId(`${modal}-value-stream-modal`);
  const submitModal = (modal) => findModal(modal).vm.$emit('primary', mockEvent);
  const findSelectValueStreamDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findCreateValueStreamOption = () => wrapper.findByTestId('create-value-stream-option');
  const findCreateValueStreamButton = () => wrapper.findByTestId('create-value-stream-button');
  const findEditValueStreamButton = () => wrapper.findByTestId('edit-value-stream');
  const findDeleteValueStreamButton = () => wrapper.findByTestId('delete-value-stream');

  afterEach(() => {
    unmockTracking();
  });

  describe('with value streams available', () => {
    describe('default behaviour', () => {
      beforeEach(() => {
        wrapper = createComponent({
          mountFn: mountExtended,
          initialState: {
            valueStreams,
          },
        });
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      });

      it('does not display the create value stream button', () => {
        expect(findCreateValueStreamButton().exists()).toBe(false);
      });

      it('displays the select value stream dropdown', () => {
        expect(findSelectValueStreamDropdown().exists()).toBe(true);
      });

      it('renders each value stream including a create button', () => {
        const opts = findSelectValueStreamDropdown().props('items');
        valueStreams.forEach((vs, index) => {
          expect(opts[index].text).toBe(vs.name);
        });
      });

      it('tracks dropdown events', () => {
        findSelectValueStreamDropdown().vm.$emit('select', valueStreams[0].id);

        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_dropdown', {
          label: 'value_stream_1',
        });
      });
    });

    describe('with a selected value stream', () => {
      describe('with canEdit=true', () => {
        beforeEach(() => {
          wrapper = createComponent({
            mountFn: mountExtended,
            initialState: {
              valueStreams,
              selectedValueStream: {
                ...selectedValueStream,
                isCustom: true,
              },
            },
          });
        });

        it('renders a delete option for custom value streams', () => {
          expect(findDeleteValueStreamButton().exists()).toBe(true);
        });

        it('renders a create option for custom value streams', () => {
          expect(findCreateValueStreamOption().exists()).toBe(true);
          expect(findCreateValueStreamOption().text()).toBe('New Value Stream');
          expect(findCreateValueStreamOption().attributes('href')).toBe(newValueStreamPath);
        });

        it('renders an edit button for custom value streams', () => {
          expect(findEditValueStreamButton().exists()).toBe(true);
          expect(findEditValueStreamButton().text()).toBe('Edit');
          expect(findEditValueStreamButton().attributes('href')).toBe(editValueStreamPathWithId);
        });

        it('does not bind modal directive to edit button', () => {
          const binding = getBinding(findEditValueStreamButton().element, 'gl-modal-directive');

          expect(binding.value).toBe(false);
        });

        it('does not bind modal directive to create option', () => {
          const binding = getBinding(findCreateValueStreamOption().element, 'gl-modal-directive');

          expect(binding.value).toBe(false);
        });

        describe('vsaStandaloneSettingsPage = false', () => {
          beforeEach(() => {
            wrapper = createComponent({
              mountFn: mountExtended,
              initialState: {
                valueStreams,
                selectedValueStream: {
                  ...selectedValueStream,
                  isCustom: true,
                },
              },
              provide: { glFeatures: { vsaStandaloneSettingsPage: false } },
            });
          });

          it('renders create option without a link', () => {
            expect(findCreateValueStreamOption().attributes('href')).toBe(undefined);
          });

          it('binds modal directive to create option', () => {
            const binding = getBinding(findCreateValueStreamOption().element, 'gl-modal-directive');

            expect(binding.value).toBe('value-stream-form-modal');
          });

          it('renders edit button without a link', () => {
            expect(findEditValueStreamButton().attributes('href')).toBe(undefined);
          });

          it('binds modal directive to edit button', () => {
            const binding = getBinding(findEditValueStreamButton().element, 'gl-modal-directive');

            expect(binding.value).toBe('value-stream-form-modal');
          });
        });
      });

      describe('with canEdit=false', () => {
        beforeEach(() => {
          wrapper = createComponent({
            mountFn: mountExtended,
            initialState: {
              valueStreams,
              selectedValueStream: {
                ...selectedValueStream,
                isCustom: true,
              },
            },
            props: {
              canEdit: false,
            },
          });
        });
        it('does not render a create option for custom value streams', () => {
          expect(findCreateValueStreamOption().exists()).toBe(false);
        });

        it('does not render a delete option for custom value streams', () => {
          expect(findDeleteValueStreamButton().exists()).toBe(false);
        });

        it('does not render an edit button for custom value streams', () => {
          expect(findEditValueStreamButton().exists()).toBe(false);
        });
      });
    });

    describe('with a default value stream', () => {
      beforeEach(() => {
        wrapper = createComponent({ initialState: { valueStreams, selectedValueStream } });
      });

      it('does not render a delete option for default value streams', () => {
        expect(findDeleteValueStreamButton().exists()).toBe(false);
      });

      it('does not render an edit button for default value streams', () => {
        expect(findEditValueStreamButton().exists()).toBe(false);
      });
    });
  });

  describe('Only the default value stream available', () => {
    beforeEach(() => {
      wrapper = createComponent({
        initialState: {
          valueStreams: [{ id: 'default', name: 'default' }],
        },
      });
    });

    it('does not display the create value stream button', () => {
      expect(findCreateValueStreamButton().exists()).toBe(false);
    });

    it('displays the select value stream dropdown', () => {
      expect(findSelectValueStreamDropdown().exists()).toBe(true);
    });

    it('does not render an edit button for default value streams', () => {
      expect(findEditValueStreamButton().exists()).toBe(false);
    });
  });

  describe('No value streams available', () => {
    beforeEach(() => {
      wrapper = createComponent({
        initialState: {
          valueStreams: [],
        },
      });
    });

    it('displays the create value stream button', () => {
      expect(findCreateValueStreamButton().exists()).toBe(true);
      expect(findCreateValueStreamButton().attributes('href')).toBe(newValueStreamPath);
    });

    it('does not bind modal directive to create value stream button', () => {
      const binding = getBinding(findCreateValueStreamButton().element, 'gl-modal-directive');

      expect(binding.value).toBe(false);
    });

    it('does not display the select value stream dropdown', () => {
      expect(findSelectValueStreamDropdown().exists()).toBe(false);
    });

    it('does not render an edit button for default value streams', () => {
      expect(findEditValueStreamButton().exists()).toBe(false);
    });

    describe('vsaStandaloneSettingsPage = false', () => {
      beforeEach(() => {
        wrapper = createComponent({
          initialState: {
            valueStreams: [],
          },
          provide: { glFeatures: { vsaStandaloneSettingsPage: false } },
        });
      });

      it('renders create value stream button without a link', () => {
        expect(findCreateValueStreamButton().attributes('href')).toBe(undefined);
      });

      it('binds modal directive to create value stream button', () => {
        const binding = getBinding(findCreateValueStreamButton().element, 'gl-modal-directive');

        expect(binding.value).toBe('value-stream-form-modal');
      });
    });
  });

  describe('Delete value stream modal', () => {
    describe('succeeds', () => {
      beforeEach(() => {
        wrapper = createComponent({
          initialState: {
            valueStreams,
            selectedValueStream: {
              ...selectedValueStream,
              isCustom: true,
            },
          },
        });

        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);

        submitModal('delete');
      });

      it('calls the "deleteValueStream" event when submitted', () => {
        expect(deleteValueStreamMock).toHaveBeenCalledWith(
          expect.any(Object),
          selectedValueStream.id,
        );
      });

      it('displays a toast message', () => {
        expect(mockToastShow).toHaveBeenCalledWith(
          `'${selectedValueStream.name}' Value Stream deleted`,
        );
      });

      it('sends tracking information', () => {
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'delete_value_stream', {
          extra: { name: selectedValueStream.name },
        });
      });
    });

    describe('fails', () => {
      beforeEach(() => {
        wrapper = createComponent({
          data: { name: streamName },
          initialState: { deleteValueStreamError },
        });
      });

      it('does not display a toast message', () => {
        expect(mockToastShow).not.toHaveBeenCalled();
      });
    });
  });
});
