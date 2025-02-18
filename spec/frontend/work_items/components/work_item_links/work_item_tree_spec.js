import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlToggle } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import WidgetWrapper from '~/work_items/components/widget_wrapper.vue';
import WorkItemTree from '~/work_items/components/work_item_links/work_item_tree.vue';
import WorkItemChildrenWrapper from '~/work_items/components/work_item_links/work_item_children_wrapper.vue';
import WorkItemLinksForm from '~/work_items/components/work_item_links/work_item_links_form.vue';
import WorkItemActionsSplitButton from '~/work_items/components/work_item_links/work_item_actions_split_button.vue';
import WorkItemTreeActions from '~/work_items/components/work_item_links/work_item_tree_actions.vue';
import {
  FORM_TYPES,
  WORK_ITEM_TYPE_ENUM_OBJECTIVE,
  WORK_ITEM_TYPE_ENUM_KEY_RESULT,
  WORK_ITEM_TYPE_ENUM_EPIC,
  WORK_ITEM_TYPE_ENUM_ISSUE,
  WORK_ITEM_TYPE_VALUE_EPIC,
  WORK_ITEM_TYPE_VALUE_OBJECTIVE,
} from '~/work_items/constants';
import { childrenWorkItems } from '../../mock_data';

Vue.use(VueApollo);

