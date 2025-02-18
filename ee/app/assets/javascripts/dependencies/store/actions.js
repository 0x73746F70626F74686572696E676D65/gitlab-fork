import * as types from './mutation_types';

export const addListType = ({ commit }, payload) => commit(types.ADD_LIST_TYPE, payload);

export const dispatchForNamespaces = ({ state, dispatch }, action, payload) =>
  Promise.all(state.listTypes.map(({ namespace }) => dispatch(`${namespace}/${action}`, payload)));

export const setDependenciesEndpoint = (handle, endpoint) =>
  dispatchForNamespaces(handle, 'setDependenciesEndpoint', endpoint);

export const setExportDependenciesEndpoint = (handle, payload) =>
  dispatchForNamespaces(handle, 'setExportDependenciesEndpoint', payload);

export const setNamespaceType = (handle, payload) =>
  dispatchForNamespaces(handle, 'setNamespaceType', payload);

export const setPageInfo = (handle, payload) =>
  dispatchForNamespaces(handle, 'setPageInfo', payload);

export const setSortField = (handle, payload) =>
  dispatchForNamespaces(handle, 'setSortField', payload);

export const setCurrentList = ({ state, commit }, payload) => {
  if (state.listTypes.map(({ namespace }) => namespace).includes(payload)) {
    commit(types.SET_CURRENT_LIST, payload);
  }
};
