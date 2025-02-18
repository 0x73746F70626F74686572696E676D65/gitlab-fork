<script>
import { GridStack } from 'gridstack';
import { breakpoints } from '@gitlab/ui/dist/utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { cloneWithoutReferences } from '~/lib/utils/common_utils';
import { loadCSSFile } from '~/lib/utils/css_utils';
import {
  GRIDSTACK_MARGIN,
  GRIDSTACK_CSS_HANDLE,
  GRIDSTACK_CELL_HEIGHT,
  GRIDSTACK_MIN_ROW,
  CURSOR_GRABBING_CLASS,
} from './constants';
import { parsePanelToGridItem } from './utils';

export default {
  name: 'GridstackWrapper',
  props: {
    value: {
      type: Object,
      required: true,
    },
    editing: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      grid: undefined,
      cssLoaded: false,
      mounted: false,
      gridPanels: [],
    };
  },
  computed: {
    mountedWithCss() {
      return this.cssLoaded && this.mounted;
    },
    gridConfig() {
      return this.value.panels.map(parsePanelToGridItem);
    },
  },
  watch: {
    mountedWithCss(mountedWithCss) {
      if (mountedWithCss) {
        this.initGridStack();
      }
    },
    editing(value) {
      this.grid?.setStatic(!value);
    },
    gridConfig: {
      handler(config) {
        this.grid?.load(config);
      },
      deep: true,
    },
  },
  mounted() {
    this.mounted = true;
  },
  beforeDestroy() {
    this.mounted = false;
    this.grid?.destroy();
  },
  async created() {
    try {
      await loadCSSFile(gon.gridstack_css_path);
      this.cssLoaded = true;
    } catch (e) {
      Sentry.captureException(e);
    }
  },
  methods: {
    async mountGridComponents(panels, options = { scollIntoView: false }) {
      // Ensure new panels are always rendered first
      await this.$nextTick();

      panels.forEach((panel) => {
        const wrapper = this.$refs.panelWrappers.find((w) => w.id === panel.id);
        const widgetContentEl = panel.el.querySelector('.grid-stack-item-content');

        widgetContentEl.appendChild(wrapper);
      });

      if (options.scrollIntoView) {
        const mostRecent = panels[panels.length - 1];
        mostRecent.el.scrollIntoView({ behavior: 'smooth' });
      }
    },
    getGridItemForElement(el) {
      return this.gridConfig.find((item) => item.id === el.getAttribute('gs-id'));
    },
    initGridPanelSlots(gridElements) {
      if (!gridElements) return;

      this.gridPanels = gridElements.map((el) => ({
        ...this.getGridItemForElement(el),
        el,
      }));

      this.mountGridComponents(this.gridPanels);
    },
    initGridStack() {
      this.grid = GridStack.init({
        staticGrid: !this.editing,
        margin: GRIDSTACK_MARGIN,
        handle: GRIDSTACK_CSS_HANDLE,
        cellHeight: GRIDSTACK_CELL_HEIGHT,
        minRow: GRIDSTACK_MIN_ROW,
        columnOpts: { breakpoints: [{ w: breakpoints.md, c: 1 }] },
        alwaysShowResizeHandle: true,
        animate: true,
        float: true,
      }).load(this.gridConfig);

      // Sync Vue components array with gridstack items
      this.initGridPanelSlots(this.grid.getGridItems());

      this.grid.on('dragstart', () => {
        this.$el.classList.add(CURSOR_GRABBING_CLASS);
      });
      this.grid.on('dragstop', () => {
        this.$el.classList.remove(CURSOR_GRABBING_CLASS);
      });
      this.grid.on('change', (_, items) => {
        if (!items) return;

        this.emitLayoutChanges(items);
      });
      this.grid.on('added', (_, items) => {
        this.addGridPanels(items);
      });
      this.grid.on('removed', (_, items) => {
        this.removeGridPanels(items);
      });
    },
    convertToGridAttributes(gridStackItem) {
      return {
        yPos: gridStackItem.y,
        xPos: gridStackItem.x,
        width: gridStackItem.w,
        height: gridStackItem.h,
      };
    },
    removeGridPanels(items) {
      items.forEach((item) => {
        const index = this.gridPanels.findIndex((c) => c.id === item.id);
        this.gridPanels.splice(index, 1);
        // Finally remove the gridstack element
        item.el.remove();
      });
    },
    addGridPanels(items) {
      const newPanels = items.map(({ grid, ...rest }) => ({ ...rest }));
      this.gridPanels.push(...newPanels);

      this.mountGridComponents(newPanels, { scollIntoView: true });
    },
    emitLayoutChanges(items) {
      const newValue = cloneWithoutReferences(this.value);
      items.forEach((item) => {
        const panel = newValue.panels.find((p) => p.id === item.id);
        panel.gridAttributes = {
          ...panel.gridAttributes,
          ...this.convertToGridAttributes(item),
        };
      });
      this.$emit('input', newValue);
    },
  },
};
</script>

<template>
  <div class="grid-stack" data-testid="gridstack-grid">
    <div
      v-for="panel in gridPanels"
      :id="panel.id"
      ref="panelWrappers"
      :key="panel.id"
      class="gl-h-full"
      :class="{ 'gl-cursor-grab': editing }"
      data-testid="grid-stack-panel"
    >
      <slot name="panel" v-bind="{ panel: panel.props }"></slot>
    </div>
  </div>
</template>
