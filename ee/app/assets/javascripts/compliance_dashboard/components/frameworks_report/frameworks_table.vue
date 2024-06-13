<script>
import Vue from 'vue';
import {
  GlButton,
  GlLoadingIcon,
  GlSearchBoxByClick,
  GlSprintf,
  GlTable,
  GlToast,
  GlTooltip,
  GlLink,
} from '@gitlab/ui';
import { __, s__ } from '~/locale';
import FrameworkBadge from '../shared/framework_badge.vue';
import { ROUTE_EDIT_FRAMEWORK, ROUTE_NEW_FRAMEWORK } from '../../constants';
import { isTopLevelGroup } from '../../utils';
import FrameworkInfoDrawer from './framework_info_drawer.vue';

Vue.use(GlToast);

export default {
  name: 'FrameworksTable',
  components: {
    GlButton,
    GlLoadingIcon,
    GlSearchBoxByClick,
    GlSprintf,
    GlTable,
    GlTooltip,
    GlLink,
    FrameworkInfoDrawer,
    FrameworkBadge,
  },
  props: {
    groupPath: {
      type: String,
      required: true,
    },
    rootAncestor: {
      type: Object,
      required: true,
    },
    frameworks: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      selectedFramework: null,
    };
  },
  computed: {
    isTopLevelGroup() {
      return isTopLevelGroup(this.groupPath, this.rootAncestor.path);
    },

    showDrawer() {
      return this.selectedFramework !== null;
    },
  },
  methods: {
    toggleDrawer(item) {
      if (this.selectedFramework?.id === item.id) {
        this.closeDrawer();
      } else {
        this.openDrawer(item);
      }
    },
    openDrawer(item) {
      this.selectedFramework = item;
    },
    closeDrawer() {
      this.selectedFramework = null;
    },
    isLastItem(index, arr) {
      return index >= arr.length - 1;
    },
    newFramework() {
      this.$router.push({ name: ROUTE_NEW_FRAMEWORK });
    },
    editFramework({ id }) {
      this.$router.push({ name: ROUTE_EDIT_FRAMEWORK, params: { id } });
    },
    getPoliciesList(item) {
      const { scanExecutionPolicies, scanResultPolicies } = item;
      return [...scanExecutionPolicies.nodes, ...scanResultPolicies.nodes]
        .map((x) => x.name)
        .join(',');
    },
    filterProjects(projects) {
      return projects.filter((p) => p.fullPath.startsWith(this.groupPath));
    },
  },
  fields: [
    {
      key: 'frameworkName',
      label: __('Frameworks'),
      thClass: 'gl-md-max-w-26 !gl-align-middle',
      tdClass: 'gl-md-max-w-26 !gl-align-middle gl-cursor-pointer',
      sortable: true,
    },
    {
      key: 'associatedProjects',
      label: __('Associated projects'),
      thClass: 'gl-md-max-w-26 gl-whitespace-nowrap !gl-align-middle',
      tdClass: 'gl-md-max-w-26 !gl-align-middle gl-cursor-pointer',
      sortable: false,
    },
    {
      key: 'policies',
      label: __('Policies'),
      thClass: 'gl-md-max-w-26 gl-whitespace-nowrap !gl-align-middle',
      tdClass: 'gl-md-max-w-26 !gl-align-middle gl-cursor-pointer',
      sortable: false,
    },
  ],
  i18n: {
    newFramework: s__('ComplianceFrameworks|New framework'),
    noFrameworksFound: s__('ComplianceReport|No frameworks found'),
    editTitle: s__('ComplianceFrameworks|Edit compliance framework'),
    newFrameworkButtonMessage: s__(
      'ComplianceFrameworks|New compliance framework must be created in top-level group %{linkStart}namespace%{linkEnd}',
    ),
  },
};
</script>
<template>
  <section>
    <div class="gl-p-4 gl-bg-gray-10 gl-display-flex gl-gap-4">
      <gl-search-box-by-click
        class="gl-flex-grow-1"
        @submit="$emit('search', $event)"
        @clear="$emit('search', '')"
      />
      <gl-tooltip v-if="!isTopLevelGroup" :target="() => $refs.newFrameworkButton">
        <gl-sprintf :message="$options.i18n.newFrameworkButtonMessage">
          <template #link>
            <gl-link :href="rootAncestor.webUrl">
              {{ rootAncestor.name }}
            </gl-link>
          </template>
        </gl-sprintf>
      </gl-tooltip>
      <span ref="newFrameworkButton">
        <gl-button
          class="gl-ml-auto"
          variant="confirm"
          category="secondary"
          :disabled="!isTopLevelGroup"
          @click="newFramework"
          >{{ $options.i18n.newFramework }}</gl-button
        >
      </span>
    </div>
    <gl-table
      :fields="$options.fields"
      :busy="isLoading"
      :items="frameworks"
      no-local-sorting
      show-empty
      stacked="md"
      hover
      @row-clicked="toggleDrawer"
    >
      <template #cell(frameworkName)="{ item }">
        <framework-badge :framework="item" />
      </template>
      <template
        #cell(associatedProjects)="{
          item: {
            projects: { nodes: associatedProjects },
          },
        }"
      >
        <div
          v-for="(associatedProject, index) in filterProjects(associatedProjects)"
          :key="associatedProject.id"
          class="gl-display-inline-block"
        >
          <gl-link :href="associatedProject.webUrl">{{ associatedProject.name }}</gl-link
          ><span v-if="!isLastItem(index, associatedProjects)">,&nbsp;</span>
        </div>
      </template>
      <template #cell(policies)="{ item }">
        {{ getPoliciesList(item) }}
      </template>
      <template #table-busy>
        <gl-loading-icon size="lg" color="dark" class="gl-my-5" />
      </template>
      <template #empty>
        <div class="gl-my-5 gl-text-center">
          {{ $options.i18n.noFrameworksFound }}
        </div>
      </template>
    </gl-table>
    <framework-info-drawer
      :group-path="groupPath"
      :root-ancestor="rootAncestor"
      :show-drawer="showDrawer"
      :framework="selectedFramework"
      @close="closeDrawer"
      @edit="editFramework"
    />
  </section>
</template>
