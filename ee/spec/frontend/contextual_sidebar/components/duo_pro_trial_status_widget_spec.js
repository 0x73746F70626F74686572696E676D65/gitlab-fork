import { GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoProTrialStatusWidget from 'ee/contextual_sidebar/components/duo_pro_trial_status_widget.vue';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';

describe('DuoProTrialStatusWidget component', () => {
  let wrapper;
  let trackingSpy;

  const trialDaysUsed = 10;
  const trialDuration = 30;

  const findGlLink = () => wrapper.findComponent(GlLink);

  const createComponent = (providers = {}) => {
    return shallowMountExtended(DuoProTrialStatusWidget, {
      provide: {
        trialDaysUsed,
        trialDuration,
        percentageComplete: 10,
        widgetUrl: 'some/widget/path',
        ...providers,
      },
    });
  };

  beforeEach(() => {
    trackingSpy = mockTracking(undefined, undefined, jest.spyOn);
  });

  afterEach(() => {
    unmockTracking();
  });

  describe('interpolated strings', () => {
    it('correctly interpolates them all', () => {
      wrapper = createComponent();

      expect(wrapper.text()).not.toMatch(/%{\w+}/);
    });
  });

  describe('without the optional containerId prop', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('matches the snapshot for namespace in active trial', () => {
      expect(wrapper.element).toMatchSnapshot();
    });

    it('renders without an id', () => {
      expect(findGlLink().attributes('id')).toBe(undefined);
    });

    describe('tracks when the widget menu is clicked', () => {
      it('tracks with correct information when namespace is in an active trial', async () => {
        await wrapper.findByTestId('duo-pro-trial-widget-menu').trigger('click');

        expect(trackingSpy).toHaveBeenCalledWith('trial_status_widget', 'click_link', {
          category: 'trial_status_widget',
          label: 'duo_pro_trial',
        });
      });
    });

    it('shows the expected day 1 text', () => {
      wrapper = createComponent({ trialDaysUsed: 1 });

      expect(wrapper.text()).toMatchInterpolatedText('GitLab Duo Pro Trial Day 1/30');
    });

    it('shows the expected last day text', () => {
      wrapper = createComponent({ trialDaysUsed: 30 });

      expect(wrapper.text()).toMatchInterpolatedText('GitLab Duo Pro Trial Day 30/30');
    });
  });

  describe('with the optional containerId prop', () => {
    beforeEach(() => {
      wrapper = createComponent({ containerId: 'some-id' });
    });

    it('renders with the given id', () => {
      expect(findGlLink().attributes('id')).toBe('some-id');
    });
  });
});
