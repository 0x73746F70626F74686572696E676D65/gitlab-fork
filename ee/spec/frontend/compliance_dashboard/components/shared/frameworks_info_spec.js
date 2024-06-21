import { GlLabel, GlPopover } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FrameworksInfo from 'ee/compliance_dashboard/components/shared/frameworks_info.vue';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

describe('ComplianceFrameworksInfo', () => {
  let wrapper;

  const frameworks = [
    { id: 1, name: 'Framework 1', color: '#FF0000' },
    { id: 2, name: 'Framework 2', color: '#00FF00' },
  ];
  const projectName = 'Test Project';
  const complianceCenterPath = '/compliance/center';

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(FrameworksInfo, {
      propsData: {
        frameworks,
        projectName,
        complianceCenterPath,
        ...props,
      },
      stubs: {
        GlLabel,
      },
    });
  };

  const popover = () => wrapper.findComponent(GlPopover);
  const label = () => wrapper.findByTestId('frameworks-info-label');
  const frameworksLabels = () => wrapper.findAllByTestId('framework-label');
  const badge = () => wrapper.findByTestId('single-framework-label');

  describe('rendering', () => {
    it('does not render components when there is no frameworks applied', () => {
      createComponent({ frameworks: [] });
      expect(badge().exists()).toBe(false);
      expect(label().exists()).toBe(false);
    });

    describe('single framework rendering', () => {
      beforeEach(() => {
        createComponent({ frameworks: [frameworks[0]] });
      });

      it('renders FrameworkBadge component when only one framework is applied', () => {
        expect(badge().exists()).toBe(true);
      });

      it('passes expected props', () => {
        expect(badge().props()).toEqual({
          closeable: false,
          framework: frameworks[0],
          showDefault: true,
          showEdit: true,
          showPopover: true,
        });
      });

      it('passes showEditSingleFramework prop to Badge component', () => {
        createComponent({ frameworks: [frameworks[0]], showEditSingleFramework: false });
        expect(badge().props('showEdit')).toBe(false);
      });
    });

    describe('multiple frameworks rendering', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders label  with text', () => {
        expect(label().text()).toBe('Multiple frameworks');
      });

      it('renders GlPopover when multiple frameworks are applied', () => {
        expect(popover().exists()).toBe(true);
      });

      it('renders the correct number of framework labels', () => {
        expect(frameworksLabels()).toHaveLength(frameworks.length);
      });

      it('renders the correct popover title', () => {
        expect(popover().props('title')).toBe(`Compliance frameworks applied to ${projectName}`);
      });
    });
  });
});
