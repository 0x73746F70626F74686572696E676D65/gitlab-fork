<script>
import ListSelector from '~/vue_shared/components/list_selector/index.vue';

export default {
  components: {
    ListSelector,
  },
  inject: {
    projectPath: {
      default: '',
    },
  },
  props: {
    items: {
      type: Array,
      required: true,
    },
    type: {
      type: String,
      required: true,
    },
    usersOptions: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    disableNamespaceDropdown: {
      type: Boolean,
      required: false,
      default: false,
    },
    isProjectScoped: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      selectedItems: [],
    };
  },
  beforeMount() {
    this.selectedItems = [...this.items];
  },
  methods: {
    handleSelect(item) {
      this.selectedItems.push(item);
      this.$emit('change', this.selectedItems);
    },
    handleDelete(id) {
      const index = this.selectedItems.findIndex((item) => item.id === id);
      this.selectedItems.splice(index, 1);
      this.$emit('change', this.selectedItems);
    },
  },
};
</script>

<template>
  <div>
    <list-selector
      :type="type"
      class="gl-mt-5 gl-p-0!"
      :project-path="projectPath"
      :selected-items="selectedItems"
      :users-query-options="usersOptions"
      :disable-namespace-dropdown="disableNamespaceDropdown"
      :is-project-scoped="isProjectScoped"
      @select="handleSelect"
      @delete="handleDelete"
    />
  </div>
</template>
