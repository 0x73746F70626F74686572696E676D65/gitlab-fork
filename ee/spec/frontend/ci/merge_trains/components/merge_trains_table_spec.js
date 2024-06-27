import { GlTable, GlLink, GlKeysetPagination } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import MergeTrainsTable from 'ee/ci/merge_trains/components/merge_trains_table.vue';
import CiIcon from '~/vue_shared/components/ci_icon/ci_icon.vue';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import { DEFAULT_CURSOR } from 'ee/ci/merge_trains/constants';
import { activeTrain, trainWithPagination } from '../mock_data';

describe('MergeTrainsTable', () => {
  let wrapper;

  const defaultProps = {
    train: activeTrain.data.project.mergeTrains.nodes[0],
    cursor: DEFAULT_CURSOR,
  };

  const car = defaultProps.train.cars.nodes[0];

  const createComponent = (props = defaultProps) => {
    wrapper = mountExtended(MergeTrainsTable, {
      propsData: {
        ...props,
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findCiStatus = () => wrapper.findComponent(CiIcon);
  const findMrLink = () => wrapper.findComponent(GlLink);
  const findUserAvatar = () => wrapper.findComponent(UserAvatarLink);
  const findKeysetPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findAddedToTrainText = () => wrapper.findByTestId('added-to-train-text');

  describe('defaults', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays table', () => {
      expect(findTable().exists()).toBe(true);
    });

    it('displays CI status', () => {
      const { detailedStatus } = car.pipeline;

      expect(findCiStatus().props('status')).toEqual(detailedStatus);
    });

    it('displays merge request', () => {
      const { webPath, title } = car.mergeRequest;

      expect(findMrLink().attributes('href')).toBe(webPath);
      expect(findMrLink().text()).toBe(title);
    });

    it('displays added to train text', () => {
      expect(findAddedToTrainText().exists()).toBe(true);
    });

    it('displays user avatar', () => {
      const { avatarUrl, webPath, name } = car.user;

      expect(findUserAvatar().props()).toMatchObject({
        linkHref: webPath,
        imgSrc: avatarUrl,
        imgAlt: name,
        tooltipText: name,
        imgSize: 16,
      });
    });

    it('does not display pagination', () => {
      expect(findKeysetPagination().exists()).toBe(false);
    });
  });

  describe('pagination', () => {
    beforeEach(() => {
      createComponent({
        train: trainWithPagination.data.project.mergeTrains.nodes[0],
        cursor: DEFAULT_CURSOR,
      });
    });

    it('keyset pagination component contains pageInfo props', () => {
      const { pageInfo } = trainWithPagination.data.project.mergeTrains.nodes[0].cars;

      expect(findKeysetPagination().props()).toMatchObject(pageInfo);
    });

    it('displays pagination', () => {
      expect(findKeysetPagination().exists()).toBe(true);
    });

    it('emits pageChange event with prev cursor data', () => {
      const expectedBefore = 'eyJpZCI6IjUzIn0';

      findKeysetPagination().vm.$emit('prev', expectedBefore);

      expect(wrapper.emitted('pageChange')).toEqual([
        [{ after: null, before: expectedBefore, first: null, last: 20 }],
      ]);
    });

    it('emits pageChange event with next cursor data', () => {
      const expectedAfter = 'eyHpKCL6IjBzIn0';

      findKeysetPagination().vm.$emit('next', expectedAfter);

      expect(wrapper.emitted('pageChange')).toEqual([
        [{ after: expectedAfter, before: null, first: 20, last: null }],
      ]);
    });
  });
});
