import { GlModal, GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GroupListItemDeletionDisabledModal from 'ee/vue_shared/components/groups_list/group_list_item_deletion_disabled_modal.vue';
import { groups } from 'jest/vue_shared/components/groups_list/mock_data';

describe('GroupListItemDeletionDisabledModal', () => {
  let wrapper;

  const [group] = groups;

  const DEFAULT_BODY_TEXT = `${group.fullName} is a top level group and cannot be immediately deleted from here.  Please visit the Group Settings to immediately delete this group.`;

  const defaultProps = {
    modalId: '123',
    group: {
      ...group,
      name: group.fullName,
    },
  };

  const createComponent = ({ props = {}, slots = {} } = {}) => {
    wrapper = shallowMountExtended(GroupListItemDeletionDisabledModal, {
      propsData: { ...defaultProps, ...props },
      slots,
      stubs: {
        GlSprintf,
      },
    });
  };

  const findGlModal = () => wrapper.findComponent(GlModal);
  const findGlLink = () => wrapper.findComponent(GlLink);

  describe('modal body slot', () => {
    describe('when not using slot', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders default content', () => {
        expect(wrapper.text()).toContain(DEFAULT_BODY_TEXT);
        expect(findGlLink().attributes('href')).toBe(group.editPath);
      });
    });

    describe('when using slot', () => {
      const MOCK_BODY = 'New Body';

      beforeEach(() => {
        createComponent({
          slots: {
            'modal-body': `<span>${MOCK_BODY}</span>`,
          },
        });
      });

      it('does not render default content', () => {
        expect(wrapper.text()).not.toContain(DEFAULT_BODY_TEXT);
        expect(findGlLink().exists()).toBe(false);
      });

      it('renders custom body', () => {
        expect(wrapper.text()).toContain(MOCK_BODY);
      });
    });
  });

  describe('when change is emitted', () => {
    beforeEach(() => {
      createComponent();
      findGlModal().vm.$emit('change', false);
    });

    it('emits `change` event to parent', () => {
      expect(wrapper.emitted('change')).toMatchObject([[false]]);
    });
  });
});
