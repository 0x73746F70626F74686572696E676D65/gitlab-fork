<script>
import {
  GlBadge,
  GlIcon,
  GlButton,
  GlSkeletonLoader,
  GlTable,
  GlPopover,
  GlLink,
  GlLoadingIcon,
} from '@gitlab/ui';
import { cloneDeep } from 'lodash';
import { DOCS_URL_IN_EE_DIR } from 'jh_else_ce/lib/utils/url_utility';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { NAMESPACE_ORGANIZATION, NAMESPACE_PROJECT, DEPENDENCIES_TABLE_I18N } from '../constants';
import DependencyLicenseLinks from './dependency_license_links.vue';
import DependencyLocation from './dependency_location.vue';
import DependencyLocationCount from './dependency_location_count.vue';
import DependencyProjectCount from './dependency_project_count.vue';
import DependencyVulnerabilities from './dependency_vulnerabilities.vue';

const tdClass = (defaultClasses = []) => (value, key, item) => {
  const classes = [...defaultClasses];

  // Don't draw a border between a row and its `row-details` slot
  // eslint-disable-next-line no-underscore-dangle
  if (item._showDetails) {
    classes.push('border-bottom-0');
  }

  return classes;
};

const sharedFields = [
  { key: 'component', label: DEPENDENCIES_TABLE_I18N.component, tdClass: tdClass() },
  { key: 'packager', label: DEPENDENCIES_TABLE_I18N.packager, tdClass: tdClass() },
  {
    key: 'location',
    label: DEPENDENCIES_TABLE_I18N.location,
    tdClass: tdClass(['gl-md-max-w-26']),
  },
  { key: 'license', label: DEPENDENCIES_TABLE_I18N.license, tdClass: tdClass() },
];

