import { nextTick } from 'vue';

import { mockTracking } from 'helpers/tracking_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import AiCubeQueryFeedback from 'ee/analytics/analytics_dashboards/components/visualization_designer/ai_cube_query_feedback.vue';

describe('AiCubeQueryFeedback', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  let trackingSpy;
  const mockCorrelationId = 'some-correlation-id';

  const findPopoverBtn = () => wrapper.findByTestId('feedback-acknowledgement-popover-btn');
  const findPopover = () => wrapper.findByTestId('feedback-acknowledgement-popover');
  const findHelpfulBtn = () => wrapper.findByTestId('feedback-helpful-btn');
  const findUnhelpfulBtn = () => wrapper.findByTestId('feedback-unhelpful-btn');
  const findWrongBtn = () => wrapper.findByTestId('feedback-wrong-btn');

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(AiCubeQueryFeedback, {
      propsData: {
        correlationId: null,
        ...props,
      },
    });
  };

  beforeEach(() => {
    trackingSpy = mockTracking(undefined, window.document, jest.spyOn);
  });

  function expectAskingState() {
    expect(wrapper.text()).toContain('How was the result?');
    expect(findHelpfulBtn().exists()).toBe(true);
    expect(findUnhelpfulBtn().exists()).toBe(true);
    expect(findWrongBtn().exists()).toBe(true);
  }

  function expectSubmittedState() {
    expect(wrapper.text()).toContain('Thank you for your feedback.');
    expect(findHelpfulBtn().exists()).toBe(false);
    expect(findUnhelpfulBtn().exists()).toBe(false);
    expect(findWrongBtn().exists()).toBe(false);
  }

  beforeEach(() => createWrapper({ correlationId: mockCorrelationId }));

  it('asks for feedback', () => {
    expectAskingState();
  });

  it('shows tooltip with acknowledgement of data collection', () => {
    findPopoverBtn().vm.$emit('click');

    expect(findPopover().text()).toContain(
      'By providing feedback on AI-generated content, you acknowledge that GitLab may review the prompts you submitted alongside this feedback.',
    );
  });

  it.each([
    [findHelpfulBtn, 'user_feedback_gitlab_duo_query_in_visualization_designer_helpful'],
    [findUnhelpfulBtn, 'user_feedback_gitlab_duo_query_in_visualization_designer_unhelpful'],
    [findWrongBtn, 'user_feedback_gitlab_duo_query_in_visualization_designer_wrong'],
  ])('submits the %s event when clicked', async (findButton, eventLabel) => {
    findButton().vm.$emit('click');

    await nextTick();

    expect(trackingSpy).toHaveBeenCalledWith(
      undefined,
      eventLabel,
      expect.objectContaining({
        label: 'correlation_id',
        property: mockCorrelationId,
      }),
    );
    expectSubmittedState();
  });

  describe('after submitting feedback', () => {
    beforeEach(() => {
      createWrapper({ correlationId: mockCorrelationId });
      findHelpfulBtn().vm.$emit('click');

      return nextTick();
    });

    it('resets the feedback form when receiving a new mockCorrelationId', async () => {
      expectSubmittedState();

      wrapper.setProps({ correlationId: 'some-new-correlation-id' });
      await nextTick();

      expectAskingState();
    });
  });
});
