import { mount } from '@vue/test-utils';
import EEJobLogTopBar from 'ee/ci/job_details/components/job_log_top_bar.vue';
import CeJobLogTopBar from '~/ci/job_details/components/job_log_top_bar.vue';
import { mockJobLog } from '../../mock_data';

describe('EE JobLogTopBar', () => {
  let wrapper;

  const defaultProps = {
    rawPath: '/raw',
    size: 511952,
    isScrollTopDisabled: false,
    isScrollBottomDisabled: false,
    isScrollingDown: true,
    isJobLogSizeVisible: true,
    isComplete: true,
    jobLog: mockJobLog,
  };

  const createComponent = (props) => {
    wrapper = mount(EEJobLogTopBar, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        aiRootCauseAnalysisAvailable: true,
        duoFeaturesEnabled: true,
        rootCauseAnalysisDuo: false,
        jobGid: 'gid://gitlab/Ci::Build/123',
      },
    });
  };

  const findJobLogTopBar = () => wrapper.findComponent(CeJobLogTopBar);

  describe('when the underlying event is triggered', () => {
    beforeEach(() => {
      createComponent();
    });

    it.each`
      eventName               | parameter
      ${'scrollJobLogTop'}    | ${undefined}
      ${'scrollJobLogBottom'} | ${undefined}
      ${'searchResults'}      | ${'searchResults'}
    `('should re-trigger events', ({ eventName, parameter }) => {
      findJobLogTopBar().vm.$emit(eventName, parameter);

      expect(wrapper.emitted(eventName)[0][0]).toBe(parameter);
    });
  });
});