export default {
  name: 'DependenciesTable',
  components: {
    DependencyLicenseLinks,
    DependencyVulnerabilities,
    DependencyLocation,
    DependencyLocationCount,
    DependencyProjectCount,
    GlBadge,
    GlIcon,
    GlButton,
    GlSkeletonLoader,
    GlTable,
    GlPopover,
    GlLink,
    GlLoadingIcon,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['namespaceType'],
  props: {
    dependencies: {
      type: Array,
      required: true,
    },
    vulnerabilityInfo: {
      type: Object,
      required: true,
    },
    vulnerabilityItemsLoading: {
      type: Array,
      required: false,
      default: () => [],
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    anyDependencyHasVulnerabilities() {
      return this.localDependencies.some((dependency) => this.vulnerabilitiesCount(dependency));
    },
    fields() {
      if (this.isOrganizationNamespace) {
        return this.$options.organizationFields;
      }

      return this.isProjectNamespace ? this.$options.projectFields : this.$options.groupFields;
    },
    isProjectNamespace() {
      return this.namespaceType === NAMESPACE_PROJECT;
    },
    isOrganizationNamespace() {
      return this.namespaceType === NAMESPACE_ORGANIZATION;
    },
    localDependencies() {
      return this.transformDependenciesForUI(this.dependencies);
    },
    isGroupLevelOrWithSbomOccurrencesEnabled() {
      return !this.isProjectNamespace || this.glFeatures.projectLevelSbomOccurrences;
    },
  },
  methods: {
    // The GlTable component mutates the `_showDetails` property on items
    // passed to it in order to track the visibility of each row's `row-details`
    // slot. So, create a deep clone of them here to avoid mutating the
    // `dependencies` prop.
    // We also make sure that `vulnerabilities` is always defined to prevent rendering
    // errors when the user is allowe to see dependencies but not their vulnerabilities.
    transformDependenciesForUI(dependencies) {
      return dependencies.map(({ vulnerabilities, ...dep }) => ({
        ...cloneDeep(dep),
        vulnerabilities: vulnerabilities ? cloneDeep(vulnerabilities) : [],
      }));
    },
    packager(dependency) {
      return dependency.packager || this.$options.i18n.unknown;
    },
    vulnerabilitiesCount(item) {
      if (this.isGroupLevelOrWithSbomOccurrencesEnabled) {
        return item.vulnerabilityCount;
      }
      return item.vulnerabilities?.length;
    },
    vulnerabilities(item) {
      if (this.isGroupLevelOrWithSbomOccurrencesEnabled) {
        return this.vulnerabilityInfo[item.occurrenceId];
      }
      return item.vulnerabilities;
    },
    rowExpanded(showDetails, item) {
      showDetails();
      if (this.isGroupLevelOrWithSbomOccurrencesEnabled) {
        this.$emit('row-click', item);
      }
    },
  },
  organizationFields: [...sharedFields],
  groupFields: [
    ...sharedFields,
    { key: 'projects', label: DEPENDENCIES_TABLE_I18N.projects, tdClass: tdClass() },
    { key: 'isVulnerable', label: '', tdClass: tdClass(['gl-text-right']) },
  ],
  projectFields: [
    ...sharedFields,
    { key: 'isVulnerable', label: '', tdClass: tdClass(['gl-text-right']) },
  ],
  DEPENDENCIES_PER_PAGE: 20,
  DEPENDENCY_PATH_LINK: `${DOCS_URL_IN_EE_DIR}/user/application_security/dependency_list/#dependency-paths`,
  i18n: DEPENDENCIES_TABLE_I18N,
};
</script>

<template>
  <gl-table
    :fields="fields"
    :items="localDependencies"
    :busy="isLoading"
    data-testid="dependencies-table-content"
    details-td-class="pt-0"
    stacked="md"
    show-empty
  >
    <template #head(location)="data">
      {{ data.label }}
      <gl-icon id="location-info" name="information-o" class="gl-text-blue-600 gl-ml-2" />
      <gl-popover
        target="location-info"
        placement="top"
        :title="$options.i18n.locationDependencyTitle"
      >
        {{ $options.i18n.tooltipText }}
        <div class="gl-mt-4">
          <gl-link :href="$options.DEPENDENCY_PATH_LINK" target="_blank">{{
            $options.i18n.tooltipMoreText
          }}</gl-link>
        </div>
      </gl-popover>
    </template>

    <!-- toggleDetails and detailsShowing are scoped slot props provided by
      GlTable; they mutate/read the item's _showDetails property, which GlTable
      uses to show/hide the row-details slot -->
    <template #cell(component)="{ item, toggleDetails, detailsShowing }">
      <gl-button
        v-if="anyDependencyHasVulnerabilities"
        class="gl-hidden md:gl-inline"
        :class="{ invisible: !vulnerabilitiesCount(item) }"
        category="tertiary"
        size="small"
        :aria-label="$options.i18n.toggleVulnerabilityList"
        :icon="detailsShowing ? 'chevron-up' : 'chevron-down'"
        @click="rowExpanded(toggleDetails, item)"
      />
      <span class="bold">{{ item.name }}</span
      >&nbsp;{{ item.version }}
    </template>

    <template #cell(packager)="{ item }">
      <span>{{ packager(item) }}</span>
    </template>

    <template #cell(location)="{ item }">
      <dependency-location-count
        v-if="item.occurrenceCount !== undefined"
        :location-count="item.occurrenceCount"
        :component-id="item.componentId"
      />
      <dependency-location v-else :location="item.location" />
    </template>

    <template #cell(license)="{ item }">
      <dependency-license-links :licenses="item.licenses" :title="item.name" />
    </template>

    <template #cell(projects)="{ item }">
      <dependency-project-count
        v-if="!isProjectNamespace"
        :project-count="item.projectCount"
        :component-id="item.componentId"
      />
    </template>

    <template #cell(isVulnerable)="{ item, toggleDetails }">
      <gl-badge
        v-if="vulnerabilitiesCount(item)"
        variant="warning"
        href="#"
        @click.native="rowExpanded(toggleDetails, item)"
      >
        <gl-icon name="warning" class="gl-text-orange-500 mr-1" />
        {{
          n__(
            'Dependencies|%d vulnerability detected',
            'Dependencies|%d vulnerabilities detected',
            vulnerabilitiesCount(item),
          )
        }}
      </gl-badge>
    </template>

    <template #row-details="{ item }">
      <gl-loading-icon v-if="vulnerabilityItemsLoading.includes(item)" size="md" />
      <dependency-vulnerabilities v-else class="ml-4" :vulnerabilities="vulnerabilities(item)" />
    </template>

    <template #table-busy>
      <div class="mt-2">
        <gl-skeleton-loader v-for="n in $options.DEPENDENCIES_PER_PAGE" :key="n" :lines="1" />
      </div>
    </template>
  </gl-table>
</template>
