import { GlFormInput, GlModal, GlAlert } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import DeleteModal from '~/projects/components/shared/delete_modal.vue';
import { __, sprintf } from '~/locale';
import { stubComponent } from 'helpers/stub_component';

jest.mock('lodash/uniqueId', () => () => 'fake-id');

describe('DeleteModal', () => {
  let wrapper;

  const defaultPropsData = {
    visible: false,
    confirmPhrase: 'foo',
    isFork: false,
    issuesCount: 1,
    mergeRequestsCount: 2,
    forksCount: 3,
    starsCount: 4,
  };

  const createComponent = (propsData) => {
    wrapper = mountExtended(DeleteModal, {
      propsData: {
        ...defaultPropsData,
        ...propsData,
      },
      stubs: {
        GlModal: stubComponent(GlModal),
      },
      scopedSlots: {
        'modal-footer': '<div data-testid="modal-footer-slot"></div>',
      },
    });
  };

  const findGlModal = () => wrapper.findComponent(GlModal);
  const alertText = () => wrapper.findComponent(GlAlert).text();
  const findFormInput = () => wrapper.findComponent(GlFormInput);

  it('renders modal with correct props', () => {
    createComponent();

    expect(findGlModal().props()).toMatchObject({
      visible: defaultPropsData.visible,
      modalId: 'fake-id',
      actionPrimary: {
        text: __('Yes, delete project'),
        attributes: {
          variant: 'danger',
          disabled: true,
          'data-qa-selector': 'confirm_delete_button',
        },
      },
      actionCancel: {
        text: __('Cancel, keep project'),
      },
    });
  });

  describe('when resource counts are set', () => {
    it('displays resource counts', () => {
      createComponent();

      expect(alertText()).toContain(`${defaultPropsData.issuesCount} issue`);
      expect(alertText()).toContain(`${defaultPropsData.mergeRequestsCount} merge requests`);
      expect(alertText()).toContain(`${defaultPropsData.forksCount} forks`);
      expect(alertText()).toContain(`${defaultPropsData.starsCount} stars`);
    });
  });

  describe('when resource counts are not set', () => {
    it('does not display resource counts', () => {
      createComponent({
        issuesCount: null,
        mergeRequestsCount: null,
        forksCount: null,
        starsCount: null,
      });

      expect(alertText()).not.toContain('issue');
      expect(alertText()).not.toContain('merge requests');
      expect(alertText()).not.toContain('forks');
      expect(alertText()).not.toContain('stars');
    });
  });

  describe('when project is a fork', () => {
    beforeEach(() => {
      createComponent({
        isFork: true,
      });
    });

    it('displays correct alert title', () => {
      expect(alertText()).toContain(DeleteModal.i18n.isForkAlertTitle);
    });

    it('displays correct alert body', () => {
      expect(alertText()).toContain(DeleteModal.i18n.isForkAlertBody);
    });
  });

  describe('when project is not a fork', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays correct alert title', () => {
      expect(alertText()).toContain(
        sprintf(DeleteModal.i18n.isNotForkAlertTitle, { strongStart: '', strongEnd: '' }),
      );
    });

    it('displays correct alert body', () => {
      expect(alertText()).toContain(
        sprintf(DeleteModal.i18n.isNotForkAlertBody, { strongStart: '', strongEnd: '' }),
      );
    });
  });

  describe('when correct confirm phrase is used', () => {
    beforeEach(() => {
      createComponent();

      findFormInput().vm.$emit('input', defaultPropsData.confirmPhrase);
    });

    it('enables the primary action', () => {
      expect(findGlModal().props('actionPrimary').attributes.disabled).toBe(false);
    });
  });

  describe('when correct confirm phrase is not used', () => {
    beforeEach(() => {
      createComponent();

      findFormInput().vm.$emit('input', 'bar');
    });

    it('keeps the primary action disabled', () => {
      expect(findGlModal().props('actionPrimary').attributes.disabled).toBe(true);
    });
  });

  it('emits `primary` event', () => {
    createComponent();

    findGlModal().vm.$emit('primary');

    expect(wrapper.emitted('primary')).toEqual([[]]);
  });

  it('emits `change` event', () => {
    createComponent();

    findGlModal().vm.$emit('change', true);

    expect(wrapper.emitted('change')).toEqual([[true]]);
  });

  it('renders `modal-footer` slot', () => {
    createComponent();

    expect(wrapper.findByTestId('modal-footer-slot').exists()).toBe(true);
  });
});
