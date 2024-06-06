<script>
import { GlFilteredSearch, GlLink, GlPopover, GlSprintf } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { __, s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import LicenseToken from './tokens/license_token.vue';
import ProjectToken from './tokens/project_token.vue';
import ComponentToken from './tokens/component_token.vue';
import PackagerToken from './tokens/package_manager_token.vue';

export default {
  components: {
    GlFilteredSearch,
    GlPopover,
    GlLink,
    GlSprintf,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['belowGroupLimit'],
  data() {
    return {
      value: [],
      currentFilterParams: null,
    };
  },
  computed: {
    ...mapState(['currentList']),
    tokens() {
      return [
        {
          type: 'licenses',
          title: __('License'),
          multiSelect: true,
          unique: true,
          token: LicenseToken,
          operators: OPERATORS_IS,
        },
        {
          type: 'project_ids',
          title: __('Project'),
          multiSelect: true,
          unique: true,
          token: ProjectToken,
          operators: OPERATORS_IS,
        },
        ...(this.glFeatures.groupLevelDependenciesFilteringByPackager
          ? [
              {
                type: 'package_managers',
                title: __('Packager'),
                multiSelect: true,
                unique: true,
                token: PackagerToken,
                operators: OPERATORS_IS,
              },
            ]
          : []),
        ...(this.glFeatures.groupLevelDependenciesFilteringByComponent
          ? [
              {
                type: 'component_names',
                title: __('Component'),
                multiSelect: true,
                unique: true,
                token: ComponentToken,
                operators: OPERATORS_IS,
              },
            ]
          : []),
      ];
    },
  },
  methods: {
    ...mapActions('allDependencies', ['setSearchFilterParameters', 'fetchDependencies']),
  },
  GROUP_LEVEL_DEPENDENCY_LIST_DOC: helpPagePath('user/application_security/dependency_list/index', {
    anchor: 'view-a-groups-dependencies',
  }),
  i18n: {
    searchInputPlaceholder: s__('Dependencies|Search or filter dependencies...'),
    popoverTitle: s__('Dependencies|Filtering unavailable'),
    description: s__(
      `Dependencies|This group exceeds the maximum number of 600 sub-groups. We cannot accurately filter or search the dependency list above this maximum. To view or filter a subset of this information, go to a subgroup's dependency list.`,
    ),
  },
  filteredSearchId: 'group-level-filtered-search',
};
</script>

<template>
  <div>
    <gl-filtered-search
      :id="$options.filteredSearchId"
      :view-only="!belowGroupLimit"
      :placeholder="$options.i18n.searchInputPlaceholder"
      :available-tokens="tokens"
      terms-as-tokens
      @input="setSearchFilterParameters"
      @submit="fetchDependencies({ page: 1 })"
    />
    <gl-popover
      v-if="!belowGroupLimit"
      :target="$options.filteredSearchId"
      :title="$options.i18n.popoverTitle"
      triggers="hover"
      :show-close-button="true"
      container="viewport"
    >
      <gl-sprintf :message="$options.i18n.description">
        <template #link="{ content }">
          <gl-link :href="$options.GROUP_LEVEL_DEPENDENCY_LIST_DOC" class="gl-font-sm">
            {{ content }}
          </gl-link>
        </template>
      </gl-sprintf>
    </gl-popover>
  </div>
</template>
