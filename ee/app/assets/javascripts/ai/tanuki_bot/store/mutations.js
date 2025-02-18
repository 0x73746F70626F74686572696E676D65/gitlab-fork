import { isObject, uniqueId } from 'lodash';
import { GENIE_CHAT_MODEL_ROLES, CHAT_MESSAGE_TYPES } from '../../constants';
import * as types from './mutation_types';

export default {
  [types.ADD_MESSAGE](state, newMessageData) {
    if (newMessageData && isObject(newMessageData) && Object.values(newMessageData).length) {
      if (newMessageData.role.toLowerCase() === GENIE_CHAT_MODEL_ROLES.system) {
        return;
      }
      let isLastMessage = false;

      const getExistingMessagesIndex = (role) =>
        state.messages.findIndex(
          (msg) => msg.requestId === newMessageData.requestId && msg.role.toLowerCase() === role,
        );
      const userMessageWithRequestIdIndex = getExistingMessagesIndex(GENIE_CHAT_MODEL_ROLES.user);
      const userMessageExists = userMessageWithRequestIdIndex > -1;

      const isUserMessage = newMessageData.role.toLowerCase() === GENIE_CHAT_MODEL_ROLES.user;
      const isAssistantMessage =
        newMessageData.role.toLowerCase() === GENIE_CHAT_MODEL_ROLES.assistant;

      if (isAssistantMessage) {
        const assistantMessageWithRequestIdIndex = getExistingMessagesIndex(
          GENIE_CHAT_MODEL_ROLES.assistant,
        );
        const assistantMessageExists = assistantMessageWithRequestIdIndex > -1;

        if (assistantMessageExists) {
          state.messages.splice(assistantMessageWithRequestIdIndex, 1, {
            ...state.messages[assistantMessageWithRequestIdIndex],
            ...newMessageData,
          });
        } else if (userMessageExists) {
          // We add the new ASSISTANT message
          isLastMessage = userMessageWithRequestIdIndex === state.messages.length - 1;
          state.messages.splice(userMessageWithRequestIdIndex + 1, 0, newMessageData);
        } else {
          state.messages.push(newMessageData);
        }
      } else if (isUserMessage) {
        if (userMessageExists) {
          // We update the existing USER message object instead of pushing a new one
          state.messages.splice(userMessageWithRequestIdIndex, 1, {
            ...state.messages[userMessageWithRequestIdIndex],
            ...newMessageData,
          });
        } else {
          const extraData = {};
          // If the user prompt in question failed being answered,
          // it might not have an id and we want to reset
          // the loading state.
          if (newMessageData.errors?.length) {
            extraData.requestId = newMessageData.requestId ?? uniqueId('failing-request');
            isLastMessage = true;
          }
          state.messages.push({ ...newMessageData, ...extraData });
        }
      }

      if (isLastMessage) {
        state.loading = false;
      }
    }
  },
  [types.SET_LOADING](state, loading) {
    state.loading = loading;
  },
  [types.ADD_TOOL_MESSAGE](state, toolMessage) {
    if (
      (toolMessage.role.toLowerCase() !== GENIE_CHAT_MODEL_ROLES.system &&
        toolMessage.type !== CHAT_MESSAGE_TYPES.tool) ||
      !state.loading
    ) {
      return;
    }
    state.toolMessage = toolMessage;
  },
  [types.CLEAN_MESSAGES](state) {
    state.messages = [];
  },
};
