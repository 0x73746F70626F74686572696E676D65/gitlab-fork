import { mount } from '@vue/test-utils';
import { GlBroadcastMessage, GlForm } from '@gitlab/ui';
import AxiosMockAdapter from 'axios-mock-adapter';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_BAD_REQUEST } from '~/lib/utils/http_status';
import MessageForm from '~/admin/broadcast_messages/components/message_form.vue';
import {
  TYPE_BANNER,
  TYPE_NOTIFICATION,
  THEMES,
  TARGET_OPTIONS,
} from '~/admin/broadcast_messages/constants';
import waitForPromises from 'helpers/wait_for_promises';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { MOCK_TARGET_ACCESS_LEVELS } from '../mock_data';

jest.mock('~/alert');

describe('MessageForm', () => {
  let wrapper;
  let axiosMock;

  const defaultProps = {
    message: 'zzzzzzz',
    broadcastType: TYPE_BANNER,
    theme: THEMES[0].value,
    dismissable: false,
    targetPath: '',
    targetAccessLevels: [],
    startsAt: new Date(),
    endsAt: new Date(),
  };

  const messagesPath = '_messages_path_';

  const findPreview = () => extendedWrapper(wrapper.findComponent(GlBroadcastMessage));
  const findThemeSelect = () => wrapper.findComponent('[data-testid=theme-select]');
  const findDismissable = () => wrapper.findComponent('[data-testid=dismissable-checkbox]');
  const findTargetRoles = () => wrapper.findComponent('[data-testid=target-roles-checkboxes]');
  const findSubmitButton = () => wrapper.findComponent('[data-testid=submit-button]');
  const findCancelButton = () => wrapper.findComponent('[data-testid=cancel-button]');
  const findForm = () => wrapper.findComponent(GlForm);
  const findShowInCli = () => wrapper.findComponent('[data-testid=show-in-cli-checkbox]');
  const findTargetSelect = () => wrapper.findComponent('[data-testid=target-select]');
  const findTargetPath = () => wrapper.findComponent('[data-testid=target-path-input]');

  function createComponent({ broadcastMessage = {} } = {}) {
    wrapper = mount(MessageForm, {
      provide: {
        targetAccessLevelOptions: MOCK_TARGET_ACCESS_LEVELS,
        messagesPath,
        previewPath: '_preview_path_',
      },
      propsData: {
        broadcastMessage: {
          ...defaultProps,
          ...broadcastMessage,
        },
      },
    });
  }

  beforeEach(() => {
    axiosMock = new AxiosMockAdapter(axios);
  });

  afterEach(() => {
    axiosMock.restore();
    createAlert.mockClear();
  });

  describe('the message preview', () => {
    it('renders the preview with the user selected theme', () => {
      const theme = 'blue';
      createComponent({ broadcastMessage: { theme } });
      expect(findPreview().props().theme).toEqual(theme);
    });

    it('renders the placeholder text when the user message is blank', () => {
      createComponent({ broadcastMessage: { message: '  ' } });
      expect(wrapper.text()).toContain(wrapper.vm.$options.i18n.messagePlaceholder);
    });
  });

  describe('theme select dropdown', () => {
    it('renders for Banners', () => {
      createComponent({ broadcastMessage: { broadcastType: TYPE_BANNER } });
      expect(findThemeSelect().exists()).toBe(true);
    });

    it('does not render for Notifications', () => {
      createComponent({ broadcastMessage: { broadcastType: TYPE_NOTIFICATION } });
      expect(findThemeSelect().exists()).toBe(false);
    });
  });

  describe('dismissable checkbox', () => {
    it('renders for Banners', () => {
      createComponent({ broadcastMessage: { broadcastType: TYPE_BANNER } });
      expect(findDismissable().exists()).toBe(true);
    });

    it('does not render for Notifications', () => {
      createComponent({ broadcastMessage: { broadcastType: TYPE_NOTIFICATION } });
      expect(findDismissable().exists()).toBe(false);
    });
  });

  describe('showInCli checkbox', () => {
    it('renders for Banners', () => {
      createComponent({ broadcastMessage: { broadcastType: TYPE_BANNER } });
      expect(findShowInCli().exists()).toBe(true);
    });

    it('does not render for Notifications', () => {
      createComponent({ broadcastMessage: { broadcastType: TYPE_NOTIFICATION } });
      expect(findShowInCli().exists()).toBe(false);
    });
  });

  describe('target select', () => {
    it('renders the first option and hide target path and target roles when creating message', () => {
      createComponent();
      expect(findTargetSelect().element.value).toBe(TARGET_OPTIONS[0].value);
      expect(findTargetRoles().isVisible()).toBe(false);
      expect(findTargetPath().isVisible()).toBe(false);
    });

    it('triggers displaying target path and target roles when selecting different options', async () => {
      createComponent();
      const options = findTargetSelect().findAll('option');
      await options.at(1).setSelected();
      expect(findTargetPath().isVisible()).toBe(true);
      expect(findTargetRoles().isVisible()).toBe(false);

      await options.at(2).setSelected();
      expect(findTargetPath().isVisible()).toBe(true);
      expect(findTargetRoles().isVisible()).toBe(true);
    });

    it('renders the second option and hide target roles when editing message with path specified', () => {
      createComponent({ broadcastMessage: { targetPath: '/welcome' } });
      expect(findTargetSelect().element.value).toBe(TARGET_OPTIONS[1].value);
      expect(findTargetRoles().isVisible()).toBe(false);
      expect(findTargetPath().isVisible()).toBe(true);
    });

    it('renders the third option when editing message with path and roles specified', () => {
      createComponent({ broadcastMessage: { targetPath: '/welcome', targetAccessLevels: [20] } });
      expect(findTargetSelect().element.value).toBe(TARGET_OPTIONS[2].value);
      expect(findTargetRoles().isVisible()).toBe(true);
      expect(findTargetPath().isVisible()).toBe(true);
    });
  });

  describe('form submit button', () => {
    it('renders the "add" text when the message is not persisted', () => {
      createComponent({ broadcastMessage: { id: undefined } });
      expect(wrapper.text()).toContain(wrapper.vm.$options.i18n.add);
    });

    it('renders the "update" text when the message is persisted', () => {
      createComponent({ broadcastMessage: { id: 100 } });
      expect(wrapper.text()).toContain(wrapper.vm.$options.i18n.update);
    });

    it('is disabled when the user message is blank', () => {
      createComponent({ broadcastMessage: { message: '  ' } });
      expect(findSubmitButton().props().disabled).toBe(true);
    });

    it('is not disabled when the user message is present', () => {
      createComponent({ broadcastMessage: { message: 'alsdjfkldsj' } });
      expect(findSubmitButton().props().disabled).toBe(false);
    });
  });

  describe('form cancel button', () => {
    it('renders when the editing a message and has href back to message index page', () => {
      createComponent({ broadcastMessage: { id: 100 } });
      expect(wrapper.text()).toContain('Cancel');
      expect(findCancelButton().attributes('href')).toBe(wrapper.vm.messagesPath);
    });
  });

  describe('form submission', () => {
    const defaultPayload = {
      message: defaultProps.message,
      broadcast_type: defaultProps.broadcastType,
      theme: defaultProps.theme,
      dismissable: defaultProps.dismissable,
      target_path: defaultProps.targetPath,
      target_access_levels: defaultProps.targetAccessLevels,
      starts_at: defaultProps.startsAt,
      ends_at: defaultProps.endsAt,
    };

    it('sends a create request for a new message form', async () => {
      createComponent({ broadcastMessage: { id: undefined } });
      findForm().vm.$emit('submit', { preventDefault: () => {} });
      await waitForPromises();

      expect(axiosMock.history.post).toHaveLength(2);
      expect(axiosMock.history.post[1]).toMatchObject({
        url: messagesPath,
        data: JSON.stringify(defaultPayload),
      });
    });

    it('shows an error alert if the create request fails', async () => {
      createComponent({ broadcastMessage: { id: undefined } });
      axiosMock.onPost(messagesPath).replyOnce(HTTP_STATUS_BAD_REQUEST);
      findForm().vm.$emit('submit', { preventDefault: () => {} });
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: wrapper.vm.$options.i18n.addError,
        }),
      );
    });

    it('sends an update request for a persisted message form', async () => {
      const id = 1337;
      createComponent({ broadcastMessage: { id } });
      findForm().vm.$emit('submit', { preventDefault: () => {} });
      await waitForPromises();

      expect(axiosMock.history.patch).toHaveLength(1);
      expect(axiosMock.history.patch[0]).toMatchObject({
        url: `${messagesPath}/${id}`,
        data: JSON.stringify(defaultPayload),
      });
    });

    it('shows an error alert if the update request fails', async () => {
      const id = 1337;
      createComponent({ broadcastMessage: { id } });
      axiosMock.onPost(`${messagesPath}/${id}`).replyOnce(HTTP_STATUS_BAD_REQUEST);
      findForm().vm.$emit('submit', { preventDefault: () => {} });
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: wrapper.vm.$options.i18n.updateError,
        }),
      );
    });
  });
});
