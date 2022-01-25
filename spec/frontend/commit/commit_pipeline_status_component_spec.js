import { GlLoadingIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Visibility from 'visibilityjs';
import { nextTick } from 'vue';
import fixture from 'test_fixtures/pipelines/pipelines.json';
import createFlash from '~/flash';
import Poll from '~/lib/utils/poll';
import CommitPipelineStatus from '~/projects/tree/components/commit_pipeline_status_component.vue';
import CiIcon from '~/vue_shared/components/ci_icon.vue';

jest.mock('~/lib/utils/poll');
jest.mock('visibilityjs');
jest.mock('~/flash');

const mockFetchData = jest.fn();
jest.mock('~/projects/tree/services/commit_pipeline_service', () =>
  jest.fn().mockImplementation(() => ({
    fetchData: mockFetchData.mockReturnValue(Promise.resolve()),
  })),
);

describe('Commit pipeline status component', () => {
  let wrapper;
  const { pipelines } = fixture;
  const { status: mockCiStatus } = pipelines[0].details;

  const defaultProps = {
    endpoint: 'endpoint',
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMount(CommitPipelineStatus, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findLoader = () => wrapper.find(GlLoadingIcon);
  const findLink = () => wrapper.find('a');
  const findCiIcon = () => findLink().find(CiIcon);

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  describe('Visibility management', () => {
    describe('when component is hidden', () => {
      beforeEach(() => {
        Visibility.hidden.mockReturnValue(true);
        createComponent();
      });

      it('does not start polling', () => {
        const [pollInstance] = Poll.mock.instances;
        expect(pollInstance.makeRequest).not.toHaveBeenCalled();
      });

      it('requests pipeline data', () => {
        expect(mockFetchData).toHaveBeenCalled();
      });
    });

    describe('when component is visible', () => {
      beforeEach(() => {
        Visibility.hidden.mockReturnValue(false);
        createComponent();
      });

      it('starts polling', () => {
        const [pollInstance] = [...Poll.mock.instances].reverse();
        expect(pollInstance.makeRequest).toHaveBeenCalled();
      });
    });

    describe('when component changes its visibility', () => {
      it.each`
        visibility | action
        ${false}   | ${'restart'}
        ${true}    | ${'stop'}
      `(
        '$action polling when component visibility becomes $visibility',
        ({ visibility, action }) => {
          Visibility.hidden.mockReturnValue(!visibility);
          createComponent();
          const [pollInstance] = Poll.mock.instances;
          expect(pollInstance[action]).not.toHaveBeenCalled();
          Visibility.hidden.mockReturnValue(visibility);
          const [visibilityHandler] = Visibility.change.mock.calls[0];
          visibilityHandler();
          expect(pollInstance[action]).toHaveBeenCalled();
        },
      );
    });
  });

  it('stops polling when component is destroyed', () => {
    createComponent();
    wrapper.destroy();
    const [pollInstance] = Poll.mock.instances;
    expect(pollInstance.stop).toHaveBeenCalled();
  });

  describe('when polling', () => {
    let pollConfig;
    beforeEach(() => {
      Poll.mockImplementation((config) => {
        pollConfig = config;
        return { makeRequest: jest.fn(), restart: jest.fn(), stop: jest.fn() };
      });
      createComponent();
    });

    it('shows the loading icon at start', async () => {
      createComponent();
      expect(findLoader().exists()).toBe(true);

      pollConfig.successCallback({
        data: { pipelines: [] },
      });

      await nextTick();
      expect(findLoader().exists()).toBe(false);
    });

    describe('is successful', () => {
      beforeEach(async () => {
        pollConfig.successCallback({
          data: { pipelines: [{ details: { status: mockCiStatus } }] },
        });
        await nextTick();
      });

      it('does not render loader', () => {
        expect(findLoader().exists()).toBe(false);
      });

      it('renders link with href', () => {
        expect(findLink().attributes('href')).toEqual(mockCiStatus.details_path);
      });

      it('renders CI icon with the correct title and status', () => {
        expect(findCiIcon().attributes('title')).toEqual('Pipeline: passed');
        expect(findCiIcon().props('status')).toEqual(mockCiStatus);
      });
    });

    describe('is not successful', () => {
      beforeEach(() => {
        pollConfig.errorCallback();
      });

      it('does not render loader', () => {
        expect(findLoader().exists()).toBe(false);
      });

      it('renders link with href', () => {
        expect(findLink().attributes('href')).toBeUndefined();
      });

      it('renders not found CI icon', () => {
        expect(findCiIcon().attributes('title')).toEqual('Pipeline: not found');
        expect(findCiIcon().props('status')).toEqual({
          text: 'not found',
          icon: 'status_notfound',
          group: 'notfound',
        });
      });

      it('displays flash error message', () => {
        expect(createFlash).toHaveBeenCalled();
      });
    });
  });
});
