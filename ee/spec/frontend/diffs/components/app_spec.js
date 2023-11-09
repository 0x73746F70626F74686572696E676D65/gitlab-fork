import { shallowMount } from '@vue/test-utils';

import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import getMRCodequalityAndSecurityReports from '~/diffs/components/graphql/get_mr_codequality_and_security_reports.query.graphql';
import { TEST_HOST } from 'spec/test_constants';
import App, { FINDINGS_POLL_INTERVAL } from '~/diffs/components/app.vue';
import store from '~/mr_notes/stores';

import {
  codeQualityNewErrorsHandler,
  SASTParsedHandler,
  SASTErrorAndParsedHandler,
  codeQualityErrorAndParsed,
} from './mocks/queries';

const TEST_ENDPOINT = `${TEST_HOST}/diff/endpoint`;

jest.mock('~/mr_notes/stores', () => jest.requireActual('helpers/mocks/mr_notes/stores'));
Vue.use(VueApollo);
Vue.config.ignoredElements = ['copy-code'];

describe('diffs/components/app', () => {
  let wrapper;
  let stopPollingSpy;
  let mockDispatch;
  let fakeApollo;

  const createComponent = (
    props = {},
    baseConfig = {},
    flags = {},
    queryHandler = codeQualityNewErrorsHandler,
  ) => {
    store.reset();
    store.getters.isNotesFetched = false;
    store.getters.getNoteableData = {
      current_user: {
        can_create_note: true,
      },
    };
    store.getters['findingsDrawer/activeDrawer'] = {};
    store.getters['diffs/flatBlobsList'] = [];
    store.getters['diffs/isBatchLoading'] = false;
    store.getters['diffs/isBatchLoadingError'] = false;
    store.getters['diffs/whichCollapsedTypes'] = { any: false };

    store.state.diffs.isLoading = false;
    store.state.findingsDrawer = { activeDrawer: false };

    store.state.diffs.isTreeLoaded = true;

    store.dispatch('diffs/setBaseConfig', {
      endpoint: TEST_ENDPOINT,
      endpointMetadata: `${TEST_HOST}/diff/endpointMetadata`,
      endpointBatch: `${TEST_HOST}/diff/endpointBatch`,
      endpointDiffForPath: TEST_ENDPOINT,
      projectPath: 'namespace/project',
      dismissEndpoint: '',
      showSuggestPopover: true,
      mrReviews: {},
      ...baseConfig,
    });

    mockDispatch = jest.spyOn(store, 'dispatch');

    fakeApollo = createMockApollo([[getMRCodequalityAndSecurityReports, queryHandler]]);

    wrapper = shallowMount(App, {
      apolloProvider: fakeApollo,
      provide: {
        glFeatures: {
          ...flags,
        },
      },
      propsData: {
        endpointCoverage: `${TEST_HOST}/diff/endpointCoverage`,
        endpointCodequality: '',
        sastReportAvailable: false,
        currentUser: {},
        changesEmptyStateIllustration: '',
        ...props,
      },
      mocks: {
        $store: store,
      },
    });
  };

  describe('EE codequality diff', () => {
    describe('sastReportsInInlineDiff flag off', () => {
      it('fetches Code Quality data via REST and not via GraphQL when endpoint is provided', () => {
        createComponent({
          shouldShow: true,
          endpointCodequality: `${TEST_HOST}/diff/endpointCodequality`,
        });
        expect(codeQualityNewErrorsHandler).not.toHaveBeenCalled();
        expect(mockDispatch).toHaveBeenCalledWith('diffs/fetchCodequality');
      });

      it('does not fetch code quality data when endpoint is blank', () => {
        createComponent({ shouldShow: true, endpointCodequality: '' });

        expect(mockDispatch).not.toHaveBeenCalledWith('diffs/fetchCodequality');
        expect(codeQualityNewErrorsHandler).not.toHaveBeenCalled();
      });
    });

    describe('sastReportsInInlineDiff flag on', () => {
      it('polls Code Quality data via GraphQL and not via REST when endpoint is provided', async () => {
        createComponent(
          { shouldShow: true, endpointCodequality: `${TEST_HOST}/diff/endpointCodequality` },
          {},
          { sastReportsInInlineDiff: true },
          codeQualityErrorAndParsed,
        );
        await waitForPromises();
        expect(codeQualityErrorAndParsed).toHaveBeenCalledTimes(1);
        expect(mockDispatch).not.toHaveBeenCalledWith('diffs/fetchCodequality');
        jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

        expect(codeQualityErrorAndParsed).toHaveBeenCalledTimes(2);
      });

      it('stops polling when newErrors in response are defined', async () => {
        stopPollingSpy = jest.spyOn(App.methods, 'getMRCodequalityAndSecurityReportStopPolling');

        createComponent(
          {
            shouldShow: true,
            endpointCodequality: `${TEST_HOST}/diff/endpointCodequality`,
          },
          {},
          { sastReportsInInlineDiff: true },
        );

        const getMRCodequalityAndSecurityReportsQuery =
          wrapper.vm.$apollo.queries.getMRCodequalityAndSecurityReports;
        jest.spyOn(getMRCodequalityAndSecurityReportsQuery, 'stopPolling');

        await waitForPromises();

        expect(stopPollingSpy).toHaveBeenCalled();
      });

      it('does not fetch code quality data when endpoint is blank', () => {
        createComponent(
          { shouldShow: false, endpointCodequality: '' },
          {},
          { sastReportsInInlineDiff: true },
        );
        expect(codeQualityNewErrorsHandler).not.toHaveBeenCalled();
        expect(mockDispatch).not.toHaveBeenCalledWith('diffs/fetchCodequality');
      });
    });
  });

  describe('EE SAST diff', () => {
    describe('sastReportsInInlineDiff flag off', () => {
      it('does not fetch SAST data when sastReportAvailable is true', () => {
        createComponent({ shouldShow: true, sastReportAvailable: true });
        expect(codeQualityNewErrorsHandler).not.toHaveBeenCalled();
      });

      it('does not fetch SAST data when sastReportAvailable is false', () => {
        createComponent({ shouldShow: false, sastReportAvailable: false });

        expect(codeQualityNewErrorsHandler).not.toHaveBeenCalled();
      });
    });

    describe('sastReportsInInlineDiff flag on', () => {
      it('polls SAST data when sastReportAvailable is true', async () => {
        createComponent(
          { shouldShow: true, sastReportAvailable: true },
          {},
          { sastReportsInInlineDiff: true },
          SASTErrorAndParsedHandler,
        );
        await waitForPromises();

        expect(SASTErrorAndParsedHandler).toHaveBeenCalledTimes(1);
        jest.advanceTimersByTime(FINDINGS_POLL_INTERVAL);

        expect(SASTErrorAndParsedHandler).toHaveBeenCalledTimes(2);
      });

      it('stops polling when sastReport status is PARSED', async () => {
        stopPollingSpy = jest.spyOn(App.methods, 'getMRCodequalityAndSecurityReportStopPolling');

        createComponent(
          {
            shouldShow: true,
            sastReportAvailable: true,
          },
          {},
          { sastReportsInInlineDiff: true },
          SASTParsedHandler,
        );

        const getMRCodequalityAndSecurityReportsQuery =
          wrapper.vm.$apollo.queries.getMRCodequalityAndSecurityReports;
        jest.spyOn(getMRCodequalityAndSecurityReportsQuery, 'stopPolling');

        await waitForPromises();

        expect(stopPollingSpy).toHaveBeenCalled();
      });

      it('does not fetch SAST data when sastReportAvailable is false', () => {
        createComponent({ shouldShow: false }, {}, { sastReportsInInlineDiff: true });
        expect(codeQualityNewErrorsHandler).not.toHaveBeenCalled();
      });
    });
  });
});
