import MockAdapter from 'axios-mock-adapter';
import { mapApprovalRuleRequest, mapApprovalSettingsResponse } from 'ee/approvals/mappers';
import * as types from 'ee/approvals/stores/modules/base/mutation_types';
import * as actions from 'ee/approvals/stores/modules/project_settings/actions';
import testAction from 'helpers/vuex_action_helper';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_INTERNAL_SERVER_ERROR, HTTP_STATUS_OK } from '~/lib/utils/http_status';

jest.mock('~/alert');

const TEST_PROJECT_ID = 9;
const TEST_RULE_ID = 7;
const TEST_RULE_REQUEST = {
  name: 'Lorem',
  approvalsRequired: 1,
  groups: [7],
  users: [8, 9],
};
const TEST_RULE_RESPONSE = {
  id: 7,
  name: 'Ipsum',
  approvals_required: 2,
  approvers: [{ id: 7 }, { id: 8 }, { id: 9 }],
  groups: [{ id: 4 }],
  users: [{ id: 7 }, { id: 8 }],
};
const TEST_RULES_PATH = 'projects/9/approval_rules';

describe('EE approvals project settings module actions', () => {
  let state;
  let mock;

  beforeEach(() => {
    state = {
      settings: {
        projectId: TEST_PROJECT_ID,
        settingsPath: TEST_RULES_PATH,
        rulesPath: TEST_RULES_PATH,
      },
    };
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('drawer', () => {
    it('openCreateDrawer', () => {
      return testAction(
        actions.openCreateDrawer,
        TEST_RULE_RESPONSE,
        {},
        [
          { type: types.SET_DRAWER_OPEN, payload: true },
          { type: types.SET_EDIT_RULE, payload: TEST_RULE_RESPONSE },
        ],
        [],
      );
    });

    it('closeCreateDrawer', () => {
      return testAction(
        actions.closeCreateDrawer,
        null,
        {},
        [
          { type: types.SET_DRAWER_OPEN, payload: false },
          { type: types.SET_EDIT_RULE, payload: null },
        ],
        [],
      );
    });
  });

  describe('requestRules', () => {
    it('sets loading', () => {
      return testAction(
        actions.requestRules,
        null,
        {},
        [{ type: types.SET_LOADING, payload: true }],
        [],
      );
    });
  });

  describe('receiveRulesSuccess', () => {
    it('sets rules', () => {
      const settings = [{ id: 1 }];

      return testAction(
        actions.receiveRulesSuccess,
        settings,
        {},
        [
          { type: types.SET_APPROVAL_SETTINGS, payload: settings },
          { type: types.SET_LOADING, payload: false },
        ],
        [],
      );
    });
  });

  describe('receiveRulesError', () => {
    it('creates an alert', () => {
      expect(createAlert).not.toHaveBeenCalled();

      actions.receiveRulesError();

      expect(createAlert).toHaveBeenCalledTimes(1);
      expect(createAlert).toHaveBeenCalledWith({
        message: expect.stringMatching('error occurred'),
      });
    });
  });

  describe('setRulesFilter', () => {
    it('sets rules', () => {
      const rules = ['test'];

      return testAction(
        actions.setRulesFilter,
        rules,
        {},
        [{ type: types.SET_RULES_FILTER, payload: rules }],
        [],
      );
    });
  });

  describe('fetchRules', () => {
    it('dispatches request/receive', async () => {
      const data = [TEST_RULE_RESPONSE];
      mock.onGet(TEST_RULES_PATH).replyOnce(HTTP_STATUS_OK, data);

      await testAction(
        actions.fetchRules,
        null,
        state,
        [],
        [
          { type: 'requestRules' },
          { type: 'receiveRulesSuccess', payload: mapApprovalSettingsResponse(data) },
        ],
      );
      expect(mock.history.get.map((x) => x.url)).toEqual([TEST_RULES_PATH]);
    });

    it('dispatches request/receive on error', () => {
      mock.onGet(TEST_RULES_PATH).replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);

      return testAction(
        actions.fetchRules,
        null,
        state,
        [],
        [{ type: 'requestRules' }, { type: 'receiveRulesError' }],
      );
    });
  });

  describe('postRuleSuccess', () => {
    it('closes modal and fetches', () => {
      return testAction(
        actions.postRuleSuccess,
        null,
        {},
        [],
        [{ type: 'createModal/close' }, { type: 'fetchRules' }],
      );
    });
  });

  describe('postRule', () => {
    it('dispatches success on success', async () => {
      mock.onPost(TEST_RULES_PATH).replyOnce(HTTP_STATUS_OK);

      await testAction(
        actions.postRule,
        TEST_RULE_REQUEST,
        state,
        [],
        [{ type: 'postRuleSuccess' }],
      );
      expect(mock.history.post).toEqual([
        expect.objectContaining({
          url: TEST_RULES_PATH,
          data: JSON.stringify(mapApprovalRuleRequest(TEST_RULE_REQUEST)),
        }),
      ]);
    });
  });

  describe('putRule', () => {
    it('dispatches success on success', async () => {
      mock.onPut(`${TEST_RULES_PATH}/${TEST_RULE_ID}`).replyOnce(HTTP_STATUS_OK);

      await testAction(
        actions.putRule,
        { id: TEST_RULE_ID, ...TEST_RULE_REQUEST },
        state,
        [],
        [{ type: 'postRuleSuccess' }],
      );
      expect(mock.history.put).toEqual([
        expect.objectContaining({
          url: `${TEST_RULES_PATH}/${TEST_RULE_ID}`,
          data: JSON.stringify(mapApprovalRuleRequest(TEST_RULE_REQUEST)),
        }),
      ]);
    });
  });

  describe('deleteRuleSuccess', () => {
    it('closes modal and fetches', () => {
      return testAction(
        actions.deleteRuleSuccess,
        null,
        {},
        [],
        [{ type: 'deleteModal/close' }, { type: 'fetchRules' }],
      );
    });
  });

  describe('deleteRuleError', () => {
    it('creates an alert', () => {
      expect(createAlert).not.toHaveBeenCalled();

      actions.deleteRuleError();

      expect(createAlert.mock.calls[0]).toEqual([
        { message: expect.stringMatching('error occurred') },
      ]);
    });
  });

  describe('deleteRule', () => {
    it('dispatches success on success', async () => {
      mock.onDelete(`${TEST_RULES_PATH}/${TEST_RULE_ID}`).replyOnce(HTTP_STATUS_OK);

      await testAction(
        actions.deleteRule,
        TEST_RULE_ID,
        state,
        [],
        [{ type: 'deleteRuleSuccess' }],
      );
      expect(mock.history.delete).toEqual([
        expect.objectContaining({
          url: `${TEST_RULES_PATH}/${TEST_RULE_ID}`,
        }),
      ]);
    });

    it('dispatches error on error', () => {
      mock
        .onDelete(`${TEST_RULES_PATH}/${TEST_RULE_ID}`)
        .replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);

      return testAction(actions.deleteRule, TEST_RULE_ID, state, [], [{ type: 'deleteRuleError' }]);
    });
  });
});
