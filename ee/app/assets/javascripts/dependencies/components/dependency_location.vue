<script>
import { GlIcon, GlIntersperse, GlLink, GlPopover, GlTruncate } from '@gitlab/ui';
import { n__ } from '~/locale';
import { DEPENDENCIES_TABLE_I18N } from '../constants';
import DependencyPathViewer from './dependency_path_viewer.vue';

export const VISIBLE_DEPENDENCY_COUNT = 2;
export const CONTAINER_IMAGE_PREFIX = 'container-image:';

export default {
  name: 'DependencyLocation',
  components: {
    DependencyPathViewer,
    GlIcon,
    GlIntersperse,
    GlLink,
    GlPopover,
    GlTruncate,
  },
  props: {
    location: {
      type: Object,
      required: true,
    },
  },
  computed: {
    ancestors() {
      return this.location.ancestors || [];
    },
    locationComponent() {
      return this.isContainerImageDependency ? 'span' : GlLink;
    },
    hasAncestors() {
      return this.ancestors.length > 0;
    },
    isContainerImageDependency() {
      return this.location.path.startsWith(CONTAINER_IMAGE_PREFIX);
    },
    locationPath() {
      if (this.isContainerImageDependency) {
        return this.location.path.slice(CONTAINER_IMAGE_PREFIX.length);
      }

      return this.location.path;
    },
    isTopLevelDependency() {
      return this.location.topLevel;
    },
    visibleDependencies() {
      return this.ancestors.slice(0, VISIBLE_DEPENDENCY_COUNT);
    },
    remainingDependenciesCount() {
      return Math.max(0, this.ancestors.length - VISIBLE_DEPENDENCY_COUNT);
    },
    showMoreLink() {
      return this.remainingDependenciesCount > 0;
    },
    nMoreMessage() {
      return n__('Dependencies|%d more', 'Dependencies|%d more', this.remainingDependenciesCount);
    },
    hasPaths() {
      return this.location.path && this.location.blobPath;
    },
  },
  i18n: DEPENDENCIES_TABLE_I18N,
};
</script>

<template>
  <gl-intersperse separator=" / " class="gl-text-gray-500">
    <!-- We need to put an extra span to avoid separator between path & top level label -->
    <span>
      <component
        :is="locationComponent"
        v-if="hasPaths"
        class="md:gl-whitespace-nowrap"
        data-testid="dependency-path"
        :href="location.blobPath"
      >
        <gl-icon v-if="isContainerImageDependency" name="container-image" />
        <gl-icon v-else name="doc-text" />
        <gl-truncate
          class="gl-hidden md:gl-inline-flex"
          position="start"
          :text="locationPath"
          with-tooltip
        />
        <span class="md:gl-hidden">{{ locationPath }}</span>
      </component>
      <span v-else>{{ $options.i18n.unknown }}</span>
      <span v-if="isTopLevelDependency">{{ s__('Dependencies|(top level)') }}</span>
    </span>

    <dependency-path-viewer v-if="hasAncestors" :dependencies="visibleDependencies" />

    <!-- We need to put an extra span to avoid separator between link & popover -->
    <span v-if="showMoreLink">
      <gl-link ref="moreLink" class="gl-whitespace-nowrap">{{ nMoreMessage }}</gl-link>

      <gl-popover
        :target="() => $refs.moreLink.$el"
        placement="top"
        :title="s__('Dependencies|Dependency path')"
      >
        <dependency-path-viewer :dependencies="ancestors" />

        <!-- footer -->
        <div class="gl-mt-4">
          <gl-icon class="!gl-align-middle gl-text-blue-600" name="information" :size="12" />
          <span class="gl-text-gray-500 gl-align-middle">
            {{ s__('Dependencies|There may be multiple paths') }}
          </span>
        </div>
      </gl-popover>
    </span>
  </gl-intersperse>
</template>
