import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { cloneDeep } from 'lodash';
import IssuesDashboardApp from 'ee/issues/dashboard/components/issues_dashboard_app.vue';
import getIssuesQuery from 'ee_else_ce/issues/dashboard/queries/get_issues.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import CEIssuesDashboardApp from '~/issues/dashboard/components/issues_dashboard_app.vue';
import getIssuesCountsQuery from '~/issues/dashboard/queries/get_issues_counts.query.graphql';
import {
  CREATED_DESC,
  TYPE_TOKEN_KEY_RESULT_OPTION,
  TYPE_TOKEN_OBJECTIVE_OPTION,
} from '~/issues/list/constants';
import { issuesCountsQueryResponse, issuesQueryResponse } from 'jest/issues/dashboard/mock_data';

describe('EE IssuesDashboardApp component', () => {
  let wrapper;

  Vue.use(VueApollo);

  const defaultProvide = {
    autocompleteAwardEmojisPath: 'autocomplete/award/emojis/path',
    autocompleteUsersPath: 'autocomplete/users.json',
    calendarPath: 'calendar/path',
    dashboardLabelsPath: 'dashboard/labels/path',
    dashboardMilestonesPath: 'dashboard/milestones/path',
    emptyStateWithFilterSvgPath: 'empty/state/with/filter/svg/path.svg',
    emptyStateWithoutFilterSvgPath: 'empty/state/with/filter/svg/path.svg',
    hasBlockedIssuesFeature: true,
    hasIssueDateFilterFeature: true,
    hasIssuableHealthStatusFeature: true,
    hasIssueWeightsFeature: true,
    hasOkrsFeature: true,
    hasScopedLabelsFeature: true,
    initialSort: CREATED_DESC,
    isPublicVisibilityRestricted: false,
    isSignedIn: true,
    rssPath: 'rss/path',
  };

  const defaultQueryResponse = cloneDeep(issuesQueryResponse);
  defaultQueryResponse.data.issues.nodes[0].blockingCount = 1;
  defaultQueryResponse.data.issues.nodes[0].healthStatus = null;
  defaultQueryResponse.data.issues.nodes[0].weight = 5;

  const findCEIssuesDashboardApp = () => wrapper.findComponent(CEIssuesDashboardApp);

  const mountComponent = ({
    provide = {},
    issuesQueryHandler = jest.fn().mockResolvedValue(defaultQueryResponse),
    issuesCountsQueryHandler = jest.fn().mockResolvedValue(issuesCountsQueryResponse),
  } = {}) => {
    wrapper = mountExtended(IssuesDashboardApp, {
      apolloProvider: createMockApollo([
        [getIssuesQuery, issuesQueryHandler],
        [getIssuesCountsQuery, issuesCountsQueryHandler],
      ]),
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  describe('tokens', () => {
    describe.each`
      hasOkrsFeature | eeWorkItemTypeTokens                                           | message
      ${false}       | ${[]}                                                          | ${'not include'}
      ${true}        | ${[TYPE_TOKEN_OBJECTIVE_OPTION, TYPE_TOKEN_KEY_RESULT_OPTION]} | ${'include'}
    `(
      'when hasOkrsFeature is "$hasOkrsFeature"',
      ({ hasOkrsFeature, eeWorkItemTypeTokens, message }) => {
        beforeEach(() => {
          mountComponent({ provide: { hasOkrsFeature } });
        });

        it(`should ${message} objective and key result in type tokens`, () => {
          expect(findCEIssuesDashboardApp().props('eeTypeTokenOptions')).toMatchObject(
            eeWorkItemTypeTokens,
          );
        });
      },
    );
  });
});
