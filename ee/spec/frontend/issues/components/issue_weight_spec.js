import { shallowMount } from '@vue/test-utils';
import IssueWeight from 'ee_component/issues/components/issue_weight.vue';

function mountIssueWeight(propsData) {
  return shallowMount(IssueWeight, {
    propsData,
  });
}

describe('IssueWeight', () => {
  let wrapper;

  describe('weight text', () => {
    it('shows 0 when weight is 0', () => {
      wrapper = mountIssueWeight({
        weight: 0,
      });

      expect(wrapper.find('.board-card-info-text').text()).toContain('0');
    });

    it('shows 5 when weight is 5', () => {
      wrapper = mountIssueWeight({
        weight: 5,
      });

      expect(wrapper.find('.board-card-info-text').text()).toContain('5');
    });
  });

  it('renders a div', () => {
    wrapper = mountIssueWeight({
      weight: 2,
    });

    expect(wrapper.find('div.board-card-info').exists()).toBe(true);
  });
});
