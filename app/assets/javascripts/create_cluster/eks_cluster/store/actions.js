import * as types from './mutation_types';

export const setRegion = ({ commit }, payload) => {
  commit(types.SET_REGION, payload);
};

export const setVpc = ({ commit }, payload) => {
  commit(types.SET_VPC, payload);
};

export default () => {};