describe('WorkItemTree', () => {
  let wrapper;

  const findEmptyState = () => wrapper.findByTestId('tree-empty');
  const findToggleFormSplitButton = () => wrapper.findComponent(WorkItemActionsSplitButton);
  const findForm = () => wrapper.findComponent(WorkItemLinksForm);
  const findWidgetWrapper = () => wrapper.findComponent(WidgetWrapper);
  const findWorkItemLinkChildrenWrapper = () => wrapper.findComponent(WorkItemChildrenWrapper);
  const findShowLabelsToggle = () => wrapper.findComponent(GlToggle);
  const findTreeActions = () => wrapper.findComponent(WorkItemTreeActions);

  const createComponent = ({
    workItemType = 'Objective',
    workItemIid = '2',
    parentWorkItemType = 'Objective',
    confidential = false,
    children = childrenWorkItems,
    canUpdate = true,
    canUpdateChildren = true,
    hasSubepicsFeature = true,
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemTree, {
      propsData: {
        fullPath: 'test/project',
        workItemType,
        workItemIid,
        parentWorkItemType,
        workItemId: 'gid://gitlab/WorkItem/515',
        confidential,
        children,
        canUpdate,
        canUpdateChildren,
      },
      provide: {
        hasSubepicsFeature,
      },
      stubs: { WidgetWrapper },
    });
  };

  it('displays Add button', () => {
    createComponent();

    expect(findToggleFormSplitButton().exists()).toBe(true);
  });

  it('displays empty state if there are no children', () => {
    createComponent({ children: [] });

    expect(findEmptyState().exists()).toBe(true);
  });

  it('renders hierarchy widget children container', () => {
    createComponent();

    expect(findWorkItemLinkChildrenWrapper().exists()).toBe(true);
    expect(findWorkItemLinkChildrenWrapper().props().children).toHaveLength(4);
  });

  it('does not display form by default', () => {
    createComponent();

    expect(findForm().exists()).toBe(false);
  });

  it('shows an error message on error', async () => {
    const errorMessage = 'Some error';
    createComponent();

    findWorkItemLinkChildrenWrapper().vm.$emit('error', errorMessage);
    await nextTick();

    expect(findWidgetWrapper().props('error')).toBe(errorMessage);
  });

  it.each`
    option                   | formType             | childType
    ${'New objective'}       | ${FORM_TYPES.create} | ${WORK_ITEM_TYPE_ENUM_OBJECTIVE}
    ${'Existing objective'}  | ${FORM_TYPES.add}    | ${WORK_ITEM_TYPE_ENUM_OBJECTIVE}
    ${'New key result'}      | ${FORM_TYPES.create} | ${WORK_ITEM_TYPE_ENUM_KEY_RESULT}
    ${'Existing key result'} | ${FORM_TYPES.add}    | ${WORK_ITEM_TYPE_ENUM_KEY_RESULT}
  `(
    'when triggering action $option, renders the form passing $formType and $childType',
    async ({ formType, childType }) => {
      createComponent();

      wrapper.vm.showAddForm(formType, childType);
      await nextTick();

      expect(findForm().exists()).toBe(true);
      expect(findForm().props()).toMatchObject({
        formType,
        childrenType: childType,
        parentWorkItemType: 'Objective',
        parentConfidential: false,
      });
    },
  );

  describe('when subepics are not available', () => {
    it.each`
      option              | formType             | childType
      ${'New issue'}      | ${FORM_TYPES.create} | ${WORK_ITEM_TYPE_ENUM_ISSUE}
      ${'Existing issue'} | ${FORM_TYPES.add}    | ${WORK_ITEM_TYPE_ENUM_ISSUE}
    `(
      'when triggering action $option, renders the form passing $formType and $childType',
      async ({ formType, childType }) => {
        createComponent({ hasSubepicsFeature: false, workItemType: 'Epic' });

        wrapper.vm.showAddForm(formType, childType);
        await nextTick();

        expect(findForm().exists()).toBe(true);
        expect(findForm().props()).toMatchObject({
          formType,
          childrenType: childType,
        });
      },
    );
  });

  describe('when subepics are available', () => {
    it.each`
      option              | formType             | childType
      ${'New issue'}      | ${FORM_TYPES.create} | ${WORK_ITEM_TYPE_ENUM_ISSUE}
      ${'Existing issue'} | ${FORM_TYPES.add}    | ${WORK_ITEM_TYPE_ENUM_ISSUE}
      ${'New epic'}       | ${FORM_TYPES.create} | ${WORK_ITEM_TYPE_ENUM_EPIC}
      ${'Existing epic'}  | ${FORM_TYPES.add}    | ${WORK_ITEM_TYPE_ENUM_EPIC}
    `(
      'when triggering action $option, renders the form passing $formType and $childType',
      async ({ formType, childType }) => {
        createComponent({ hasSubepicsFeature: true, workItemType: 'Epic' });

        wrapper.vm.showAddForm(formType, childType);
        await nextTick();

        expect(findForm().exists()).toBe(true);
        expect(findForm().props()).toMatchObject({
          formType,
          childrenType: childType,
        });
      },
    );
  });

  describe('when no permission to update', () => {
    beforeEach(() => {
      createComponent({
        canUpdate: false,
        canUpdateChildren: false,
      });
    });

    it('does not display button to toggle Add form', () => {
      expect(findToggleFormSplitButton().exists()).toBe(false);
    });

    it('does not display link menu on children', () => {
      expect(findWorkItemLinkChildrenWrapper().props('canUpdate')).toBe(false);
    });
  });

  it('emits `addChild` event when form emits `addChild` event', async () => {
    createComponent();

    wrapper.vm.showAddForm(FORM_TYPES.create, WORK_ITEM_TYPE_ENUM_OBJECTIVE);
    await nextTick();
    findForm().vm.$emit('addChild');

    expect(wrapper.emitted('addChild')).toEqual([[]]);
  });

  it.each`
    toggleValue
    ${true}
    ${false}
  `(
    'passes showLabels as $toggleValue to child items when toggle is $toggleValue',
    async ({ toggleValue }) => {
      createComponent();

      findShowLabelsToggle().vm.$emit('change', toggleValue);

      await nextTick();

      expect(findWorkItemLinkChildrenWrapper().props('showLabels')).toBe(toggleValue);
    },
  );

  describe('action menu', () => {
    it.each`
      visible  | workItemType
      ${true}  | ${WORK_ITEM_TYPE_VALUE_EPIC}
      ${false} | ${WORK_ITEM_TYPE_VALUE_OBJECTIVE}
    `(
      'When displaying a $workItemType, it is $visible that the action menu is rendered',
      ({ workItemType, visible }) => {
        createComponent({ workItemType });

        expect(findTreeActions().exists()).toBe(visible);
      },
    );
  });
});
