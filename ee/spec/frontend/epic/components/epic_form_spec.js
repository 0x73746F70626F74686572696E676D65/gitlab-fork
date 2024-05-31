import { GlForm, GlFormCheckbox, GlFormInput } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import EpicForm from 'ee/epic/components/epic_form.vue';
import createEpic from 'ee/epic/queries/create_epic.mutation.graphql';
import { TEST_HOST } from 'helpers/test_constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import Autosave from '~/autosave';
import { visitUrl } from '~/lib/utils/url_utility';
import LabelsSelectWidget from '~/sidebar/components/labels/labels_select_widget/labels_select_root.vue';
import ColorSelectDropdown from '~/vue_shared/components/color_select_dropdown/color_select_root.vue';
import MarkdownEditor from '~/vue_shared/components/markdown/markdown_editor.vue';
import { CLEAR_AUTOSAVE_ENTRY_EVENT } from '~/vue_shared/constants';
import markdownEditorEventHub from '~/vue_shared/components/markdown/eventhub';
import { mockTracking } from 'helpers/tracking_helper';

jest.mock('~/lib/utils/url_utility', () => ({
  visitUrl: jest.fn(),
}));
jest.mock('~/autosave');

const TEST_GROUP_PATH = 'gitlab-org';
const TEST_NEW_EPIC = {
  data: { createEpic: { epic: { id: '1', webUrl: TEST_HOST }, errors: [] } },
};

