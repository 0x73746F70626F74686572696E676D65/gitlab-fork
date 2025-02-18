<script>
import { GlFilteredSearchSuggestion } from '@gitlab/ui';
import { pick } from 'lodash';
import { createAlert } from '~/alert';
import { __ } from '~/locale';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import searchGroupsQuery from 'ee/boards/graphql/sub_groups.query.graphql';
import { OPTIONS_NONE_ANY } from '~/vue_shared/components/filtered_search_bar/constants';

export default {
  defaultGroups: OPTIONS_NONE_ANY,
  separator: '::',
  components: {
    BaseToken,
    GlFilteredSearchSuggestion,
  },
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      groups: [],
      loading: false,
    };
  },
  methods: {
    fetchGroups(search = '') {
      this.loading = true;
      this.$apollo
        .query({
          query: searchGroupsQuery,
          variables: { fullPath: this.config.fullPath, search },
        })
        .then(({ data }) => data)
        .then(({ group }) => {
          const parentGroup = pick(group, ['id', 'name', 'fullName', 'fullPath']) || {};
          this.groups = [parentGroup, ...(group?.descendantGroups?.nodes || [])];
        })
        .catch(() => createAlert({ message: __('There was a problem fetching groups.') }))
        .finally(() => {
          this.loading = false;
        });
    },
    getActiveGroup(groups, data) {
      if (data && groups.length) {
        return groups.find((group) => this.getValue(group) === data);
      }
      return undefined;
    },
    getValue(group) {
      return group.id;
    },
    displayValue(group) {
      return group?.fullName;
    },
  },
};
</script>

<template>
  <base-token
    v-bind="$attrs"
    :config="config"
    :value="value"
    :active="active"
    :default-suggestions="$options.defaultGroups"
    :suggestions-loading="loading"
    :suggestions="groups"
    :get-active-token-value="getActiveGroup"
    search-by="title"
    v-on="$listeners"
    @fetch-suggestions="fetchGroups"
  >
    <template #view="{ viewTokenProps: { inputValue, activeTokenValue } }">
      {{ activeTokenValue ? displayValue(activeTokenValue) : inputValue }}
    </template>
    <template #suggestions-list="{ suggestions }">
      <gl-filtered-search-suggestion
        v-for="group in suggestions"
        :key="group.id"
        :value="getValue(group)"
      >
        {{ group.fullName }}
      </gl-filtered-search-suggestion>
    </template>
  </base-token>
</template>
