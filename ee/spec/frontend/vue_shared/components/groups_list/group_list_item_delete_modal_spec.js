import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import GroupListItemDeleteModal from 'ee/vue_shared/components/groups_list/group_list_item_delete_modal.vue';
import GroupListItemDeletionDisabledModal from 'ee/vue_shared/components/groups_list/group_list_item_deletion_disabled_modal.vue';
import GroupListItemDelayedDeletionModalFooter from 'ee/vue_shared/components/groups_list/group_list_item_delayed_deletion_modal_footer.vue';
import DangerConfirmModal from '~/vue_shared/components/confirm_danger/confirm_danger_modal.vue';
import { groups } from 'jest/vue_shared/components/groups_list/mock_data';

describe('GroupListItemDeleteModalEE', () => {
  let wrapper;

  const [group] = groups;

  const MOCK_PERM_DELETION_DATE = '2024-03-31';

  const DELETE_MODAL_BODY_OVERRIDE = `This group is scheduled to be deleted on ${MOCK_PERM_DELETION_DATE}. You are about to delete this group, including its subgroups and projects, immediately. This action cannot be undone.`;
  const DELETE_MODAL_TITLE_OVERRIDE = 'Delete group immediately?';
  const DEFAULT_DELETE_MODAL_TITLE = 'Are you absolutely sure?';

  const defaultProps = {
    modalId: '123',
    phrase: 'mock phrase',
    group,
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(GroupListItemDeleteModal, {
      propsData: { ...defaultProps, ...props },
      stubs: {
        GlSprintf,
        DangerConfirmModal: stubComponent(DangerConfirmModal, {
          template: '<div><slot name="modal-body"></slot><slot name="modal-footer"></slot></div>',
        }),
      },
    });
  };

  const findDeletionDisabledModal = () => wrapper.findComponent(GroupListItemDeletionDisabledModal);
  const findDangerConfirmModal = () => wrapper.findComponent(DangerConfirmModal);
  const findDelayedDeletionModalFooter = () =>
    wrapper.findComponent(GroupListItemDelayedDeletionModalFooter);

  describe('when visible is false', () => {
    beforeEach(() => {
      createComponent({ props: { visible: false } });
    });

    it('does not render either modal', () => {
      expect(findDeletionDisabledModal().exists()).toBe(false);
      expect(findDangerConfirmModal().exists()).toBe(false);
      expect(findDelayedDeletionModalFooter().exists()).toBe(false);
    });
  });

  describe('when visible is true', () => {
    describe.each`
      isAdjournedDeletionEnabled | markedForDeletionOn | parent       | renderDeletionModal | renderDisabledDeletionModal
      ${false}                   | ${false}            | ${null}      | ${false}            | ${true}
      ${false}                   | ${false}            | ${{ id: 1 }} | ${true}             | ${false}
      ${false}                   | ${'2024-03-24'}     | ${null}      | ${false}            | ${true}
      ${false}                   | ${'2024-03-24'}     | ${{ id: 1 }} | ${true}             | ${false}
      ${true}                    | ${false}            | ${null}      | ${true}             | ${false}
      ${true}                    | ${false}            | ${{ id: 1 }} | ${true}             | ${false}
      ${true}                    | ${'2024-03-24'}     | ${null}      | ${false}            | ${true}
      ${true}                    | ${'2024-03-24'}     | ${{ id: 1 }} | ${true}             | ${false}
    `(
      'when group isAdjournedDeletionEnabled is $isAdjournedDeletionEnabled, markedForDeletionOn is $markedForDeletionOn, and parent is $parent',
      ({
        isAdjournedDeletionEnabled,
        markedForDeletionOn,
        parent,
        renderDeletionModal,
        renderDisabledDeletionModal,
      }) => {
        beforeEach(() => {
          createComponent({
            props: {
              visible: true,
              group: {
                ...group,
                isAdjournedDeletionEnabled,
                markedForDeletionOn,
                parent,
              },
            },
          });
        });

        it(`${renderDeletionModal ? 'does' : 'does not'} render deletion modal`, () => {
          expect(findDangerConfirmModal().exists()).toBe(renderDeletionModal);
          expect(findDelayedDeletionModalFooter().exists()).toBe(renderDeletionModal);
        });

        it(`${
          renderDisabledDeletionModal ? 'does' : 'does not'
        } render disabled deletion modal`, () => {
          expect(findDeletionDisabledModal().exists()).toBe(renderDisabledDeletionModal);
        });
      },
    );
  });

  describe('delete modal overrides', () => {
    describe.each`
      isAdjournedDeletionEnabled | markedForDeletionOn | modalTitle                     | modalBody
      ${false}                   | ${false}            | ${DELETE_MODAL_TITLE_OVERRIDE} | ${DELETE_MODAL_BODY_OVERRIDE}
      ${true}                    | ${false}            | ${DEFAULT_DELETE_MODAL_TITLE}  | ${''}
      ${false}                   | ${'2024-03-24'}     | ${DELETE_MODAL_TITLE_OVERRIDE} | ${DELETE_MODAL_BODY_OVERRIDE}
      ${true}                    | ${'2024-03-24'}     | ${DELETE_MODAL_TITLE_OVERRIDE} | ${DELETE_MODAL_BODY_OVERRIDE}
    `(
      'when group isAdjournedDeletionEnabled is $isAdjournedDeletionEnabled and markedForDeletionOn is $markedForDeletionOn',
      ({ isAdjournedDeletionEnabled, markedForDeletionOn, modalTitle, modalBody }) => {
        beforeEach(() => {
          createComponent({
            props: {
              visible: true,
              group: {
                ...group,
                parent: { id: 1 },
                permanentDeletionDate: MOCK_PERM_DELETION_DATE,
                isAdjournedDeletionEnabled,
                markedForDeletionOn,
              },
            },
          });
        });

        it(`${
          modalTitle === DELETE_MODAL_TITLE_OVERRIDE ? 'does' : 'does not'
        } override deletion modal title`, () => {
          expect(findDangerConfirmModal().props('modalTitle')).toBe(modalTitle);
        });

        it(`${modalBody ? 'does' : 'does not'} override deletion modal body`, () => {
          expect(findDangerConfirmModal().text()).toBe(modalBody);
        });
      },
    );
  });

  describe('events', () => {
    describe('deletion modal events', () => {
      beforeEach(() => {
        createComponent({
          props: {
            visible: true,
            group: {
              ...group,
              parent: { id: 1 },
            },
          },
        });
      });

      describe('when confirm is emitted', () => {
        beforeEach(() => {
          findDangerConfirmModal().vm.$emit('confirm', {
            preventDefault: jest.fn(),
          });
        });

        it('emits `confirm` event to parent', () => {
          expect(wrapper.emitted('confirm')).toHaveLength(1);
        });
      });

      describe('when change is emitted', () => {
        beforeEach(() => {
          findDangerConfirmModal().vm.$emit('change', false);
        });

        it('emits `change` event to parent', () => {
          expect(wrapper.emitted('change')).toMatchObject([[false]]);
        });
      });
    });

    describe('deletion disabled modal events', () => {
      beforeEach(() => {
        createComponent({
          props: {
            visible: true,
            group: {
              ...group,
              parent: null,
            },
          },
        });
      });

      describe('when change is emitted', () => {
        beforeEach(() => {
          findDeletionDisabledModal().vm.$emit('change', false);
        });

        it('emits `change` event to parent', () => {
          expect(wrapper.emitted('change')).toMatchObject([[false]]);
        });
      });
    });
  });
});
