import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ChildEpicIssueIndicator from 'ee/issuable/child_epic_issue_indicator/components/child_epic_issue_indicator.vue';

describe('ChildEpicIssueIndicator component', () => {
  let wrapper;
  const mockIssuable = {
    id: 'gid://gitlab/Issue/1',
    epic: {
      id: 'gid://gitlab/Epic/1',
    },
  };

  const createComponent = ({ filteredEpicId = 'gid://gitlab/Epic/1' } = {}) => {
    wrapper = shallowMountExtended(ChildEpicIssueIndicator, {
      propsData: {
        issuable: mockIssuable,
        filteredEpicId,
      },
    });
  };

  const findIcon = () => wrapper.findByTestId('child-epic-issue-indicator');

  it('renders the icon when issue epic if matches epic id', () => {
    createComponent({ filteredEpicId: 'gid://gitlab/Epic/3' });

    expect(findIcon().exists()).toBe(true);
  });

  it('does not render the icon when there is no filtered epic id', () => {
    createComponent();

    expect(findIcon().exists()).toBe(false);
  });
});
