import { GlTable, GlLink } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import MergeTrainsTable from 'ee/ci/merge_trains/components/merge_trains_table.vue';
import CiIcon from '~/vue_shared/components/ci_icon/ci_icon.vue';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import { activeTrain } from '../mock_data';

describe('MergeTrainsTable', () => {
  let wrapper;

  const defaultProps = {
    train: activeTrain.data.project.mergeTrains.nodes[0],
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
  const findAddedToTrainText = () => wrapper.findByTestId('added-to-train-text');

  beforeEach(() => {
    createComponent();
  });

  it('renders table', () => {
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
});
