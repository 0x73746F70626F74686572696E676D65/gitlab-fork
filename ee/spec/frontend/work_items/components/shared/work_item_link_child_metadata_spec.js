import { GlIcon, GlTooltip } from '@gitlab/ui';
import { __ } from '~/locale';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { formatDate } from '~/lib/utils/datetime_utility';
import IssueHealthStatus from 'ee/related_items_tree/components/issue_health_status.vue';
import WorkItemLinkChildMetadata from 'ee/work_items/components/shared/work_item_link_child_metadata.vue';

import { workItemObjectiveMetadataWidgetsEE } from '../../mock_data';

describe('WorkItemLinkChildMetadataEE', () => {
  const { PROGRESS, HEALTH_STATUS, WEIGHT, ITERATION } = workItemObjectiveMetadataWidgetsEE;

  let wrapper;

  const createComponent = ({ metadataWidgets = workItemObjectiveMetadataWidgetsEE } = {}) => {
    wrapper = shallowMountExtended(WorkItemLinkChildMetadata, {
      propsData: {
        iid: '1',
        reference: 'test-project-path#1',
        metadataWidgets,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  describe('progress', () => {
    it('renders item progress icon and percentage completion', () => {
      const progressEl = wrapper.findByTestId('item-progress');

      expect(progressEl.exists()).toBe(true);
      expect(progressEl.findComponent(GlIcon).props('name')).toBe('progress');
      expect(wrapper.findByTestId('progressValue').text().trim()).toBe(`${PROGRESS.progress}%`);
    });

    it('renders gl-tooltip', () => {
      const progressEl = wrapper.findByTestId('item-progress');

      expect(progressEl.findComponent(GlTooltip).isVisible()).toBe(true);
    });

    it('renders progressTitle in bold', () => {
      expect(wrapper.findByTestId('progressTitle').text().trim()).toBe(__('Progress'));
    });

    it('renders progressText in bold', () => {
      expect(wrapper.findByTestId('progressText').text().trim()).toBe(__('Last updated'));
    });

    it('renders lastUpdatedInWords', () => {
      expect(wrapper.findByTestId('lastUpdatedInWords').text().trim()).toContain('just now');
    });

    it('renders lastUpdatedTimestamp in muted', () => {
      expect(wrapper.findByTestId('lastUpdatedTimestamp').text().trim()).toContain(
        formatDate(PROGRESS.updatedAt).toString(),
      );
    });
  });

  it('renders item weight icon and value', () => {
    const weightEl = wrapper.findByTestId('item-weight');

    expect(weightEl.exists()).toBe(true);
    expect(weightEl.findComponent(GlIcon).props('name')).toBe('weight');
    expect(wrapper.findByTestId('weight-value').text().trim()).toBe(`${WEIGHT.weight}`);
  });

  describe('dates', () => {
    it('renders item date icon and value', () => {
      const datesEl = wrapper.findByTestId('item-dates');

      expect(datesEl.exists()).toBe(true);
      expect(datesEl.findComponent(GlIcon).props('name')).toBe('calendar');
      expect(wrapper.findByTestId('dates-value').text().trim()).toBe('Jan 1 – Jun 27, 2024');
    });

    it('renders item with no start date', () => {
      createComponent({
        metadataWidgets: {
          START_AND_DUE_DATE: {
            type: 'START_AND_DUE_DATE',
            startDate: null,
            dueDate: '2024-06-27',
            __typename: 'WorkItemWidgetStartAndDueDate',
          },
        },
      });

      expect(wrapper.findByTestId('dates-value').text().trim()).toBe(
        'No start date – Jun 27, 2024',
      );
    });

    it('renders item with no end date', () => {
      createComponent({
        metadataWidgets: {
          START_AND_DUE_DATE: {
            type: 'START_AND_DUE_DATE',
            startDate: '2024-06-27',
            dueDate: null,
            __typename: 'WorkItemWidgetStartAndDueDate',
          },
        },
      });

      expect(wrapper.findByTestId('dates-value').text().trim()).toBe('Jun 27, 2024 – No due date');
    });
  });

  describe('iteration', () => {
    it('renders item iteration icon and name', () => {
      const iterationEl = wrapper.findByTestId('item-iteration');

      expect(iterationEl.exists()).toBe(true);
      expect(iterationEl.findComponent(GlIcon).props('name')).toBe('iteration');
      expect(wrapper.findByTestId('iteration-value').text().trim()).toBe(
        'Dec 19, 2023 - Jan 15, 2024',
      );
    });

    it('renders gl-tooltip', () => {
      const iterationEl = wrapper.findByTestId('item-iteration');

      expect(iterationEl.findComponent(GlTooltip).isVisible()).toBe(true);
    });

    it('renders iteration title in bold', () => {
      expect(wrapper.findByTestId('iteration-title').text().trim()).toBe('Iteration');
    });

    it('renders iteration tooltip text', () => {
      expect(wrapper.findByTestId('iteration-cadence-text').text().trim()).toBe(
        `${ITERATION.iteration.iterationCadence.title}`,
      );
      expect(wrapper.findByTestId('iteration-title-text').text().trim()).toBe(
        `${ITERATION.iteration.title}`,
      );
      expect(wrapper.findByTestId('iteration-period-text').text().trim()).toBe(
        `Dec 19, 2023 - Jan 15, 2024`,
      );
    });
  });

  it('renders health status badge', () => {
    const { healthStatus } = HEALTH_STATUS;

    expect(wrapper.findComponent(IssueHealthStatus).props('healthStatus')).toBe(healthStatus);
  });
});
