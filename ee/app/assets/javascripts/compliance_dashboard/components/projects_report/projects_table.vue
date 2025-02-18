<script>
import Vue from 'vue';
import {
  GlFormCheckbox,
  GlButton,
  GlLink,
  GlLoadingIcon,
  GlModal,
  GlTable,
  GlToast,
} from '@gitlab/ui';

import { __, s__ } from '~/locale';
import { createAlert } from '~/alert';

import CreateForm from 'ee/groups/settings/compliance_frameworks/components/create_form.vue';
import EditForm from 'ee/groups/settings/compliance_frameworks/components/edit_form.vue';
import FrameworkBadge from '../shared/framework_badge.vue';
import { isTopLevelGroup } from '../../utils';
import setComplianceFrameworkMutation from '../../graphql/set_compliance_framework.mutation.graphql';
import SelectionOperations from './selection_operations.vue';
import FrameworkSelectionBox from './framework_selection_box.vue';

Vue.use(GlToast);

export default {
  name: 'ProjectsTable',
  components: {
    CreateForm,
    EditForm,

    FrameworkBadge,
    FrameworkSelectionBox,
    SelectionOperations,

    GlButton,
    GlFormCheckbox,
    GlLink,
    GlLoadingIcon,
    GlModal,
    GlTable,
  },
  props: {
    projects: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },

    groupPath: {
      type: String,
      required: true,
    },
    rootAncestorPath: {
      type: String,
      required: true,
    },
    hasFilters: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['updated'],
  data() {
    return {
      selectedRows: [],
      projectWhichInvokedModal: null,
      frameworkSelectedForEdit: null,
      preselectedFrameworkForBulkOperation: null,
      projectsPendindSingleOperation: [],
      isApplyInProgress: false,
    };
  },
  computed: {
    isFrameworkEditingEnabled() {
      return isTopLevelGroup(this.groupPath, this.rootAncestorPath);
    },

    tableFields() {
      const selectionField = {
        key: 'selected',
        sortable: false,
        thClass: '!gl-align-middle',
        tdClass: '!gl-align-middle',
      };
      return [...(this.isEditingEnabled ? [selectionField] : []), ...this.$options.fields];
    },

    hasProjects() {
      return this.projects.length > 0;
    },

    hasSelectedProjects() {
      return this.selectedRows.length > 0;
    },

    hasSelectedAllProjects() {
      return this.selectedRows.length === this.projects.length;
    },
    noProjectsText() {
      return this.hasFilters
        ? this.$options.i18n.noProjectsFoundMatchingFilters
        : this.$options.i18n.noProjectsFound;
    },
  },
  methods: {
    updateSelectedRows(selection) {
      this.selectedRows = selection;
    },

    qaRowAttributes(project, type) {
      if (type === 'row') {
        return {
          'data-testid': 'project-frameworks-row',
          'data-qa-project-name': project.name,
        };
      }

      return {};
    },

    async applyOperations(operations) {
      const successMessage = operations.some((entry) => Boolean(entry.frameworkId))
        ? this.$options.i18n.successApplyToastMessage
        : this.$options.i18n.successRemoveToastMessage;

      try {
        this.isApplyInProgress = true;
        const results = await Promise.all(
          operations.map((entry) =>
            this.$apollo.mutate({
              mutation: setComplianceFrameworkMutation,
              variables: {
                projectId: entry.projectId,
                frameworkId: entry.frameworkId,
              },
            }),
          ),
        );

        const firstError = results.find(
          (response) => response.data.projectSetComplianceFramework.errors.length,
        );
        if (firstError) {
          throw firstError;
        }
        this.$toast.show(successMessage, {
          action: {
            text: __('Undo'),
            onClick: () => {
              this.applyOperations(
                operations.map((entry) => ({
                  projectId: entry.projectId,
                  previousFrameworkId: entry.frameworkId,
                  frameworkId: entry.previousFrameworkId,
                })),
              );
            },
          },
        });
      } catch (e) {
        createAlert({
          message: __('Something went wrong on our end.'),
        });
      } finally {
        this.isApplyInProgress = false;
        this.$emit('updated');
      }
    },

    async applySingleItemOperation(operation) {
      try {
        this.projectsPendindSingleOperation.push(operation.projectId);
        await this.applyOperations([operation]);
      } finally {
        this.projectsPendindSingleOperation = this.projectsPendindSingleOperation.filter(
          (projectId) => projectId !== operation.projectId,
        );
      }
    },

    hasPendingSingleOperation(projectId) {
      return this.projectsPendindSingleOperation.indexOf(projectId) > -1;
    },

    createComplianceFramework(projectId) {
      this.projectWhichInvokedModal = projectId;
      this.$refs.createModal.show();
    },

    selectNewlyCreatedFramework({ framework }) {
      const projectId = this.projectWhichInvokedModal;
      this.resetCreateModal();

      if (projectId === this.$options.BULK_FRAMEWORK_ID) {
        this.preselectedFrameworkForBulkOperation = framework;
      } else {
        this.applySingleItemOperation({
          projectId,
          frameworkId: framework.id,
          previousFrameworkId: null,
        });
      }
    },

    resetCreateModal() {
      this.projectWhichInvokedModal = null;
      this.$refs.createModal.hide();
    },

    resetEditModal() {
      this.frameworkSelectedForEdit = null;
      this.$refs.editModal.hide();
    },
  },
  fields: [
    {
      key: 'selected',
      sortable: false,
      thClass: '!gl-align-middle',
      tdClass: '!gl-align-middle',
    },
    {
      key: 'projectName',
      label: __('Project name'),
      thClass: '!gl-align-middle',
      tdClass: '!gl-align-middle',
      sortable: false,
    },
    {
      key: 'projectPath',
      label: __('Project path'),
      thClass: '!gl-align-middle',
      tdAttr: { 'data-testid': 'project-path-content' },
      tdClass: '!gl-align-middle',
      sortable: false,
    },
    {
      key: 'complianceFramework',
      label: __('Compliance framework'),
      thClass: 'gl-md-max-w-26 !gl-align-middle',
      tdClass: 'gl-md-max-w-26 !gl-align-middle',
      sortable: false,
    },
  ],
  i18n: {
    addTitle: s__('ComplianceFrameworks|New compliance framework'),
    editTitle: s__('ComplianceFrameworks|Edit compliance framework'),

    noProjectsFound: s__('ComplianceReport|No projects found'),
    noProjectsFoundMatchingFilters: s__('ComplianceReport|No projects found that match filters'),
    addFrameworkMessage: s__('ComplianceReport|Add framework'),

    successApplyToastMessage: s__('ComplianceReport|Framework successfully applied'),
    successRemoveToastMessage: s__('ComplianceReport|Framework successfully removed'),
  },
  BULK_FRAMEWORK_ID: '__INTERNAL_BULK_FRAMEWORK_VALUE',
};
</script>
<template>
  <div>
    <gl-modal
      ref="createModal"
      :title="$options.i18n.addTitle"
      modal-id="create-framework-form-modal"
      hide-footer
    >
      <create-form @success="selectNewlyCreatedFramework" @cancel="resetCreateModal" />
    </gl-modal>
    <gl-modal
      ref="editModal"
      :title="$options.i18n.editTitle"
      modal-id="edit-framework-form-modal"
      hide-footer
    >
      <edit-form
        v-if="frameworkSelectedForEdit"
        :id="frameworkSelectedForEdit.id"
        :framework="frameworkSelectedForEdit"
        @success="resetEditModal"
        @cancel="resetEditModal"
      />
    </gl-modal>
    <selection-operations
      :selection="selectedRows"
      :root-ancestor-path="rootAncestorPath"
      :is-apply-in-progress="isApplyInProgress"
      :is-framework-creating-enabled="isFrameworkEditingEnabled"
      :default-framework="preselectedFrameworkForBulkOperation"
      @change="applyOperations"
      @create="createComplianceFramework($options.BULK_FRAMEWORK_ID)"
    />
    <gl-table
      :fields="$options.fields"
      :busy="isLoading"
      :items="projects"
      no-local-sorting
      show-empty
      stacked="lg"
      hover
      :tbody-tr-attr="qaRowAttributes"
      selectable
      select-mode="multi"
      selected-variant="primary"
      @row-selected="updateSelectedRows"
    >
      <template #head(selected)="{ selectAllRows, clearSelected }">
        <gl-form-checkbox
          class="gl-pt-2"
          data-testid="select-all-projects-checkbox"
          :checked="hasSelectedProjects"
          :indeterminate="hasSelectedProjects && !hasSelectedAllProjects"
          @change="hasSelectedProjects ? clearSelected() : selectAllRows()"
        />
      </template>
      <template #cell(selected)="{ rowSelected, selectRow, unselectRow }">
        <div>
          <gl-form-checkbox
            class="gl-pt-2"
            data-testid="select-project-checkbox"
            :checked="rowSelected"
            @change="rowSelected ? unselectRow() : selectRow()"
          />
        </div>
      </template>
      <template #cell(projectName)="{ item }">
        <gl-link :href="item.webUrl" data-testid="project-name-link">{{ item.name }} </gl-link>
      </template>
      <template #cell(projectPath)="{ item: { fullPath } }">
        {{ fullPath }}
      </template>
      <template #cell(complianceFramework)="{ item: { id, complianceFrameworks } }">
        <gl-loading-icon v-if="hasPendingSingleOperation(id)" size="sm" inline />
        <framework-selection-box
          v-else-if="!complianceFrameworks.length"
          :root-ancestor-path="rootAncestorPath"
          :is-framework-creating-enabled="isFrameworkEditingEnabled"
          @select="
            applySingleItemOperation({
              projectId: id,
              frameworkId: $event,
              previousFrameworkId: null,
            })
          "
          @create="createComplianceFramework(id)"
        >
          <template #toggle>
            <gl-button
              v-if="isFrameworkEditingEnabled"
              icon="plus"
              category="tertiary"
              variant="confirm"
            >
              {{ $options.i18n.addFrameworkMessage }}
            </gl-button>
          </template>
        </framework-selection-box>
        <framework-badge
          v-for="framework in complianceFrameworks"
          v-else
          :key="framework.id"
          closeable
          :show-edit="isFrameworkEditingEnabled"
          :framework="framework"
          @close="
            applySingleItemOperation({
              projectId: id,
              frameworkId: null,
              previousFrameworkId: framework.id,
            })
          "
        />
      </template>
      <template #table-busy>
        <gl-loading-icon size="lg" color="dark" class="gl-my-5" />
      </template>
      <template #empty>
        <div class="gl-my-5 gl-text-center" data-testid="projects-table-empty-state">
          {{ noProjectsText }}
        </div>
      </template>
    </gl-table>
  </div>
</template>