describe('ee/epic/components/epic_form.vue', () => {
  let wrapper;
  let trackingSpy;
  let requestHandler;

  const createMutationResponse = (result = TEST_NEW_EPIC) => jest.fn().mockResolvedValue(result);

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    requestHandler = handler;

    return createMockApollo([[createEpic, handler]]);
  };

  const createWrapper = ({ handler = createMutationResponse() } = {}) => {
    wrapper = shallowMountExtended(EpicForm, {
      apolloProvider: createMockApolloProvider(handler),
      provide: {
        iid: '1',
        groupPath: TEST_GROUP_PATH,
        groupEpicsPath: TEST_HOST,
        labelsManagePath: TEST_HOST,
        markdownPreviewPath: TEST_HOST,
        markdownDocsPath: TEST_HOST,
      },
    });
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findLabels = () => wrapper.findComponent(LabelsSelectWidget);
  const findColor = () => wrapper.findComponent(ColorSelectDropdown);
  const findTitle = () => wrapper.findComponent(GlFormInput);
  const findDescription = () => wrapper.findComponent(MarkdownEditor);
  const findConfidentialityCheck = () => wrapper.findComponent(GlFormCheckbox);
  const findStartDate = () => wrapper.findByTestId('epic-start-date');
  const findStartDateReset = () => wrapper.findByTestId('clear-start-date');
  const findDueDate = () => wrapper.findByTestId('epic-due-date');
  const findDueDateReset = () => wrapper.findByTestId('clear-due-date');
  const findSaveButton = () => wrapper.findByTestId('create-epic-button');
  const findCancelButton = () => wrapper.findByTestId('cancel-epic');

  beforeEach(() => {
    trackingSpy = mockTracking(undefined, null, jest.spyOn);
  });

  describe('when mounted', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should render the form', () => {
      expect(findForm().exists()).toBe(true);
    });

    it('initializes autosave support on title field', () => {
      expect(Autosave.mock.calls).toEqual([[expect.any(Element), ['/', '', 'title']]]);
    });

    it('can be canceled', () => {
      expect(findCancelButton().attributes('href')).toBe(TEST_HOST);
    });

    it('disables submit button if no title is provided', () => {
      expect(findSaveButton().attributes('disabled')).toBeDefined();
    });

    it.each`
      findInput        | findResetter
      ${findStartDate} | ${findStartDateReset}
      ${findDueDate}   | ${findDueDateReset}
    `('can reset date selectors side control', async ({ findInput, findResetter }) => {
      await findInput().vm.$emit('input', new Date());

      expect(findInput().props('value')).not.toBeNull();

      await findResetter().vm.$emit('click');

      expect(findInput().props('value')).toBeNull();
    });
  });

  describe('save', () => {
    const addLabelIds = [1];
    const title = 'Status page MVP';
    const description = '### Goal\n\n- [ ] Item';
    const confidential = true;

    it.each`
      startDateFixed  | dueDateFixed    | startDateIsFixed | dueDateIsFixed
      ${null}         | ${null}         | ${false}         | ${false}
      ${'2021-07-01'} | ${null}         | ${true}          | ${false}
      ${null}         | ${'2021-07-02'} | ${false}         | ${true}
      ${'2021-07-01'} | ${'2021-07-02'} | ${true}          | ${true}
    `(
      'requests mutation with correct data with all start and due date configurations',
      async ({ startDateFixed, dueDateFixed, startDateIsFixed, dueDateIsFixed }) => {
        const epicColor = {
          color: '#217645',
          title: 'Green',
        };

        createWrapper();

        findTitle().vm.$emit('input', title);
        findDescription().vm.$emit('input', description);
        findConfidentialityCheck().vm.$emit('input', confidential);
        findLabels().vm.$emit('updateSelectedLabels', {
          labels: [{ id: 'gid://gitlab/GroupLabel/1' }],
        });
        findColor().vm.$emit('updateSelectedColor', { color: epicColor });

        // Make sure the submitted values for start and due dates are date strings without timezone info.
        // (Datepicker emits a Date object but the submitted value must be a date string).
        findStartDate().vm.$emit('input', startDateFixed ? new Date(startDateFixed) : null);
        findDueDate().vm.$emit('input', dueDateFixed ? new Date(dueDateFixed) : null);

        findForm().vm.$emit('submit', { preventDefault: () => {} });

        expect(requestHandler).toHaveBeenCalledWith({
          input: {
            groupPath: TEST_GROUP_PATH,
            addLabelIds,
            title,
            description,
            confidential,
            startDateFixed,
            startDateIsFixed,
            dueDateFixed,
            dueDateIsFixed,
            color: epicColor.color,
          },
        });

        await waitForPromises();

        expect(visitUrl).toHaveBeenCalled();
      },
    );

    it('resets loading indicator when request is successful', async () => {
      createWrapper({ handler: createMutationResponse(TEST_NEW_EPIC) });

      findForm().vm.$emit('submit', { preventDefault: () => {} });
      await waitForPromises();

      expect(findSaveButton().props('loading')).toBe(true);
    });

    it('resets does not reset loading indicator when request fails', async () => {
      createWrapper({ handler: jest.fn().mockRejectedValue({}) });

      findForm().vm.$emit('submit', { preventDefault: () => {} });
      await waitForPromises();

      expect(findSaveButton().props('loading')).toBe(false);
    });

    it('tracks event on submit', () => {
      createWrapper();

      findForm().vm.$emit('submit', { preventDefault: () => {} });

      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'save_markdown', {
        label: 'markdown_editor',
        property: 'Epic',
      });
    });

    it('resets automatically saved title and description when request succeeds', async () => {
      setWindowLocation('/my-group/epics/new?q=my-query');
      createWrapper();
      jest.spyOn(Autosave.prototype, 'reset');
      jest.spyOn(markdownEditorEventHub, '$emit');

      findTitle().vm.$emit('input', title);
      findDescription().vm.$emit('input', description);

      findForm().vm.$emit('submit', { preventDefault: () => {} });

      await waitForPromises();

      expect(Autosave.prototype.reset).toHaveBeenCalledTimes(1);
      expect(markdownEditorEventHub.$emit).toHaveBeenCalledWith(
        CLEAR_AUTOSAVE_ENTRY_EVENT,
        '/my-group/epics/new/?q=my-query/description',
      );
    });
  });
});
