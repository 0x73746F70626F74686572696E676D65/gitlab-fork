import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import Vuex from 'vuex';
import IssuePlaceholderNote from '~/vue_shared/components/notes/placeholder_note.vue';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import { userDataMock } from 'jest/notes/mock_data';

Vue.use(Vuex);

const getters = {
  getUserData: () => userDataMock,
};

describe('Issue placeholder note component', () => {
  let wrapper;

  const findNote = () => wrapper.find({ ref: 'note' });

  const createComponent = (isIndividual = false, propsData = {}) => {
    wrapper = shallowMount(IssuePlaceholderNote, {
      store: new Vuex.Store({
        getters,
      }),
      propsData: {
        note: {
          body: 'Foo',
          individual_note: isIndividual,
        },
        ...propsData,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  it('matches snapshot', () => {
    createComponent();

    expect(wrapper.element).toMatchSnapshot();
  });

  it('does not add "discussion" class to individual notes', () => {
    createComponent(true);

    expect(findNote().classes()).not.toContain('discussion');
  });

  it('adds "discussion" class to non-individual notes', () => {
    createComponent();

    expect(findNote().classes()).toContain('discussion');
  });

  describe('avatar size', () => {
    it.each`
      size  | line                    | isOverviewTab
      ${40} | ${null}                 | ${false}
      ${24} | ${{ line_code: '123' }} | ${false}
      ${40} | ${{ line_code: '123' }} | ${true}
    `('renders avatar $size for $line and $isOverviewTab', ({ size, line, isOverviewTab }) => {
      createComponent(false, { line, isOverviewTab });

      expect(wrapper.findComponent(UserAvatarLink).props('imgSize')).toBe(size);
    });
  });
});
