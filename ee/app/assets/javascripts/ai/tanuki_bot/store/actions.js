import { MESSAGE_TYPES } from '../constants';
import { GENIE_CHAT_RESET_MESSAGE } from '../../constants';
import * as types from './mutation_types';

export const sendUserMessage = async ({ commit }, msg) => {
  commit(types.SET_LOADING, true);
  commit(types.ADD_USER_MESSAGE, msg);
};

export const receiveMutationResponse = ({ commit, dispatch }, { data, message }) => {
  const hasErrors = data?.aiAction?.errors?.length > 0;

  if (hasErrors) {
    dispatch('tanukiBotMessageError');
  } else if (message === GENIE_CHAT_RESET_MESSAGE) {
    commit(types.SET_LOADING, false);
  }
};

export const receiveTanukiBotMessage = async ({ commit, dispatch }, data) => {
  const { errors = [], responseBody } = data.aiCompletionResponse || {};

  if (errors?.length) {
    dispatch('tanukiBotMessageError');
  } else if (responseBody) {
    commit(types.SET_LOADING, false);

    let parsedResponse;
    try {
      parsedResponse = JSON.parse(responseBody);
    } catch {
      parsedResponse = { content: responseBody };
    }
    commit(types.ADD_TANUKI_MESSAGE, parsedResponse);
  }
};

export const tanukiBotMessageError = ({ commit }) => {
  commit(types.SET_LOADING, false);
  commit(types.ADD_ERROR_MESSAGE);
};

export const setMessages = ({ commit, dispatch }, messages) => {
  messages.forEach((msg, index) => {
    if (msg.errors?.length) {
      dispatch('tanukiBotMessageError');
    } else {
      switch (msg.role.toLowerCase()) {
        case MESSAGE_TYPES.USER:
          dispatch('sendUserMessage', msg.content);
          if (index !== messages.length - 1) {
            // if this is not the last message in the array,
            // then we need to set loading to false.
            // Otherwise, if the message is the last one and is from user,
            // then we need to keep loading as `true` - the AI response is still pending.
            commit(types.SET_LOADING, false);
          }
          break;
        case MESSAGE_TYPES.TANUKI:
          dispatch('receiveTanukiBotMessage', {
            aiCompletionResponse: { responseBody: msg.content },
          });
          break;
        default:
          break;
      }
    }
  });
};
